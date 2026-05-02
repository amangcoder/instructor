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
import 'package:instructor/providers/tts_status_providers.dart';
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
// Persisted session summary (lightweight DB read result)
// ────────────────────────────────────────────────────────────────────────────

/// Lightweight summary of a persisted execution session returned by
/// [PlanExecutionEngine.getPersistedSessionSummaryForPlan].
///
/// Unlike [getRecoverableSession], this does **not** restore engine state —
/// it is safe to call before the user confirms they want to resume.
class PersistedSessionSummary {
  const PersistedSessionSummary({
    required this.stepIndex,
    required this.elapsedMs,
  });

  /// 0-based flattened step index of the paused/interrupted session.
  final int stepIndex;

  /// Total elapsed milliseconds accumulated in the current step at pause time.
  final int elapsedMs;
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

  /// Begins executing [plan] at the given [flatStepIndex] (mid-plan start).
  ///
  /// [flatStepIndex] is the index into the flattened step list produced by
  /// expanding all [RepeatStep] blocks. Callers can compute this by summing
  /// the flat-expansion counts for each top-level step before the target
  /// (see [flatStepCountForSteps]).
  ///
  /// If [flatStepIndex] is out of range (< 0 or ≥ total flat steps), the
  /// call is treated as a normal [startPlan] from step 0.
  Future<void> startPlanFromStep(Plan plan, int flatStepIndex);

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

  /// Returns a lightweight summary of any persisted session for [planId].
  ///
  /// Returns the [PersistedSessionSummary] (step index + elapsed ms) without
  /// restoring engine state, so it is safe to call before the user confirms
  /// they want to resume. Returns `null` when no session exists.
  Future<PersistedSessionSummary?> getPersistedSessionSummaryForPlan(
      String planId);

  /// Returns a recoverable session if one exists (for crash recovery on launch).
  ///
  /// Also restores the engine's internal state so that [resume] can be called
  /// immediately after the user confirms they want to resume.
  ///
  /// If [planId] is provided, only the session for that specific plan is
  /// considered (used by the plan library to check before showing the
  /// "Continue where you left off?" dialog).
  Future<ExecutionState?> getRecoverableSession([String? planId]);

  /// Returns the 0-based flattened step index of any persisted session for
  /// [planId], or `null` if no recoverable session exists.
  ///
  /// This is a lightweight read-only DB query that does **not** restore the
  /// engine's internal state — safe to call before the user confirms they want
  /// to resume.
  Future<int?> getRecoverableStepIndexForPlan(String planId);

