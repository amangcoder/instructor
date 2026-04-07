/// PlanExecutionEngine — core background orchestrator for Plan step sequencing.
///
/// ## Architecture
///
/// [PlanExecutionEngineImpl] receives a [Plan] and walks its steps in order.
/// [RepeatStep] blocks are **flattened** at [startPlan] time: each child step
/// is expanded inline for every iteration, producing a flat [_FlatStep] list
/// that can be addressed by a single integer index ([_currentStepIndex]).
///
/// Flattening makes skip operations trivial (index ± 1) and eliminates the
/// need for a runtime recursive traversal. Each [_FlatStep] carries a
/// [repeatCounters] snapshot so the UI can display "Iteration N of M" without
/// any additional state.
///
/// ## Execution loop
///
/// [_runFromCurrentStep] is the async loop called from [startPlan] and
/// [resume]. It checks [_cancelled] before and after every step so that
/// [pause], [stop], and [skipForward]/[skipBackward] can safely interrupt it.
///
/// ## Persistence
///
/// At every step transition, [_persistState] upserts the [ExecutionStateTable]
/// row (planId, currentStepIndex, repeatCounters JSON, elapsedMs within the
/// current WaitStep, ambientPositionMs, status). This enables crash recovery
/// via [getRecoverableSession].
///
/// ## iOS background execution
///
/// [WaitStep] starts a silent audio loop via [AudioEngine.startSilenceKeepAlive]
/// so that the iOS AVAudioSession stays alive and the OS does not suspend the
/// app during long silent periods.
library plan_execution_engine;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/audio_engine.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/tts_service.dart';

part 'plan_execution_engine.g.dart';

// ────────────────────────────────────────────────────────────────────────────
// Internal value type
// ────────────────────────────────────────────────────────────────────────────

/// A leaf node in the flattened step sequence produced by [_flattenPlan].
///
/// [RepeatStep] blocks are expanded by [_flattenPlan]: each child is emitted
/// once per iteration of the repeat block, so the engine never encounters a
/// [RepeatStep] at runtime.
class _FlatStep {
  const _FlatStep({
    required this.step,
    required this.repeatCounters,
  });

  /// The concrete step to execute (never a [RepeatStep]).
  final PlanStep step;

  /// Snapshot of active repeat-block iteration counters at this position.
  ///
  /// Maps each enclosing [RepeatStep.id] → 1-based iteration number.
  /// Immutable so that [ExecutionState] snapshots are stable.
  final Map<String, int> repeatCounters;
}

// ────────────────────────────────────────────────────────────────────────────
// Public data types
// ────────────────────────────────────────────────────────────────────────────

/// Execution status snapshot broadcast by [PlanExecutionEngine.stateStream].
class ExecutionState {
  const ExecutionState({
    required this.plan,
    required this.currentStepIndex,
    required this.timeRemaining,
    required this.status,
    this.repeatCounters = const {},
    this.ambientPositionMs = 0,
    this.currentStepText,
    this.nextStepText,
    this.currentStepType,
  });

  /// The plan currently being executed.
  final Plan plan;

  /// Index into the engine's flattened step list.
  final int currentStepIndex;

  /// Time remaining for the current step (approximate for non-wait steps).
  final Duration timeRemaining;

  /// Current lifecycle status.
  final ExecutionStatus status;

  /// Maps repeat-step IDs to their current iteration count (for display).
  final Map<String, int> repeatCounters;

  /// Ambient audio position in milliseconds (for crash recovery seek).
  final int ambientPositionMs;

  /// User-facing display text for the currently executing flattened step.
  ///
  /// Populated from the engine's internal flattened step list so that plans
  /// with [RepeatStep] blocks show the actual inner step text rather than the
  /// [RepeatStep] container.
  final String? currentStepText;

  /// User-facing display text for the next flattened step, or null if last.
  final String? nextStepText;

  /// The [StepType] of the currently executing flattened step (for UI colour
  /// coding). Never [StepType.repeat] since repeat blocks are expanded.
  final StepType? currentStepType;
}

// ────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ────────────────────────────────────────────────────────────────────────────

