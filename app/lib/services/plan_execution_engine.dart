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
import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
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
    this.ambientAssetKey,
    this.currentStepText,
    this.nextStepText,
    this.currentStepType,
    this.currentStepDuration = Duration.zero,
    this.nextStepType,
    this.stepPhase = StepPhase.active,
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

  /// The asset key of the ambient track currently playing, or `null`.
  ///
  /// Populated from [AudioEngine.currentAmbientAssetKey] in [_emitState] and
  /// [getRecoverableSession]. Surfaces the ambient asset key to UI consumers
  /// and lock screen handlers, and aids crash-recovery debugging.
  final String? ambientAssetKey;

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

  /// Full duration of the current step.
  ///
  /// For [WaitStep] this is the complete wait duration (not the remaining
  /// time). For all other step types it is [PlanStep.estimatedStepDuration].
  /// Used by [StepCountdownTimer] to compute a stable arc fraction from
  /// `timeRemaining / currentStepDuration`.
  final Duration currentStepDuration;

  /// The [StepType] of the *next* flattened step, or `null` when the current
  /// step is the last one. Used by [NextUpPreview] to display the correct
  /// step-type icon and colour.
  final StepType? nextStepType;

  /// Sub-phase within the current step. Defaults to [StepPhase.active].
  ///
  /// Set to [StepPhase.loadingTts] while a TTS cache miss is being resolved
  /// via the backend API, and to [StepPhase.ambientDisplay] during the
  /// 2-second ambient info pause after a [PlayStep] starts.
  final StepPhase stepPhase;
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
class PlanExecutionEngineImpl
    with WidgetsBindingObserver
    implements PlanExecutionEngine {
  PlanExecutionEngineImpl({
    required AudioEngine audioEngine,
    required TTSService ttsService,
    required NotificationService notificationService,
    required AppDatabase db,
  })  : _audioEngine = audioEngine,
        _ttsService = ttsService,
        _notificationService = notificationService,
        _db = db {
    WidgetsBinding.instance.addObserver(this);
  }

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

  /// Sub-phase within the currently executing step (for UI loading states).
  StepPhase _currentStepPhase = StepPhase.active;

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

  /// Wall-clock deadline for the current wait (WaitStep or ambientDisplay).
  ///
  /// Stored as an instance field so that [didChangeAppLifecycleState] can
  /// detect an expired wait when iOS resumes the app after a long suspension
  /// where [Timer.periodic] may have stopped firing entirely.
  DateTime? _waitDeadline;

  /// How often to persist elapsed time during a long WaitStep so that crash
  /// recovery doesn't lose progress if iOS kills the app.
  static const _waitStepPersistInterval = Duration(minutes: 2);

  /// Tracks when we last persisted state mid-WaitStep.
  DateTime? _lastMidWaitPersistTime;

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

  /// Completed by [_cancelCurrentStep] to unblock any `Future.any` in
  /// [_executeSayStep] that is waiting on a long-running async op (e.g. an
  /// HTTP TTS call).  A new completer is created at the start of each step.
  Completer<void>? _stepCancelCompleter;

  // ── Loop guard mutex ───────────────────────────────────────────────────────

  /// True while [_runFromCurrentStep] is executing.
  bool _loopRunning = false;

  /// Completed (and set to null) when the current [_runFromCurrentStep]
  /// invocation exits via its try/finally block. Awaited by [skipForward],
  /// [skipBackward], and [resume] before resetting [_cancelled] and starting a
  /// new loop, ensuring that long-running async ops (like [renderTTS] over the
  /// network) from the old loop cannot continue after the new loop starts.
  Completer<void>? _loopDoneCompleter;

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

    // Capture ambient state BEFORE stopAll() clears it — stopAll() sets
    // currentAmbientPosition/currentAmbientAssetKey to null, so we must
    // snapshot them here for crash recovery / resume.
    final ambientPositionMs =
        _audioEngine.currentAmbientPosition?.inMilliseconds ?? 0;
    final ambientAssetKey = _audioEngine.currentAmbientAssetKey;

    _cancelled = true;
    _status = ExecutionStatus.paused;

    // Unblock the WaitStep completer so the loop exits promptly.
    _waitCompleter?.complete();
    _waitCompleter = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    // Stop all audio — this also unblocks any pending playVoice() awaiter.
    await _audioEngine.stopAll();

    // Stop any in-progress platform TTS speech (speakDirect fallback).
    // Without this, platform TTS can continue speaking for up to 30 s after
    // the user pauses when _executeSayStep fell back to _speakDirectFallback.
    await _ttsService.stopSpeaking();

    _emitState();
    await _persistState(
      ambientPositionMsOverride: ambientPositionMs,
      ambientAssetKeyOverride: ambientAssetKey,
    );
  }

  @override
  Future<void> resume() async {
    if (_status != ExecutionStatus.paused) return;

    // Wait for any in-progress execution loop to exit before starting a new one.
    // This ensures the old loop's long-running async ops (e.g. renderTTS) have
    // fully unwound before we reset _cancelled and launch a new loop.
    await _loopDoneCompleter?.future;

    _cancelled = false;
    _status = ExecutionStatus.running;

    // Restore the ambient track that was playing when we paused, then seek
    // to the persisted position so the listener hears a seamless resume.
    final rows = await (_db.select(_db.executionStateTable)
          ..where((t) => t.planId.equals(_currentPlan!.id))
          ..limit(1))
        .get();

    if (rows.isNotEmpty) {
      final row = rows.first;
      if (row.ambientAssetKey != null) {
        // Restart the ambient track that was playing before the pause.
        try {
          await _audioEngine.startAmbient(row.ambientAssetKey!);
          if (row.ambientPositionMs > 0) {
            await _audioEngine
                .seekAmbient(Duration(milliseconds: row.ambientPositionMs));
          }
        } catch (e) {
          debugPrint(
            'PlanExecutionEngine: ambient restore on resume failed: $e',
          );
        }
      } else if (row.ambientPositionMs > 0) {
        // Legacy rows without assetKey: best-effort seek only.
        try {
          await _audioEngine
              .seekAmbient(Duration(milliseconds: row.ambientPositionMs));
        } catch (e) {
          debugPrint('PlanExecutionEngine: seekAmbient on resume failed: $e');
        }
      }
    }

    _emitState();
    await _persistState();
    unawaited(_runFromCurrentStep());
  }

  @override
  Future<void> skipForward() async {
    if (_status == ExecutionStatus.idle) return;
    await _cancelCurrentStep();
    // Stop audio BEFORE resetting _cancelled so the old execution loop's
    // pending playVoice() is unblocked and can observe _cancelled == true
    // and exit cleanly — preventing two concurrent execution loops.
    await _audioEngine.stopAll();

    // Wait for the old execution loop to exit completely.
    // _cancelCurrentStep() sets _cancelled=true and yields once with
    // Future.delayed(Duration.zero), which is insufficient when renderTTS is
    // awaiting a long-running network call. This mutex await serialises the
    // old loop's exit with the new loop's start.
    await _loopDoneCompleter?.future;

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
    // Stop audio BEFORE resetting _cancelled so the old execution loop's
    // pending playVoice() is unblocked and can observe _cancelled == true
    // and exit cleanly — preventing two concurrent execution loops.
    await _audioEngine.stopAll();

    // Wait for the old execution loop to exit completely.
    // _cancelCurrentStep() sets _cancelled=true and yields once with
    // Future.delayed(Duration.zero), which is insufficient when renderTTS is
    // awaiting a long-running network call. This mutex await serialises the
    // old loop's exit with the new loop's start.
    await _loopDoneCompleter?.future;

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
      _ttsService.stopSpeaking(),
      _notificationService.cancelAll(),
    ]);

    await _clearPersistedState();

    _currentPlan = null;
    _lastState = null;
    _flatSteps = [];
    _currentStepIndex = 0;
    _waitStepElapsedMs = 0;
    _speedMultiplier = 1.0;
    _waitDeadline = null;
    _lastMidWaitPersistTime = null;
  }

  // ── App lifecycle observer ────────────────────────────────────────────────

  /// Called by the framework when the app transitions between lifecycle states.
  ///
  /// When the app returns to the foreground after a long background period
  /// (iOS suspension / Android Doze), [Timer.periodic] callbacks may have
  /// stopped firing entirely. This observer catches up by checking whether
  /// the active wait deadline has already passed and, if so, completing the
  /// wait immediately. It also restarts the silence keep-alive in case the
  /// OS killed the audio session during suspension.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_status != ExecutionStatus.running) return;

    final deadline = _waitDeadline;
    final completer = _waitCompleter;
    if (deadline == null || completer == null || completer.isCompleted) return;

    if (DateTime.now().isAfter(deadline)) {
      // Deadline passed while the OS suspended us — complete immediately.
      debugPrint(
        'PlanExecutionEngine: app resumed after deadline passed '
        '(deadline=$deadline) — completing wait.',
      );
      _waitTimer?.cancel();
      _waitTimer = null;
      completer.complete();
    } else {
      // Still within the wait — restart silence keep-alive in case the OS
      // killed the audio session during suspension.
      debugPrint(
        'PlanExecutionEngine: app resumed, wait still active — '
        'restarting silence keep-alive.',
      );
      unawaited(_audioEngine.startSilenceKeepAlive().catchError((_) {}));
    }
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
      ambientAssetKey: row.ambientAssetKey,
      currentStepText: currentFlatStep != null
          ? _stepDisplayText(currentFlatStep.step)
          : null,
      nextStepText:
          nextFlatStep != null ? _stepDisplayText(nextFlatStep.step) : null,
      currentStepType: currentFlatStep?.step.type,
      currentStepDuration: currentFlatStep != null
          ? _computeStepDuration(currentFlatStep.step)
          : Duration.zero,
      nextStepType: nextFlatStep?.step.type,
    );
  }

  // ── Execution loop ────────────────────────────────────────────────────────

  /// Runs steps sequentially starting from [_currentStepIndex].
  ///
  /// Exits when the plan completes, [_cancelled] is set to true, or an
  /// unrecoverable error occurs.
  ///
  /// A try/finally block sets [_loopRunning] on entry and completes
  /// [_loopDoneCompleter] on exit, forming the loop guard mutex. This ensures
  /// that callers awaiting [_loopDoneCompleter] are unblocked even when the
  /// loop exits via an exception.
  Future<void> _runFromCurrentStep() async {
    _loopRunning = true;
    _loopDoneCompleter = Completer<void>();
    try {
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
    } finally {
      _loopRunning = false;
      if (!_loopDoneCompleter!.isCompleted) {
        _loopDoneCompleter!.complete();
      }
      _loopDoneCompleter = null;
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
      case CountStep(:final from, :final to, :final intervalSeconds):
        await _executeCountStep(
          from: from,
          to: to,
          intervalSeconds: intervalSeconds,
          voiceId: _currentPlan!.defaultVoice,
        );
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

    // Single try/finally guarantees restoreAmbient on every exit path.
    // playVoice internally restores ambient on success; we track this to
    // avoid a redundant second restore in the happy path.
    // Create a fresh cancel signal for this step so that pause/stop/skip can
    // unblock a long-running renderTTS HTTP call immediately.
    _stepCancelCompleter = Completer<void>();

    var voicePlayedSuccessfully = false;
    try {
      if (_cancelled) return;

      // Signal UI: TTS is loading (visible on cache miss, instant on hit).
      _currentStepPhase = StepPhase.loadingTts;
      _emitState();

      // Resolve the cached audio file path (or render on a miss).
      // Future.any races the TTS call against the cancel signal so that
      // pause/stop/skip unblock immediately instead of waiting for the HTTP
      // timeout (up to 60 s).
      String? path;
      try {
        // Start TTS rendering. If the step is cancelled while the network
        // call is in-flight, we still wait for renderTTS to finish so that
        // errors (SocketException, timeout, etc.) are surfaced and the
        // fallback chain can run. Without this, cancellation would swallow
        // the TTS error and skip the fallback entirely.
        final ttsFuture =
            _ttsService.renderTTS(text: text, voiceId: voiceId);

        // Also listen for the cancel signal so we know if pause/stop/skip
        // was requested, but do NOT let it short-circuit error handling.
        var cancelled = false;
        unawaited(
          _stepCancelCompleter!.future.then((_) {
            cancelled = true;
          }),
        );

        String ttsResult;
        try {
          debugPrint('PlanExecutionEngine: [SAY] awaiting ttsFuture…');
          ttsResult = await ttsFuture;
          debugPrint('PlanExecutionEngine: [SAY] ttsFuture resolved OK');
        } catch (e) {
          debugPrint('PlanExecutionEngine: [SAY] ttsFuture threw ${e.runtimeType}: $e');
          // debugger(message: 'ttsFuture THREW ${e.runtimeType} — cancelled=$_cancelled');
          rethrow;
        }

        if (_cancelled || cancelled) return;
        path = ttsResult;
        debugPrint('PlanExecutionEngine: [SAY] renderTTS succeeded — path=$path');
      } on TtsFallbackException catch (e) {
        // debugger(message: 'CATCH TtsFallbackException — cancelled=$_cancelled — $e');
        if (_cancelled) return;
        // Backend offline/timeout — render via platform TTS to a file and
        // play through the audio engine. Does NOT cache in the TTS DB.
        debugPrint('PlanExecutionEngine: [SAY] backend unavailable, using platform TTS file fallback');
        // debugger(message: 'FALLBACK: TtsFallbackException — $e');
        _currentStepPhase = StepPhase.active;
        _emitState();
        voicePlayedSuccessfully = await _platformTtsFallback(text);
        return;
      } on TtsApiException catch (e) {
        // debugger(message: 'CATCH TtsApiException — cancelled=$_cancelled — $e');
        if (_cancelled) return;
        if (e.statusCode == 401) {
          debugPrint('PlanExecutionEngine: auth expired, stopping plan');
          await stop();
          return;
        }
        debugPrint('PlanExecutionEngine: TTS API error for "$text": $e');
        // debugger(message: 'FALLBACK: TtsApiException status=${e.statusCode} — $e');
        _currentStepPhase = StepPhase.active;
        _emitState();
        voicePlayedSuccessfully = await _platformTtsFallback(text);
        return;
      } catch (e) {
        // debugger(message: 'CATCH generic — cancelled=$_cancelled — ${e.runtimeType}: $e');
        if (_cancelled) return;
        debugPrint('PlanExecutionEngine: TTS render failed for "$text": $e');
        _currentStepPhase = StepPhase.active;
        _emitState();
        voicePlayedSuccessfully = await _platformTtsFallback(text);
        return;
      }

      if (_cancelled) return;

      // TTS file is ready — switch back to active phase before playback.
      _currentStepPhase = StepPhase.active;
      _emitState();

      // Read the user's preferred speech rate before playback.
      final rateRow = await (_db.select(_db.appSettingsTable)
            ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
          .getSingleOrNull();
      final speed = double.tryParse(rateRow?.value ?? '') ?? 1.0;

      // Play voice and wait for completion. AudioEngineImpl.playVoice awaits
      // completion and automatically restores ambient volume when done.
      debugPrint('PlanExecutionEngine: [SAY] playing voice — path=$path, speed=$speed');
      // debugger(message: 'BEFORE playVoice — path=$path, speed=$speed, cancelled=$_cancelled');
      try {
        await _audioEngine.playVoice(path, speed: speed);
        debugPrint('PlanExecutionEngine: [SAY] playVoice completed');
        voicePlayedSuccessfully = true;
      } catch (e) {
        debugPrint('PlanExecutionEngine: playVoice failed: $e');
        if (e is StoppedByUserException || _cancelled) {
          return;
        }
        // Fallback to platform TTS file when audio file playback fails.
        debugPrint('PlanExecutionEngine: [SAY] playVoice failed, trying platform TTS file fallback');
        voicePlayedSuccessfully = await _platformTtsFallback(text);
      }
    } finally {
      // Always clear the loading phase and notify the UI — without this the
      // Now Playing screen would stay stuck on the spinner if any code path
      // above returns early (e.g. _cancelled, fallback, error).
      if (_currentStepPhase != StepPhase.active) {
        _currentStepPhase = StepPhase.active;
        _emitState();
      }
      // Guarantee ambient is restored on every exit path.  Skip only when
      // playVoice already handled restoration internally (happy path).
      if (!voicePlayedSuccessfully) {
        try {
          await _audioEngine.restoreAmbient();
        } catch (e) {
          debugPrint(
            'PlanExecutionEngine: restoreAmbient failed (non-fatal): $e',
          );
        }
      }
    }
    debugPrint('PlanExecutionEngine: [SAY] step done');
  }

  /// Renders [text] to a file via platform TTS and plays it through the audio
  /// engine. Does NOT cache the result in the TTS cache database.
  ///
  /// Returns `true` if the voice was played successfully through the audio
  /// engine (meaning ambient was already restored by playVoice internally).
  ///
  /// Falls back to [_speakDirectFallback] if file synthesis or playback fails.
  Future<bool> _platformTtsFallback(String text) async {
    if (_cancelled) return false;
    debugPrint('PlanExecutionEngine: [FALLBACK] platformTts starting — text="${text.length > 50 ? '${text.substring(0, 50)}…' : text}"');
    // debugger(message: 'PLATFORM TTS FALLBACK entry — text="${text.length > 30 ? '${text.substring(0, 30)}…' : text}"');
    try {
      final path = await _ttsService.renderWithPlatformTTS(text);
      if (_cancelled) return false;
      final rateRow = await (_db.select(_db.appSettingsTable)
            ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
          .getSingleOrNull();
      final speed = double.tryParse(rateRow?.value ?? '') ?? 1.0;
      debugPrint('PlanExecutionEngine: [FALLBACK] playing platform TTS file — path=$path, speed=$speed');
      await _audioEngine.playVoice(path, speed: speed);
      debugPrint('PlanExecutionEngine: [FALLBACK] platform TTS playback completed');
      return true;
    } catch (e) {
      debugPrint('PlanExecutionEngine: platform TTS file fallback failed: $e');
      // debugger(message: 'PLATFORM TTS FAILED — ${e.runtimeType}: $e → falling to speakDirect');
      if (e is StoppedByUserException || _cancelled) return false;
      // Last resort: speak directly through the device speaker.
      await _speakDirectFallback(text);
      return false;
    }
  }

  /// Speaks [text] directly via [TTSService.speakDirect] as a last-resort
  /// fallback when both backend TTS and platform TTS file synthesis fail.
  ///
  /// Ambient restoration is handled by the caller's try/finally block in
  /// [_executeSayStep], so this method intentionally does NOT call
  /// [AudioEngine.restoreAmbient].
  Future<void> _speakDirectFallback(String text) async {
    if (_cancelled) return;
    debugPrint('PlanExecutionEngine: [FALLBACK] speakDirect starting — text="${text.length > 50 ? '${text.substring(0, 50)}…' : text}"');
    // debugger(message: 'SPEAK DIRECT (last resort) entry');
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
    debugPrint('PlanExecutionEngine: [FALLBACK] done');
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

    // Hold on this step for 2 seconds so the UI displays the ambient track
    // info before advancing. Only for looping ambient tracks — one-shot effects
    // (bell, chime) don't need a visual pause. Uses the same
    // _waitCompleter/_waitTimer pattern as _executeWaitStep so pause/skip can
    // interrupt the display period.
    if (_cancelled || !loop) return;

    _currentStepPhase = StepPhase.ambientDisplay;
    _emitState();

    try {
      _waitCompleter = Completer<void>();
      _waitDeadline = DateTime.now().add(const Duration(seconds: 2));
      _waitTimer = Timer(const Duration(seconds: 2), () {
        if (!(_waitCompleter?.isCompleted ?? true)) {
          _waitCompleter!.complete();
        }
      });

      await _waitCompleter!.future;
      _waitCompleter = null;
      _waitDeadline = null;
      _waitTimer?.cancel();
      _waitTimer = null;
    } finally {
      _currentStepPhase = StepPhase.active;
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

    // Start silent keep-alive so the OS doesn't suspend the app during silence.
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
    _lastMidWaitPersistTime = _waitStepStartTime;

    // Compute the wall-clock deadline so the periodic timer can detect
    // completion even if the Dart isolate was briefly suspended by the OS.
    final deadline = _waitStepStartTime!.add(remaining);
    _waitDeadline = deadline;

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

      final now = DateTime.now();

      if (now.isAfter(deadline)) {
        _waitTimer?.cancel();
        _waitTimer = null;
        if (!(_waitCompleter?.isCompleted ?? true)) {
          _waitCompleter!.complete();
        }
        return;
      }

      // Periodically persist elapsed time so that if the OS kills the app,
      // crash recovery can resume close to where we left off instead of
      // restarting the entire WaitStep from zero.
      if (_lastMidWaitPersistTime != null &&
          now.difference(_lastMidWaitPersistTime!) >=
              _waitStepPersistInterval) {
        _lastMidWaitPersistTime = now;
        unawaited(_persistState());
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
    _waitDeadline = null;
    _waitTimer?.cancel();
    _waitTimer = null;

    if (!_cancelled) {
      // Step completed normally — reset elapsed tracking.
      _waitStepElapsedMs = 0;
      _waitStepStartTime = null;
    }

    _lastMidWaitPersistTime = null;

    try {
      await _audioEngine.stopSilenceKeepAlive();
    } catch (e) {
      debugPrint('PlanExecutionEngine: stopSilenceKeepAlive error: $e');
    }
  }

  // ── Count step ─────────────────────────────────────────────────────────

  /// Cache of TTS-rendered number audio paths for the current session.
  /// Keyed by "$voiceId:$number" so different voices get separate cache entries.
  final Map<String, String> _numberAudioPaths = {};

  /// Executes a [CountStep] — counts aloud from [from] to [to] with
  /// [intervalSeconds] seconds between each number.
  ///
  /// Uses backend TTS (same voice as SayStep) with fallback to platform TTS.
  /// Reuses [_waitStepElapsedMs] / [_waitStepStartTime] for crash recovery
  /// and pause/resume, following the same pattern as [_executeWaitStep].
  Future<void> _executeCountStep({
    required int from,
    required int to,
    required int intervalSeconds,
    required String voiceId,
  }) async {
    if (_cancelled) return;

    final intervalMs = intervalSeconds * 1000;
    debugPrint(
      'PlanExecutionEngine: [COUNT] starting — from=$from, to=$to, '
      'interval=${intervalSeconds}s, voice=$voiceId',
    );

    // Start silence keep-alive so the OS doesn't suspend the app.
    try {
      await _audioEngine.startSilenceKeepAlive();
    } catch (e) {
      debugPrint('PlanExecutionEngine: startSilenceKeepAlive error: $e');
    }

    final direction = from <= to ? 1 : -1;
    final totalNumbers = (to - from).abs() + 1;

    // Resume support: skip numbers already counted (from _waitStepElapsedMs).
    final resumeCount = (_waitStepElapsedMs / intervalMs).floor();
    var numbersSpoken = resumeCount.clamp(0, totalNumbers);
    var currentNumber = from + (direction * numbersSpoken);

    _waitCompleter = Completer<void>();
    _waitStepStartTime = DateTime.now();
    _lastMidWaitPersistTime = _waitStepStartTime;

    while (numbersSpoken < totalNumbers && !_cancelled) {
      // Speak the current number using backend TTS (same as SayStep),
      // falling back to platform TTS, then speakDirect.
      try {
        final filePath =
            await _getNumberAudioPath(currentNumber, voiceId);
        if (_cancelled) break;
        await _audioEngine.playVoice(filePath);
      } catch (e) {
        if (_cancelled) break;
        debugPrint('PlanExecutionEngine: CountStep voice error: $e');
        // Fallback: speak directly through the device speaker.
        try {
          await _ttsService.speakDirect(currentNumber.toString());
        } catch (_) {}
      }

      numbersSpoken++;
      currentNumber += direction;

      if (numbersSpoken >= totalNumbers || _cancelled) break;

      // Wait for the remainder of the interval.
      final effectiveIntervalMs = _speedMultiplier > 1.0
          ? (intervalMs / _speedMultiplier).round()
          : intervalMs;
      final elapsed =
          DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      final expectedElapsed = numbersSpoken * effectiveIntervalMs;
      final delayMs =
          (expectedElapsed - elapsed).clamp(0, effectiveIntervalMs);

      if (delayMs > 0 && !_cancelled) {
        _waitDeadline =
            DateTime.now().add(Duration(milliseconds: delayMs));
        final delayCompleter = Completer<void>();
        _waitTimer = Timer(Duration(milliseconds: delayMs), () {
          if (!delayCompleter.isCompleted) delayCompleter.complete();
        });
        try {
          await Future.any([
            delayCompleter.future,
            if (_stepCancelCompleter != null) _stepCancelCompleter!.future,
          ]);
        } finally {
          _waitTimer?.cancel();
          _waitTimer = null;
        }
        if (_cancelled) break;
      }

      // Update elapsed time for crash recovery and emit state.
      _waitStepElapsedMs = numbersSpoken * intervalMs;
      _emitState();

      // Periodic persistence (same pattern as WaitStep).
      if (_lastMidWaitPersistTime != null &&
          DateTime.now().difference(_lastMidWaitPersistTime!) >=
              _waitStepPersistInterval) {
        _lastMidWaitPersistTime = DateTime.now();
        unawaited(_persistState());
      }
    }

    // Cleanup (same pattern as _executeWaitStep).
    _waitCompleter = null;
    _waitDeadline = null;
    _waitTimer?.cancel();
    _waitTimer = null;

    if (!_cancelled) {
      _waitStepElapsedMs = 0;
      _waitStepStartTime = null;
    }
    _lastMidWaitPersistTime = null;

    try {
      await _audioEngine.stopSilenceKeepAlive();
    } catch (e) {
      debugPrint('PlanExecutionEngine: stopSilenceKeepAlive error: $e');
    }
  }

  /// Returns a cached file path for the TTS-rendered [number].
  ///
  /// Tries backend TTS first (same voice as the plan's SayStep), falling
  /// back to platform TTS on network/API errors.
  Future<String> _getNumberAudioPath(int number, String voiceId) async {
    final cacheKey = '$voiceId:$number';
    final cached = _numberAudioPaths[cacheKey];
    if (cached != null) return cached;

    try {
      final path = await _ttsService.renderTTS(
        text: number.toString(),
        voiceId: voiceId,
      );
      _numberAudioPaths[cacheKey] = path;
      return path;
    } catch (e) {
      debugPrint(
        'PlanExecutionEngine: backend TTS for number $number failed: $e',
      );
      // Fallback to platform TTS.
      final path =
          await _ttsService.renderWithPlatformTTS(number.toString());
      _numberAudioPaths[cacheKey] = path;
      return path;
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
    debugPrint('PlanExecutionEngine: _cancelCurrentStep() called');
    // debugger(message: '_cancelCurrentStep called — check call stack');
    // Capture elapsed time within a WaitStep before cancelling.
    if (_waitStepStartTime != null) {
      _waitStepElapsedMs +=
          DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      _waitStepStartTime = null;
    }

    _cancelled = true;

    // Unblock any Future.any in _executeSayStep waiting on renderTTS / platform
    // TTS so the old loop can exit promptly instead of hanging until the HTTP
    // timeout fires.
    if (_stepCancelCompleter != null && !_stepCancelCompleter!.isCompleted) {
      _stepCancelCompleter!.complete();
    }

    _waitCompleter?.complete();
    _waitCompleter = null;
    _waitDeadline = null;

    _waitTimer?.cancel();
    _waitTimer = null;

    _lastMidWaitPersistTime = null;

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
        CountStep(:final from, :final to, :final intervalSeconds) =>
          '${from <= to ? 'Count' : 'Countdown'}: $from \u2192 $to'
          '${intervalSeconds > 1 ? ' (every ${intervalSeconds}s)' : ''}',
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
      ambientAssetKey: _audioEngine.currentAmbientAssetKey,
      currentStepText:
          flatStep != null ? _stepDisplayText(flatStep.step) : null,
      nextStepText:
          nextFlatStep != null ? _stepDisplayText(nextFlatStep.step) : null,
      currentStepType: flatStep?.step.type,
      currentStepDuration: flatStep != null
          ? _computeStepDuration(flatStep.step)
          : Duration.zero,
      nextStepType: nextFlatStep?.step.type,
      stepPhase: _currentStepPhase,
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

    if (step is WaitStep || step is CountStep) {
      final totalMs = step.estimatedStepDuration.inMilliseconds;
      var elapsed = _waitStepElapsedMs;
      if (_waitStepStartTime != null) {
        elapsed += DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
      }
      final remainingMs = (totalMs - elapsed).clamp(0, totalMs);
      return Duration(milliseconds: remainingMs);
    }

    return step.estimatedStepDuration;
  }

  /// Returns the full duration of [step] for use as [ExecutionState.currentStepDuration].
  ///
  /// For timed steps ([WaitStep], [CountStep]) this is the total duration (not
  /// remaining time) so that [StepCountdownTimer] can compute a stable arc
  /// from `timeRemaining / currentStepDuration`.
  Duration _computeStepDuration(PlanStep step) => step.estimatedStepDuration;

  /// Writes the current execution state to the [ExecutionStateTable].
  ///
  /// Uses DELETE + INSERT rather than an upsert because [ExecutionStateTable]
  /// does not have a UNIQUE constraint on [planId] (only the PK `id` is
  /// unique, which is auto-assigned).
  ///
  /// [ambientPositionMsOverride] and [ambientAssetKeyOverride] allow callers
  /// (e.g. [pause]) to supply values captured *before* [AudioEngine.stopAll]
  /// clears the engine's live position/key fields.
  Future<void> _persistState({
    int? ambientPositionMsOverride,
    String? ambientAssetKeyOverride,
  }) async {
    final plan = _currentPlan;
    if (plan == null) return;

    final flatStep = _currentStepIndex < _flatSteps.length
        ? _flatSteps[_currentStepIndex]
        : null;

    final repeatCountersJson = jsonEncode(flatStep?.repeatCounters ?? {});

    // Use caller-supplied values if provided (e.g. captured before stopAll).
    final ambientPositionMs = ambientPositionMsOverride ??
        (_audioEngine.currentAmbientPosition?.inMilliseconds ?? 0);
    final ambientAssetKey =
        ambientAssetKeyOverride ?? _audioEngine.currentAmbientAssetKey;

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
          ambientAssetKey: Value(ambientAssetKey),
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
    WidgetsBinding.instance.removeObserver(this);
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