  /// Restores the persisted session for [planId] and resumes execution from
  /// the saved step and audio position.
  ///
  /// Returns `true` if a session was found and successfully resumed.
  /// Returns `false` if no recovery data exists for [planId] (caller should
  /// fall back to [startPlan]).
  Future<bool> resumeFromPersistedState(String planId);
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
    required TtsPlaybackMode Function() ttsPlaybackModeGetter,
  })  : _audioEngine = audioEngine,
        _ttsService = ttsService,
        _notificationService = notificationService,
        _db = db,
        _ttsPlaybackMode = ttsPlaybackModeGetter {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioEngine _audioEngine;
  final TTSService _ttsService;
  final NotificationService _notificationService;
  final AppDatabase _db;

  /// Returns the current [TtsPlaybackMode] at call time.
  ///
  /// Injected at construction so that tests can supply a controllable getter
  /// without depending on Riverpod. Production code passes
  /// `() => ref.read(ttsPlaybackModeProvider)`.
  ///
  /// ## Toggle-at-step-boundary semantics
  ///
  /// This getter is called **once at the start of each step** (inside
  /// [_executeSayStep] and [_getNumberAudioPath]). Because the current step
  /// has already begun executing by the time the user flips the
  /// [NowPlayingTtsToggle], the toggle has no effect on the in-flight step:
  /// it will complete in whichever mode was active when the step started.
  /// The new mode takes effect on the **next** step transition, when the
  /// execution loop calls [_executeStep] again and this getter is re-read.
  ///
  /// This behaviour is entirely natural — no extra locking or buffering is
  /// required. Changing the provider value at any point is safe; the engine
  /// will pick it up at the next step boundary.
  final TtsPlaybackMode Function() _ttsPlaybackMode;

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

  // ── Say step tracking ─────────────────────────────────────────────────────

  /// Actual duration of the currently playing voice audio file, adjusted for
  /// playback speed.
  ///
  /// Equals `raw_file_duration / _currentSayStepSpeed` so that wall-clock
  /// elapsed time can be compared directly to produce an accurate countdown.
  ///
  /// Set once [AudioEngine.currentVoiceDuration] becomes non-null after the
  /// voice player has loaded the file. Cleared when the step ends or when
  /// skip/stop is called.
  Duration? _currentSayStepActualDuration;

  /// The playback speed at which the current Say step's audio is playing.
  ///
  /// Used to convert the raw file duration (at 1× speed) to the effective
  /// wall-clock duration so the countdown timer stays in sync with the audio.
  /// Reset to 1.0 by [_stopSayStepPlaybackTimer].
  double _currentSayStepSpeed = 1.0;

  /// Timestamp when voice playback started for the current Say step.
  ///
  /// Used to compute elapsed time for the countdown timer. Set just before
  /// [AudioEngine.playVoice] is called; cleared in the step's finally block.
  DateTime? _sayStepPlaybackStartTime;

  /// Elapsed playback time (ms) accumulated before the current play call.
  ///
  /// Non-zero on resume: captures how much of the Say step had already played
  /// before a previous interruption in the same step execution. Reset to 0
  /// when a new step begins.
  int _sayStepElapsedBeforeCurrentPlayMs = 0;

  /// Periodic timer that fires every 100 ms during Say step playback to emit
  /// [ExecutionState] updates and capture the actual voice file duration.
  Timer? _sayStepProgressTimer;

  /// Subscription to speech-rate DB changes during Say step voice playback.
  ///
  /// Active only while a voice file is playing. When the user changes the
  /// speed setting (via the Now Playing speed button or Settings), this fires
  /// [_onSpeedChangedDuringPlayback] which updates the live audio player and
  /// recomputes the countdown timer to stay in sync.
  StreamSubscription<dynamic>? _speedWatchSubscription;

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

    // Reset preview speed-up. `stop()` already does this, but it's only
    // invoked above when another session was running/paused. After a preview
    // ends naturally (status → completed/idle without an explicit stop),
    // `_speedMultiplier` would otherwise leak into the next plan and play it
    // 4× too fast. `startPreview` re-applies 4× after this method returns.
    _speedMultiplier = 1.0;

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
  Future<void> startPlanFromStep(Plan plan, int flatStepIndex) async {
    // Stop any in-progress execution cleanly first.
    if (_status == ExecutionStatus.running ||
        _status == ExecutionStatus.paused) {
      await stop();
    }

    // Reset preview speed-up — see startPlan() for rationale.
    _speedMultiplier = 1.0;

    _currentPlan = plan;
    _flatSteps = _flattenPlan(plan.steps);

    // Clamp to valid range; fall back to 0 if index is out of bounds.
    _currentStepIndex =
        (flatStepIndex >= 0 && flatStepIndex < _flatSteps.length)
            ? flatStepIndex
            : 0;
    _waitStepElapsedMs = 0;
    _cancelled = false;
    _status = ExecutionStatus.running;

    _emitState();
    await _persistState();

    // Run the execution loop on the next microtask.
    unawaited(_runFromCurrentStep());
  }

  @override
  Future<void> startPreview(Plan plan) async {
    // startPlan resets `_speedMultiplier` to 1.0, so apply the preview
    // override AFTER it returns. Safe: `_runFromCurrentStep` is scheduled via
    // `unawaited` and reads `_speedMultiplier` only deep inside step execution
    // (after several awaits), well after this assignment lands.
    await startPlan(plan);
    _speedMultiplier = 4.0;
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

    // Capture elapsed time within a SayStep and stop its progress timer.
    _sayStepProgressTimer?.cancel();
    _sayStepProgressTimer = null;
    if (_sayStepPlaybackStartTime != null) {
      _sayStepElapsedBeforeCurrentPlayMs +=
          DateTime.now().difference(_sayStepPlaybackStartTime!).inMilliseconds;
      _sayStepPlaybackStartTime = null;
    }

    // Capture ambient state BEFORE stopAll() clears it — stopAll() sets
    // currentAmbientPosition/currentAmbientAssetKey to null, so we must
    // snapshot them here for crash recovery / resume.
    final ambientPositionMs =
        _audioEngine.currentAmbientPosition?.inMilliseconds ?? 0;
    final ambientAssetKey = _audioEngine.currentAmbientAssetKey;

    _cancelled = true;
    _status = ExecutionStatus.paused;

    // Unblock a pending renderTTS race so the execution loop exits promptly
    // instead of blocking until the HTTP call returns (which caused a 2-3 s
    // delay on resume).
    if (_stepCancelCompleter != null && !_stepCancelCompleter!.isCompleted) {
      _stepCancelCompleter!.complete();
    }

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
    // A 3-second timeout prevents an indefinite hang during long TTS renders.
    await _loopDoneCompleter?.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});

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
    // A 3-second timeout prevents an indefinite hang when a TTS network call
    // has not yet returned — the loop will exit once the step completes.
    await _loopDoneCompleter?.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});

    if (_currentStepIndex < _flatSteps.length - 1) {
      _currentStepIndex++;
    }
    _waitStepElapsedMs = 0;
    _stopSayStepPlaybackTimer();

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

    // At step 0: do not cancel the current step or restart anything.
    // The UI is responsible for showing "Already at first step" feedback.
    if (_currentStepIndex == 0) {
      debugPrint(
        'PlanExecutionEngine: skipBackward at step 0 — already at first step.',
      );
      return;
    }

    await _cancelCurrentStep();
    // Stop audio BEFORE resetting _cancelled so the old execution loop's
    // pending playVoice() is unblocked and can observe _cancelled == true
    // and exit cleanly — preventing two concurrent execution loops.
    await _audioEngine.stopAll();

    // Wait for the old execution loop to exit completely.
    // A 3-second timeout prevents an indefinite hang when a long-running TTS
    // render (e.g. slow network) is in-flight and has not yet returned.
    await _loopDoneCompleter?.future
        .timeout(const Duration(seconds: 3), onTimeout: () {});

    _currentStepIndex--;
    _waitStepElapsedMs = 0;
    _stopSayStepPlaybackTimer();

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

    // Emit a terminal idle state BEFORE clearing _currentPlan so that
    // subscribers (NowPlayingScreen, MiniPlayerBar, lock screen widgets) can
    // gracefully transition to their idle/hidden states. Without this emit,
    // widgets that read currentState after stop() would receive null and could
    // break (e.g. buttons become unresponsive, REQ-010/#10 fix).
    _emitState();

    _currentPlan = null;
    // Do NOT clear _lastState here — keep the terminal idle ExecutionState
    // so that late subscribers (e.g. widgets that mount after stop) can still
    // read executionStateProvider.currentState and handle idle gracefully.
    _flatSteps = [];
    _currentStepIndex = 0;
    _waitStepElapsedMs = 0;
    _stopSayStepPlaybackTimer();
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
  Future<ExecutionState?> getRecoverableSession([String? planId]) async {
    // Query for paused or running rows, most recently saved first.
    // When [planId] is provided, restrict to that plan only.
    final List<ExecutionStateTableData> rows;
    if (planId != null) {
      rows = await (_db.select(_db.executionStateTable)
            ..where(
              (t) =>
                  t.planId.equals(planId) &
                  t.status.isIn(['paused', 'running']),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
            ..limit(1))
          .get();
    } else {
      rows = await (_db.select(_db.executionStateTable)
            ..where((t) => t.status.isIn(['paused', 'running']))
            ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
            ..limit(1))
          .get();
    }

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

  @override
  Future<int?> getRecoverableStepIndexForPlan(String planId) async {
    // Lightweight read-only query — does NOT restore engine state.
    final rows = await (_db.select(_db.executionStateTable)
          ..where(
            (t) =>
                t.planId.equals(planId) &
                t.status.isIn(['paused', 'running']),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
          ..limit(1))
        .get();

    if (rows.isEmpty) return null;
    return rows.first.currentStepIndex;
  }

  @override
  Future<PersistedSessionSummary?> getPersistedSessionSummaryForPlan(
      String planId) async {
    // Lightweight read-only query — does NOT restore engine state.
    final rows = await (_db.select(_db.executionStateTable)
          ..where(
            (t) =>
                t.planId.equals(planId) &
                t.status.isIn(['paused', 'running']),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.savedAt)])
          ..limit(1))
        .get();

    if (rows.isEmpty) return null;
    final row = rows.first;
    return PersistedSessionSummary(
      stepIndex: row.currentStepIndex,
      elapsedMs: row.elapsedMs,
    );
  }

  @override
  Future<bool> resumeFromPersistedState(String planId) async {
    // Load persisted state into the engine for this specific plan.
    final session = await getRecoverableSession(planId);
    if (session == null) return false;

    // Engine internal state is now restored by getRecoverableSession:
    // _currentPlan, _flatSteps, _currentStepIndex, _waitStepElapsedMs,
    // _status = paused. Call resume() to start the ambient track and loop.
    await resume();
    return true;
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
        // TTS mode toggle semantics: _ttsPlaybackMode() is read HERE, once
        // per step, at step-start time. If the user toggles the
        // NowPlayingTtsToggle while this step is executing, the change is
        // ignored for the current step — it takes effect on the next step,
        // when the execution loop calls _executeStep again and this line
        // re-reads the provider. See _ttsPlaybackMode field docs for details.
        final ttsFuture =
            _ttsService.renderTTS(text, voiceId, _ttsPlaybackMode());

        // Race TTS rendering against the cancel signal so that pause/stop/skip
        // unblock the loop immediately instead of waiting for the HTTP response
        // (which could take seconds on a cache miss).
        final ttsRaceCompleter = Completer<String?>();
        unawaited(ttsFuture.then(
          (result) {
            if (!ttsRaceCompleter.isCompleted) {
              ttsRaceCompleter.complete(result);
            }
          },
          onError: (Object e, StackTrace st) {
            if (!ttsRaceCompleter.isCompleted) {
              ttsRaceCompleter.completeError(e, st);
            }
          },
        ),);
        unawaited(_stepCancelCompleter!.future.then((_) {
          if (!ttsRaceCompleter.isCompleted) {
            ttsRaceCompleter.complete(null);
          }
        },),);

        String? ttsResult;
        try {
          debugPrint('PlanExecutionEngine: [SAY] awaiting ttsFuture…');
          ttsResult = await ttsRaceCompleter.future;
          debugPrint('PlanExecutionEngine: [SAY] ttsFuture resolved OK');
        } catch (e) {
          debugPrint('PlanExecutionEngine: [SAY] ttsFuture threw ${e.runtimeType}: $e');
          rethrow;
        }

        if (_cancelled) return;
        if (ttsResult == null) {
          // Platform mode returned null — use platform TTS fallback directly.
          _currentStepPhase = StepPhase.active;
          _emitState();
          voicePlayedSuccessfully = await _platformTtsFallback(text);
          return;
        }
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
        _startSayStepPlaybackTimer(speed: speed);
        await _audioEngine.playVoice(path, speed: speed);
        _stopSayStepPlaybackTimer();
        debugPrint('PlanExecutionEngine: [SAY] playVoice completed');
        voicePlayedSuccessfully = true;
      } catch (e) {
        _stopSayStepPlaybackTimer();
        debugPrint('PlanExecutionEngine: playVoice failed: $e');
        if (e is StoppedByUserException || _cancelled) {
          return;
        }
        // Fallback to platform TTS file when audio file playback fails.
        debugPrint('PlanExecutionEngine: [SAY] playVoice failed, trying platform TTS file fallback');
        voicePlayedSuccessfully = await _platformTtsFallback(text);
      }
    } finally {
      // Stop the say-step progress timer on every exit path (normal
      // completion, cancellation, error, fallback).
      _stopSayStepPlaybackTimer();

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
      _startSayStepPlaybackTimer(speed: speed);
      try {
        await _audioEngine.playVoice(path, speed: speed);
        _stopSayStepPlaybackTimer();
      } catch (e) {
        _stopSayStepPlaybackTimer();
        rethrow;
      }
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

  // ── Say step playback timer helpers ──────────────────────────────────────

  /// Starts the periodic progress timer for Say step voice playback.
  ///
  /// [speed] is the playback rate passed to [AudioEngine.playVoice]. It is
  /// used to convert the raw file duration (at 1×) to the effective wall-clock
  /// duration so the countdown arc stays in sync with the audio at any speed.
  ///
  /// Captures [_sayStepPlaybackStartTime] and starts a 100 ms periodic timer
  /// that emits [ExecutionState] updates so the UI countdown timer tracks
  /// real playback progress.
  ///
  /// The actual voice file duration ([_currentSayStepActualDuration]) is
  /// captured lazily on the first timer tick rather than immediately, because
  /// [AudioEngine.currentVoiceDuration] is only available after `setFilePath`
  /// completes inside [AudioEngine.playVoice] — which takes ~300 ms+ due to
  /// ambient ducking before loading the file.
  void _startSayStepPlaybackTimer({double speed = 1.0}) {
    _currentSayStepSpeed = speed.clamp(0.5, 2.0);
    _sayStepPlaybackStartTime = DateTime.now();
    _currentSayStepActualDuration = null;

    _sayStepProgressTimer?.cancel();
    _sayStepProgressTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        // Capture the speed-adjusted voice file duration on the first tick
        // where the raw duration becomes available. Dividing by speed converts
        // the 1× file duration to the wall-clock time the audio actually takes,
        // so elapsed wall-clock time tracks correctly against the countdown.
        if (_currentSayStepActualDuration == null) {
          final raw = _audioEngine.currentVoiceDuration;
          if (raw != null) {
            final adjustedMs =
                (raw.inMilliseconds / _currentSayStepSpeed).round();
            _currentSayStepActualDuration = Duration(milliseconds: adjustedMs);
          }
        }
        _emitState();
      },
    );

    // Subscribe to speech-rate changes so speed updates take effect in real
    // time on the currently playing audio rather than only on the next step.
    // Drift emits the current value immediately on subscription, so skip the
    // first emission (which would always equal _currentSayStepSpeed).
    var firstEmission = true;
    _speedWatchSubscription?.cancel();
    _speedWatchSubscription = (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(AppSettingsKeys.speechRate)))
        .watchSingleOrNull()
        .listen((row) {
      if (firstEmission) {
        firstEmission = false;
        return;
      }
      if (_cancelled) return;
      final newSpeed = double.tryParse(row?.value ?? '') ?? 1.0;
      if ((newSpeed - _currentSayStepSpeed).abs() < 0.01) return;
      unawaited(_onSpeedChangedDuringPlayback(newSpeed));
    });

    _emitState();
  }

  /// Stops the Say step progress timer and clears playback tracking state.
  void _stopSayStepPlaybackTimer() {
    _sayStepProgressTimer?.cancel();
    _sayStepProgressTimer = null;
    _speedWatchSubscription?.cancel();
    _speedWatchSubscription = null;
    _sayStepPlaybackStartTime = null;
    _sayStepElapsedBeforeCurrentPlayMs = 0;
    _currentSayStepActualDuration = null;
    _currentSayStepSpeed = 1.0;
  }

  /// Called when the user changes the speech-rate setting while a Say step
  /// is actively playing voice audio.
  ///
  /// Updates the live audio player speed immediately (real-time effect) and
  /// recomputes [_currentSayStepActualDuration] so the countdown timer stays
  /// accurate at the new speed.
  Future<void> _onSpeedChangedDuringPlayback(double newSpeed) async {
    if (_cancelled) return;

    // Apply the new speed to the live audio player immediately.
    await _audioEngine.setVoiceSpeed(newSpeed);

    // Recompute the countdown timer from the audio player's current position.
    final position = _audioEngine.currentVoicePosition;
    if (position != null && _currentSayStepActualDuration != null) {
      // Freeze elapsed wall-clock time up to this moment.
      var elapsedWcMs = _sayStepElapsedBeforeCurrentPlayMs;
      if (_sayStepPlaybackStartTime != null) {
        elapsedWcMs +=
            DateTime.now().difference(_sayStepPlaybackStartTime!).inMilliseconds;
      }

      // Raw 1× file duration = speed-adjusted duration × old speed.
      final rawDurationMs =
          (_currentSayStepActualDuration!.inMilliseconds * _currentSayStepSpeed)
              .round();

      // Remaining audio content at 1× speed (position is always in 1× time).
      final audioRemainingAt1xMs =
          (rawDurationMs - position.inMilliseconds).clamp(0, rawDurationMs);

      // Convert remaining 1× content to wall-clock time at the new speed.
      final wallClockRemainingMs = audioRemainingAt1xMs / newSpeed;

      // Reset elapsed tracking from now so the timer increments cleanly.
      _sayStepElapsedBeforeCurrentPlayMs = elapsedWcMs;
      _sayStepPlaybackStartTime = DateTime.now();
      _currentSayStepActualDuration =
          Duration(milliseconds: (elapsedWcMs + wallClockRemainingMs).round());
    }

    _currentSayStepSpeed = newSpeed;
    _emitState();
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

      // Accumulate actual wall-clock time since the last checkpoint into
      // _waitStepElapsedMs, then reset _waitStepStartTime. This avoids
      // double-counting: _computeTimeRemaining adds _waitStepElapsedMs to the
      // delta from _waitStepStartTime, so we must not set an absolute value
      // here while _waitStepStartTime still points to the step start.
      if (_waitStepStartTime != null) {
        _waitStepElapsedMs +=
            DateTime.now().difference(_waitStepStartTime!).inMilliseconds;
        _waitStepStartTime = DateTime.now();
      }
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
      // _ttsPlaybackMode() is read once per number render, at the point each
      // number is spoken. Mode toggles take effect on the next CountStep number
      // (or the next step entirely), consistent with SayStep toggle semantics.
      final path = await _ttsService.renderTTS(
          number.toString(), voiceId, _ttsPlaybackMode());
      _numberAudioPaths[cacheKey] = path ?? await _ttsService.renderWithPlatformTTS(number.toString());
      return _numberAudioPaths[cacheKey]!;
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

    // Say step with active voice playback — compute from actual audio duration.
    if (step is SayStep && _currentSayStepActualDuration != null) {
      final totalMs = _currentSayStepActualDuration!.inMilliseconds;
      var elapsed = _sayStepElapsedBeforeCurrentPlayMs;
      if (_sayStepPlaybackStartTime != null) {
        elapsed +=
            DateTime.now().difference(_sayStepPlaybackStartTime!).inMilliseconds;
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
  ///
  /// For [SayStep]s with active voice playback, returns the actual audio file
  /// duration so the countdown arc reflects real playback time.
  Duration _computeStepDuration(PlanStep step) {
    if (step is SayStep && _currentSayStepActualDuration != null) {
      return _currentSayStepActualDuration!;
    }
    return step.estimatedStepDuration;
  }

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

    // Guard: the plans table FK requires the plan row to exist. If
    // refreshFromServer removed this plan while the session was active,
    // skip persistence rather than throwing a FK constraint violation.
    // The session continues; crash recovery is unavailable for this run.
    final planExists = await (_db.select(_db.plansTable)
          ..where((t) => t.id.equals(plan.id)))
        .getSingleOrNull() !=
        null;
    if (!planExists) {
      debugPrint(
        '[ExecutionEngine] _persistState: plan ${plan.id} absent from '
        'local DB — session state not persisted.',
      );
      return;
    }

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
      category: row.category,
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
    // Read the current playback mode at each renderTTS call — not watched,
    // so the engine doesn't rebuild; it simply samples the latest value.
    ttsPlaybackModeGetter: () => ref.read(ttsPlaybackModeProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
}

// ────────────────────────────────────────────────────────────────────────────
// Public step-flattening helper (used by plan editor "Start from here")
// ────────────────────────────────────────────────────────────────────────────

/// Returns the total number of flat steps produced when expanding [steps].
///
/// Each non-[RepeatStep] contributes 1 flat step. Each [RepeatStep] contributes
/// `count × flatStepCountForSteps(children)` flat steps (recursively).
///
/// Use this to compute the flat step index for a given top-level step index
/// so that [PlanExecutionEngine.startPlanFromStep] can be called correctly:
///
/// ```dart
/// int flatIndex = flatStepIndexForOriginalIndex(plan.steps, targetIndex);
/// await engine.startPlanFromStep(plan, flatIndex);
/// ```
int flatStepCountForSteps(List<PlanStep> steps) {
  var count = 0;
  for (final step in steps) {
    if (step is RepeatStep) {
      count += step.count * flatStepCountForSteps(step.children);
    } else {
      count += 1;
    }
  }
  return count;
}

/// Computes the flat step index that corresponds to the top-level [PlanStep]
/// at [originalIndex] within [steps].
///
/// All flat steps produced by steps 0 through [originalIndex]-1 are counted,
/// and that total is returned as the starting flat index for [originalIndex].
///
/// Returns 0 if [originalIndex] is 0 or negative.
int flatStepIndexForOriginalIndex(List<PlanStep> steps, int originalIndex) {
  if (originalIndex <= 0) return 0;
  final prefix = steps.take(originalIndex).toList();
  return flatStepCountForSteps(prefix);
}