/// Core background engine that walks through [Plan] steps sequentially.
///
/// ## Responsibilities
/// - Step sequencing (including nested [RepeatStep] via flat expansion)
/// - Dispatching to [AudioEngine], [NotificationService], and [TTSService]
/// - Persisting [ExecutionState] on every step transition for crash recovery
/// - Exposing a [stateStream] for the [NowPlayingUI] via Riverpod
abstract class PlanExecutionEngine {
  /// Begins executing [plan] from step 0 (always starts fresh).
  Future<void> startPlan(Plan plan);

  /// Pauses at the current position and persists state.
  Future<void> pause();

  /// Resumes from the last persisted position.
  Future<void> resume();

  /// Advances to the next step immediately.
  Future<void> skipForward();

  /// Returns to the previous step.
  Future<void> skipBackward();

  /// Stops execution and releases all resources.
  Future<void> stop();

  /// Starts executing [plan] at 4× speed for a quick preview/dry-run.
  ///
  /// [WaitStep] durations are divided by the 4× speed multiplier so the entire
  /// plan completes in roughly a quarter of its real duration. All other step
  /// types execute normally (TTS still plays, notifications still fire).
  /// The multiplier is reset to 1.0 when [stop] is called or the plan ends.
  Future<void> startPreview(Plan plan);

  /// Returns true when the engine is currently running in preview (4×) mode.
  bool get isPreview;

  /// Reactive stream of [ExecutionState] consumed by the Now Playing UI.
  Stream<ExecutionState> get stateStream;

  /// The most recently emitted [ExecutionState], or `null` when idle.
  ///
  /// Used by [executionStateProvider] to seed the stream for late subscribers
  /// (e.g. [NowPlayingScreen] mounting after [startPlan] has already emitted
  /// the initial state on the broadcast stream).
  ExecutionState? get currentState;

  /// Returns a recoverable session if one exists (for crash recovery on launch).
  ///
  /// Also restores the engine's internal state so that [resume] can be called
  /// immediately after the user confirms they want to resume.
  Future<ExecutionState?> getRecoverableSession();
}

// ────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ────────────────────────────────────────────────────────────────────────────

/// Production implementation of [PlanExecutionEngine].
///
/// Inject fakes for [AudioEngine], [TTSService], [NotificationService], and
/// [AppDatabase] in unit tests to avoid platform channel calls.
class PlanExecutionEngineImpl implements PlanExecutionEngine {
  PlanExecutionEngineImpl({
    required AudioEngine audioEngine,
    required TTSService ttsService,
    required NotificationService notificationService,
    required AppDatabase db,
  })  : _audioEngine = audioEngine,
        _ttsService = ttsService,
        _notificationService = notificationService,
        _db = db;

  final AudioEngine _audioEngine;
  final TTSService _ttsService;
  final NotificationService _notificationService;
  final AppDatabase _db;

  // ── Execution state ───────────────────────────────────────────────────────

  Plan? _currentPlan;

  /// Flattened step sequence built at [startPlan] time.
  List<_FlatStep> _flatSteps = [];

  /// Current position in [_flatSteps].
  int _currentStepIndex = 0;

  /// Current lifecycle status.
  ExecutionStatus _status = ExecutionStatus.idle;

  // ── Wait step tracking ────────────────────────────────────────────────────

  /// The timer that fires when the current [WaitStep] elapses.
  Timer? _waitTimer;

  /// Completer resolved when [_waitTimer] fires or when the step is
  /// interrupted by [pause], [stop], or [skipForward]/[skipBackward].
  Completer<void>? _waitCompleter;

  /// How many milliseconds of the current [WaitStep] have already elapsed.
  ///
  /// Non-zero only when resuming a paused [WaitStep]. Reset to 0 when the
  /// step completes or is skipped.
  int _waitStepElapsedMs = 0;

  /// Timestamp when the current [WaitStep] timer tick started.
  ///
  /// Used to compute elapsed time when [pause] is called mid-wait.
  DateTime? _waitStepStartTime;

  // ── Preview speed ─────────────────────────────────────────────────────────

  /// Speed multiplier applied to [WaitStep] durations during preview mode.
  ///
  /// 1.0 = normal speed, 4.0 = 4× preview speed. Reset to 1.0 by [stop].
  double _speedMultiplier = 1.0;

  @override
  bool get isPreview => _speedMultiplier > 1.0;

  // ── Cancellation ──────────────────────────────────────────────────────────

  /// Set to [true] to break the execution loop (pause / stop / skip).
  bool _cancelled = false;

  // ── State stream ──────────────────────────────────────────────────────────

  final StreamController<ExecutionState> _stateController =
      StreamController<ExecutionState>.broadcast();

  ExecutionState? _lastState;

  @override
  Stream<ExecutionState> get stateStream => _stateController.stream;

  @override
  ExecutionState? get currentState => _lastState;

  // ── Public API ────────────────────────────────────────────────────────────

  @override
  Future<void> startPlan(Plan plan) async {
    // Stop any in-progress execution cleanly first.
    if (_status == ExecutionStatus.running ||
        _status == ExecutionStatus.paused) {
      await stop();
    }

    _currentPlan = plan;
    _flatSteps = _flattenPlan(plan.steps);
    _currentStepIndex = 0;
    _waitStepElapsedMs = 0;
    _cancelled = false;
    _status = ExecutionStatus.running;

    _emitState();
    await _persistState();

    // Run the execution loop on the next microtask so that startPlan returns
    // promptly and callers can set up stream listeners before steps begin.
    unawaited(_runFromCurrentStep());
  }

  @override
  Future<void> startPreview(Plan plan) async {
    _speedMultiplier = 4.0;
    await startPlan(plan);
  }

  @override
  Future<void> pause() async {
    if (_status != ExecutionStatus.running) return;

    // Capture elapsed time within a WaitStep before cancelling the timer.
    if (_waitStepStartTime != null) {
      _waitStepElapsedMs +=
          DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      _waitStepStartTime = null;
    }

    _cancelled = true;
    _status = ExecutionStatus.paused;

    // Unblock the WaitStep completer so the loop exits promptly.
    _waitCompleter?.complete();
    _waitCompleter = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    // Stop all audio — this also unblocks any pending playVoice() awaiter.
    await _audioEngine.stopAll();

    _emitState();
    await _persistState();
  }

  @override
  Future<void> resume() async {
    if (_status != ExecutionStatus.paused) return;

    _cancelled = false;
    _status = ExecutionStatus.running;

    // Seek ambient audio to the position it was at when we paused, so that
    // the listener doesn't notice a gap on resume.
    final rows = await (_db.select(_db.executionStateTable)
          ..where((t) => t.planId.equals(_currentPlan!.id))
          ..limit(1))
        .get();

    if (rows.isNotEmpty && rows.first.ambientPositionMs > 0) {
      await _audioEngine
          .seekAmbient(Duration(milliseconds: rows.first.ambientPositionMs));
    }

    _emitState();
    await _persistState();
    unawaited(_runFromCurrentStep());
  }

  @override
  Future<void> skipForward() async {
    if (_status == ExecutionStatus.idle) return;
    await _cancelCurrentStep();

    if (_currentStepIndex < _flatSteps.length - 1) {
      _currentStepIndex++;
    }
    _waitStepElapsedMs = 0;

    _emitState();
    await _persistState();

    if (_status == ExecutionStatus.running) {
      _cancelled = false;
      unawaited(_runFromCurrentStep());
    }
  }

  @override
  Future<void> skipBackward() async {
    if (_status == ExecutionStatus.idle) return;
    await _cancelCurrentStep();

    if (_currentStepIndex > 0) {
      _currentStepIndex--;
    }
    _waitStepElapsedMs = 0;

    _emitState();
    await _persistState();

    if (_status == ExecutionStatus.running) {
      _cancelled = false;
      unawaited(_runFromCurrentStep());
    }
  }

  @override
  Future<void> stop() async {
    if (_status == ExecutionStatus.idle) return;

    await _cancelCurrentStep();
    _status = ExecutionStatus.idle;

    await Future.wait([
      _audioEngine.stopAll(),
      _notificationService.cancelAll(),
    ]);

    await _clearPersistedState();

    _currentPlan = null;
    _lastState = null;
    _flatSteps = [];
    _currentStepIndex = 0;
    _waitStepElapsedMs = 0;
    _speedMultiplier = 1.0;
  }

  @override
  Future<ExecutionState?> getRecoverableSession() async {
    // Query for paused or running rows, most recently saved first.
    final rows = await (_db.select(_db.executionStateTable)
          ..where((t) => t.status.isIn(['paused', 'running']))
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
          ..limit(1))
        .get();

    if (rows.isEmpty) return null;

    final row = rows.first;

    // Attempt to load the associated Plan.
    final planRow = await (_db.select(_db.plansTable)
          ..where((t) => t.id.equals(row.planId)))
        .getSingleOrNull();

    if (planRow == null) {
      // Plan was deleted — remove the orphaned execution state row.
      await (_db.delete(_db.executionStateTable)
            ..where((t) => t.planId.equals(row.planId)))
          .go();
      return null;
    }

    final plan = _rowToPlan(planRow);

    // Parse persisted repeat counters.
    Map<String, int> repeatCounters = {};
    try {
      final decoded = jsonDecode(row.repeatCounters) as Map<String, dynamic>;
      repeatCounters =
          decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      // Malformed JSON — start without counters.
    }

    // Restore internal engine state so that resume() works immediately.
    _currentPlan = plan;
    _flatSteps = _flattenPlan(plan.steps);
    _currentStepIndex =
        row.currentStepIndex.clamp(0, _flatSteps.isEmpty ? 0 : _flatSteps.length - 1);
    _waitStepElapsedMs = row.elapsedMs;
    _status = ExecutionStatus.paused;
    _cancelled = false;

    // Compute time remaining for the current step.
    Duration timeRemaining = Duration.zero;
    if (_currentStepIndex < _flatSteps.length) {
      final step = _flatSteps[_currentStepIndex].step;
      if (step is WaitStep) {
        final remainingMs =
            step.duration.inMilliseconds - row.elapsedMs;
        timeRemaining = Duration(
          milliseconds: remainingMs.clamp(0, step.duration.inMilliseconds),
        );
      } else {
        timeRemaining = step.estimatedStepDuration;
      }
    }

    final currentFlatStep = _currentStepIndex < _flatSteps.length
        ? _flatSteps[_currentStepIndex]
        : null;
    final nextFlatStep = (_currentStepIndex + 1) < _flatSteps.length
        ? _flatSteps[_currentStepIndex + 1]
        : null;

    return ExecutionState(
      plan: plan,
      currentStepIndex: _currentStepIndex,
      timeRemaining: timeRemaining,
      status: ExecutionStatus.paused,
      repeatCounters: repeatCounters,
      ambientPositionMs: row.ambientPositionMs,
      currentStepText: currentFlatStep != null
          ? _stepDisplayText(currentFlatStep.step)
          : null,
      nextStepText:
          nextFlatStep != null ? _stepDisplayText(nextFlatStep.step) : null,
      currentStepType: currentFlatStep?.step.type,
    );
  }

  // ── Execution loop ────────────────────────────────────────────────────────

  /// Runs steps sequentially starting from [_currentStepIndex].
  ///
  /// Exits when the plan completes, [_cancelled] is set to true, or an
  /// unrecoverable error occurs.
  Future<void> _runFromCurrentStep() async {
    while (_currentStepIndex < _flatSteps.length && !_cancelled) {
      final flatStep = _flatSteps[_currentStepIndex];

      await _executeStep(flatStep);

      if (_cancelled) break;

      _currentStepIndex++;

      // Persist and emit before the next step (unless we just advanced past
      // the last step, in which case _complete() handles the final state).
      if (_currentStepIndex < _flatSteps.length) {
        _emitState();
        await _persistState();
      }
    }

    if (!_cancelled && _status == ExecutionStatus.running) {
      await _complete();
    }
  }

  /// Dispatches [flatStep] to the appropriate handler.
  Future<void> _executeStep(_FlatStep flatStep) async {
    final step = flatStep.step;

    switch (step) {
      case SayStep(:final text, :final voiceId):
        await _executeSayStep(
          text: text,
          voiceId: voiceId ?? _currentPlan!.defaultVoice,
        );
      case NotifyStep(:final title, :final body):
        await _executeNotifyStep(title: title, body: body);
      case PlayStep(:final audioAssetKey, :final loop, :final volume):
        await _executePlayStep(
          audioAssetKey: audioAssetKey,
          loop: loop,
          volume: volume,
        );
      case StopAudioStep():
        await _executeStopAudioStep();
      case WaitStep(:final duration):
        await _executeWaitStep(duration);
      case RepeatStep():
        // RepeatStep is expanded during _flattenPlan — should never be reached.
        debugPrint(
          'PlanExecutionEngine: unexpected RepeatStep at step '
          '$_currentStepIndex — plan flattening may have a bug.',
        );
    }
  }

  // ── Step handlers ─────────────────────────────────────────────────────────

  Future<void> _executeSayStep({
    required String text,
    required String voiceId,
  }) async {
    if (_cancelled) return;

    debugPrint('PlanExecutionEngine: [SAY] starting — text="${text.length > 50 ? '${text.substring(0, 50)}…' : text}", voice=$voiceId');

    // Duck ambient proactively while TTS resolves (may need a network call on
    // a cache miss, though pre-rendering at plan save should prevent this).
    try {
      await _audioEngine.duckAmbient();
    } catch (e) {
      debugPrint('PlanExecutionEngine: duckAmbient failed: $e');
    }

    if (_cancelled) return;

    // Resolve the cached audio file path (or render on a miss).
    String? path;
    try {
      path = await _ttsService.renderTTS(text: text, voiceId: voiceId);
      debugPrint('PlanExecutionEngine: [SAY] renderTTS succeeded — path=$path');
    } on TtsFallbackException {
      // Text was already spoken by the TTS service's platform TTS fallback
      // (e.g. backend offline / timeout). Just restore ambient and move on.
      debugPrint('PlanExecutionEngine: [SAY] text spoken via platform TTS fallback');
      try {
        await _audioEngine.restoreAmbient();
      } catch (_) {}
      return;
    } on TtsApiException catch (e) {
      if (e.statusCode == 401) {
        // Session expired — logout already triggered, stop the plan.
        debugPrint('PlanExecutionEngine: auth expired, stopping plan');
        await stop();
        return;
      }
      debugPrint('PlanExecutionEngine: TTS API error for "$text": $e');
      // Last resort: speak directly through the device speaker.
      debugPrint('PlanExecutionEngine: [SAY] falling back to speakDirect (TtsApiException)');
      path = await _speakDirectFallback(text);
      if (path == null) {
        debugPrint('PlanExecutionEngine: [SAY] speakDirect fallback returned null, skipping playVoice');
        return;
      }
    } catch (e) {
      debugPrint('PlanExecutionEngine: TTS render failed for "$text": $e');
      // Last resort: speak directly through the device speaker.
      debugPrint('PlanExecutionEngine: [SAY] falling back to speakDirect (${e.runtimeType})');
      path = await _speakDirectFallback(text);
      if (path == null) {
        debugPrint('PlanExecutionEngine: [SAY] speakDirect fallback returned null, skipping playVoice');
        return;
      }
    }

    if (_cancelled) return;

    // Read the user's preferred speech rate before playback.
    final rateRow = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
        .getSingleOrNull();
    final speed = double.tryParse(rateRow?.value ?? '') ?? 1.0;

    // Play voice and wait for completion. AudioEngineImpl.playVoice awaits
    // completion and automatically restores ambient volume when done.
    debugPrint('PlanExecutionEngine: [SAY] playing voice — path=$path, speed=$speed');
    try {
      await _audioEngine.playVoice(path, speed: speed);
      debugPrint('PlanExecutionEngine: [SAY] playVoice completed');
    } catch (e) {
      debugPrint('PlanExecutionEngine: playVoice failed: $e');
      // Fallback to platform TTS when audio file playback fails.
      debugPrint('PlanExecutionEngine: [SAY] playVoice failed, trying speakDirect');
      try {
        await _ttsService.speakDirect(text, speed: speed);
        debugPrint('PlanExecutionEngine: [SAY] speakDirect completed');
      } catch (speakError) {
        debugPrint(
          'PlanExecutionEngine: speakDirect fallback also failed: $speakError',
        );
      }
      // Restore ambient in case playVoice failed before its internal
      // restore handler could run (e.g. setFilePath threw).
      try {
        await _audioEngine.restoreAmbient();
      } catch (_) {}
    }
    debugPrint('PlanExecutionEngine: [SAY] step done');
  }

  /// Attempts [speakDirect] as a last-resort fallback and restores ambient.
  /// Returns `null` to signal the caller should return (skip playVoice).
  Future<String?> _speakDirectFallback(String text) async {
    debugPrint('PlanExecutionEngine: [FALLBACK] speakDirect starting — text="${text.length > 50 ? '${text.substring(0, 50)}…' : text}"');
    try {
      final rateRow = await (_db.select(_db.appSettingsTable)
            ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
          .getSingleOrNull();
      final speed = double.tryParse(rateRow?.value ?? '') ?? 1.0;
      debugPrint('PlanExecutionEngine: [FALLBACK] calling speakDirect with speed=$speed');
      await _ttsService.speakDirect(text, speed: speed);
      debugPrint('PlanExecutionEngine: [FALLBACK] speakDirect completed successfully');
    } catch (speakError) {
      debugPrint(
        'PlanExecutionEngine: speakDirect also failed: $speakError',
      );
    }
    try {
      await _audioEngine.restoreAmbient();
    } catch (_) {}
    debugPrint('PlanExecutionEngine: [FALLBACK] done, returning null');
    return null;
  }

  Future<void> _executeNotifyStep({
    required String title,
    required String body,
  }) async {
    if (_cancelled) return;
    try {
      await _notificationService.showStepNotification(title, body);
    } catch (e) {
      debugPrint('PlanExecutionEngine: NotifyStep error: $e');
    }
  }

  Future<void> _executePlayStep({
    required String audioAssetKey,
    required bool loop,
    required double volume,
  }) async {
    if (_cancelled) return;
    try {
      if (loop) {
        // Looping ambient track — plays continuously on the ambient channel.
        await _audioEngine.startAmbient(
          audioAssetKey,
          loop: true,
          volume: volume,
        );
      } else {
        // One-shot effect (bell, chime, gong) — plays on the voice channel
        // so it doesn't replace the active ambient track.
        await _audioEngine.playEffect(audioAssetKey);
      }
    } catch (e) {
      debugPrint('PlanExecutionEngine: PlayStep error: $e');
    }
  }

  Future<void> _executeStopAudioStep() async {
    if (_cancelled) return;
    try {
      await _audioEngine.stopAmbient();
    } catch (e) {
      debugPrint('PlanExecutionEngine: StopAudioStep error: $e');
    }
  }

  Future<void> _executeWaitStep(Duration duration) async {
    if (_cancelled) return;

    // Start silent keep-alive so iOS doesn't suspend the app during silence.
    try {
      await _audioEngine.startSilenceKeepAlive();
    } catch (e) {
      debugPrint('PlanExecutionEngine: startSilenceKeepAlive error: $e');
    }

    final rawRemaining =
        duration - Duration(milliseconds: _waitStepElapsedMs);
    // Apply speed multiplier for preview mode (divide effective wait time).
    final remaining = _speedMultiplier > 1.0
        ? Duration(
            milliseconds:
                (rawRemaining.inMilliseconds / _speedMultiplier).round(),
          )
        : rawRemaining;

    if (remaining <= Duration.zero) {
      // Already elapsed (e.g. resumed past the end of a short wait).
      await _audioEngine.stopSilenceKeepAlive();
      _waitStepElapsedMs = 0;
      return;
    }

    _waitCompleter = Completer<void>();
    _waitStepStartTime = DateTime.now();

    // Compute the wall-clock deadline so the periodic timer can detect
    // completion even if the Dart isolate was briefly suspended by the OS.
    final deadline = _waitStepStartTime!.add(remaining);

    debugPrint(
      'PlanExecutionEngine: WaitStep started — '
      'duration=${duration.inSeconds}s, '
      'elapsed=${_waitStepElapsedMs}ms, '
      'remaining=${remaining.inSeconds}s, '
      'deadline=$deadline',
    );

    // Single periodic timer handles both UI updates and completion detection.
    // Checking wall-clock time each tick is more resilient than a one-shot
    // Timer(duration) which can misfire when the OS throttles the isolate.
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_cancelled || (_waitCompleter?.isCompleted ?? true)) {
        _waitTimer?.cancel();
        _waitTimer = null;
        return;
      }

      if (DateTime.now().isAfter(deadline)) {
        _waitTimer?.cancel();
        _waitTimer = null;
        if (!(_waitCompleter?.isCompleted ?? true)) {
          _waitCompleter!.complete();
        }
        return;
      }

      // Update the foreground notification so the OS sees the service as
      // actively doing work, preventing process deprioritization / suspension.
      try {
        _notificationService.updateForegroundNotification(
          _stepDisplayText(_flatSteps[_currentStepIndex].step),
          _computeTimeRemaining(),
        );
      } catch (_) {
        // Best-effort — notification failure should not break execution.
      }

      _emitState();
    });

    await _waitCompleter!.future;

    _waitCompleter = null;
    _waitTimer?.cancel();
    _waitTimer = null;

    if (!_cancelled) {
      // Step completed normally — reset elapsed tracking.
      _waitStepElapsedMs = 0;
      _waitStepStartTime = null;
    }

    try {
      await _audioEngine.stopSilenceKeepAlive();
    } catch (e) {
      debugPrint('PlanExecutionEngine: stopSilenceKeepAlive error: $e');
    }
  }

  // ── Completion ────────────────────────────────────────────────────────────

  Future<void> _complete() async {
    _status = ExecutionStatus.completed;
    _speedMultiplier = 1.0;

    await Future.wait([
      _audioEngine.stopAll(),
      _notificationService.cancelAll(),
    ]);

    await _clearPersistedState();
    _emitState();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Interrupts the currently executing step.
  ///
  /// Sets [_cancelled], completes the [_waitCompleter] (unblocking a WaitStep),
  /// and gives the event loop a turn so the step's cancellation check fires.
  Future<void> _cancelCurrentStep() async {
    // Capture elapsed time within a WaitStep before cancelling.
    if (_waitStepStartTime != null) {
      _waitStepElapsedMs +=
          DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      _waitStepStartTime = null;
    }

    _cancelled = true;

    _waitCompleter?.complete();
    _waitCompleter = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    // Yield to the event loop so step handlers observe [_cancelled].
    await Future<void>.delayed(Duration.zero);
  }

  /// Returns a user-facing display text for [step].
  ///
  /// Used by [_emitState] and [getRecoverableSession] to populate
  /// [ExecutionState.currentStepText] and [ExecutionState.nextStepText].
  String _stepDisplayText(PlanStep step) => switch (step) {
        SayStep(:final text) => text,
        NotifyStep(:final title, :final body) => '$title: $body',
        PlayStep(:final audioAssetKey) => 'Playing: $audioAssetKey',
        WaitStep(:final duration) => 'Wait: ${duration.inSeconds}s',
        StopAudioStep() => 'Stop audio',
        RepeatStep(:final count) => 'Repeat x$count',
      };

  /// Emits the current [ExecutionState] on [stateStream].
  void _emitState() {
    if (_stateController.isClosed || _currentPlan == null) return;

    final flatStep = _currentStepIndex < _flatSteps.length
        ? _flatSteps[_currentStepIndex]
        : null;

    final nextFlatStep = (_currentStepIndex + 1) < _flatSteps.length
        ? _flatSteps[_currentStepIndex + 1]
        : null;

    final state = ExecutionState(
      plan: _currentPlan!,
      currentStepIndex: _currentStepIndex,
      timeRemaining: _computeTimeRemaining(),
      status: _status,
      repeatCounters: flatStep?.repeatCounters ?? const {},
      ambientPositionMs:
          _audioEngine.currentAmbientPosition?.inMilliseconds ?? 0,
      currentStepText:
          flatStep != null ? _stepDisplayText(flatStep.step) : null,
      nextStepText:
          nextFlatStep != null ? _stepDisplayText(nextFlatStep.step) : null,
      currentStepType: flatStep?.step.type,
    );
    _lastState = state;
    _stateController.add(state);
  }

  /// Computes the time remaining for the current step.
  Duration _computeTimeRemaining() {
    if (_flatSteps.isEmpty || _currentStepIndex >= _flatSteps.length) {
      return Duration.zero;
    }

    final step = _flatSteps[_currentStepIndex].step;

    if (step is WaitStep) {
      var elapsed = _waitStepElapsedMs;
      if (_waitStepStartTime != null) {
        elapsed += DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      }
      final remainingMs =
          (step.duration.inMilliseconds - elapsed).clamp(0, step.duration.inMilliseconds);
      return Duration(milliseconds: remainingMs);
    }

    return step.estimatedStepDuration;
  }

  /// Writes the current execution state to the [ExecutionStateTable].
  ///
  /// Uses DELETE + INSERT rather than an upsert because [ExecutionStateTable]
  /// does not have a UNIQUE constraint on [planId] (only the PK `id` is
  /// unique, which is auto-assigned).
  Future<void> _persistState() async {
    final plan = _currentPlan;
    if (plan == null) return;

    final flatStep = _currentStepIndex < _flatSteps.length
        ? _flatSteps[_currentStepIndex]
        : null;

    final repeatCountersJson = jsonEncode(flatStep?.repeatCounters ?? {});
    final ambientPositionMs =
        _audioEngine.currentAmbientPosition?.inMilliseconds ?? 0;

    // Compute elapsed ms within the current WaitStep.
    var waitElapsedMs = _waitStepElapsedMs;
    if (_waitStepStartTime != null) {
      waitElapsedMs +=
          DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
    }

    await _db.transaction(() async {
      // Remove any existing row for this plan.
      await (_db.delete(_db.executionStateTable)
            ..where((t) => t.planId.equals(plan.id)))
          .go();

      // Insert fresh state.
      await _db.into(_db.executionStateTable).insert(
        ExecutionStateTableCompanion(
          planId: Value(plan.id),
          currentStepIndex: Value(_currentStepIndex),
          repeatCounters: Value(repeatCountersJson),
          elapsedMs: Value(waitElapsedMs),
          ambientPositionMs: Value(ambientPositionMs),
          status: Value(_status.name),
        ),
      );
    });
  }

  /// Removes the persisted execution state row for the current plan.
  Future<void> _clearPersistedState() async {
    final plan = _currentPlan;
    if (plan == null) return;

    await (_db.delete(_db.executionStateTable)
          ..where((t) => t.planId.equals(plan.id)))
        .go();
  }

  // ── Plan flattening ───────────────────────────────────────────────────────

  /// Recursively expands [steps] into a flat list, expanding [RepeatStep]
  /// blocks inline for each iteration.
  ///
  /// [parentRepeatCounters] accumulates the iteration context for nested
  /// repeat blocks. It is passed down via recursion and captured in each
  /// [_FlatStep] to enable "Iteration N of M" display in the UI.
  List<_FlatStep> _flattenPlan(
    List<PlanStep> steps, {
    Map<String, int> parentRepeatCounters = const {},
  }) {
    final result = <_FlatStep>[];

    for (final step in steps) {
      switch (step) {
        case RepeatStep(:final id, :final count, :final children):
          for (var iteration = 1; iteration <= count; iteration++) {
            final counters = {...parentRepeatCounters, id: iteration};
            result.addAll(
              _flattenPlan(children, parentRepeatCounters: counters),
            );
          }
        default:
          result.add(_FlatStep(
            step: step,
            repeatCounters: Map.unmodifiable(parentRepeatCounters),
          ));
      }
    }

    return result;
  }

  // ── DB helpers ────────────────────────────────────────────────────────────

  /// Converts a [PlansTableData] row to a domain [Plan].
  Plan _rowToPlan(PlansTableData row) {
    return Plan(
      id: row.id,
      name: row.name,
      description: row.description,
      category: PlanCategory.values.firstWhere(
        (c) => c.name == row.category,
        orElse: () => PlanCategory.custom,
      ),
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      steps: row.steps,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastUsedAt: row.lastUsedAt,
    );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Closes the [stateStream] controller.
  ///
  /// Called by the Riverpod provider's [onDispose] callback and in tests
  /// during tearDown. Idempotent — safe to call multiple times.
  Future<void> dispose() async {
    if (!_stateController.isClosed) {
      await _stateController.close();
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ────────────────────────────────────────────────────────────────────────────

/// Singleton [PlanExecutionEngine] provider.
///
/// [keepAlive: true] ensures the engine (and its [stateStream]) persists for
/// the entire app session.
///
/// Override in tests with a fake implementation:
/// ```dart
/// ProviderScope(
///   overrides: [
///     planExecutionEngineProvider.overrideWithValue(FakePlanExecutionEngine()),
///   ],
/// )
/// ```
@Riverpod(keepAlive: true)
PlanExecutionEngine planExecutionEngine(Ref ref) {
  final engine = PlanExecutionEngineImpl(
    audioEngine: ref.watch(audioEngineProvider),
    ttsService: ref.watch(ttsServiceProvider),
    notificationService: ref.watch(notificationServiceProvider),
    db: ref.watch(appDatabaseProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
}
