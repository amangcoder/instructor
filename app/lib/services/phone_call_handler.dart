/// PhoneCallHandler — phone-call interruption detection via [audio_session].
///
/// Uses [AudioSession.interruptionEventStream] to detect phone calls on both
/// iOS and Android without requiring the READ_PHONE_STATE dangerous permission:
///
/// - **iOS**: When a call begins, AVAudioSession fires an interruption
///   notification with type `.began`. When the call ends it fires `.ended`.
///   The `audio_session` package surfaces these as [AudioInterruptionEvent]
///   values with [AudioInterruptionEvent.begin] set to `true` / `false`.
///
/// - **Android**: An incoming call causes the telephony stack to request
///   AUDIOFOCUS_LOSS_TRANSIENT, which [audio_session] maps to an
///   [AudioInterruptionEvent] with [AudioInterruptionType.pause].
///
/// Duck interruptions (e.g. a notification sound) are intentionally ignored
/// so that brief system sounds do not trigger a full pause + resume prompt.
library phone_call_handler;

import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:instructor/models/enums.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ────────────────────────────────────────────────────────────────────────────

/// Handles phone-call interruptions using [audio_session]'s
/// [AudioSession.interruptionEventStream].
///
/// This approach works on both iOS (AVAudioSession interruption notifications)
/// and Android (audio focus AUDIOFOCUS_LOSS_TRANSIENT during calls) without
/// requiring the [READ_PHONE_STATE] dangerous permission.
///
/// On interruption detected:
/// 1. Auto-pause the [PlanExecutionEngine].
/// 2. Show a resume-prompt notification via [NotificationService].
///
/// On interruption ended:
/// 1. Show [NotificationService.showResumePrompt] with the plan name so the
///    user can tap to resume from the exact paused position.
abstract class PhoneCallHandler {
  /// Starts listening to [audio_session] interruption events.
  void startListening();

  /// Stops listening and cancels any pending resume prompt.
  void stopListening();
}

// ────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ────────────────────────────────────────────────────────────────────────────

/// Production [PhoneCallHandler] backed by [AudioSession.interruptionEventStream].
///
/// Inject a custom fake in tests to avoid real [AudioSession] calls.
class PhoneCallHandlerImpl implements PhoneCallHandler {
  PhoneCallHandlerImpl({
    required PlanExecutionEngine engine,
    required NotificationService notificationService,
  })  : _engine = engine,
        _notificationService = notificationService;

  final PlanExecutionEngine _engine;
  final NotificationService _notificationService;

  // ── Subscriptions ──────────────────────────────────────────────────────────

  /// Subscription to [AudioSession.interruptionEventStream].
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  /// Subscription to [PlanExecutionEngine.stateStream] for tracking the current
  /// plan name (needed for the resume-prompt notification text).
  StreamSubscription<ExecutionState>? _stateSub;

  // ── Interruption state ────────────────────────────────────────────────────

  /// `true` when we paused execution in response to a phone-call interruption.
  ///
  /// Guards [_onPhoneCallEnded] so that we only show the resume prompt when
  /// we were actually the ones who paused (not when the user paused manually).
  bool _pausedForCall = false;

  /// The plan name at the moment the call began, for use in the resume prompt.
  String? _interruptedPlanName;

  // ── Latest execution state cache ──────────────────────────────────────────

  /// Most recently emitted [ExecutionState].  Updated by [_stateSub].
  ExecutionState? _lastState;

  // ── PhoneCallHandler API ──────────────────────────────────────────────────

  @override
  void startListening() {
    // Track execution state so we know the plan name when a call starts.
    _stateSub = _engine.stateStream.listen(
      (state) => _lastState = state,
      onError: (Object err) {
        debugPrint('PhoneCallHandler: stateStream error: $err');
      },
    );

    // Subscribe to audio session interruption events asynchronously.
    // We don't await the future so [startListening] remains synchronous —
    // the subscription is stored and cancelled by [stopListening].
    AudioSession.instance.then(
      (session) {
        _interruptionSub =
            session.interruptionEventStream.listen(_onInterruption);
      },
      onError: (Object err) {
        debugPrint('PhoneCallHandler: AudioSession.instance error: $err');
      },
    );
  }

  @override
  void stopListening() {
    _interruptionSub?.cancel();
    _interruptionSub = null;

    _stateSub?.cancel();
    _stateSub = null;

    // Reset interruption state so a stale call doesn't trigger a resume prompt
    // if [startListening] is called again.
    _pausedForCall = false;
    _interruptedPlanName = null;
    _lastState = null;
  }

  // ── Interruption handling ─────────────────────────────────────────────────

  void _onInterruption(AudioInterruptionEvent event) {
    debugPrint(
      'PhoneCallHandler: interruption event — begin=${event.begin}, '
      'type=${event.type}',
    );

    if (event.begin) {
      // [AudioInterruptionType.duck] events are short-lived system sounds
      // (notification pings, GPS prompts, etc.). We tolerate those without
      // pausing execution.  Any other begin-type interruption (pause,
      // unknown) is treated as a phone call.
      if (event.type != AudioInterruptionType.duck) {
        _onPhoneCallStarted();
      }
    } else {
      _onPhoneCallEnded();
    }
  }

  /// Pauses execution and records the interrupted plan name.
  ///
  /// Called when a non-duck audio interruption begins (phone call on iOS
  /// or Android AUDIOFOCUS_LOSS_TRANSIENT).
  void _onPhoneCallStarted() {
    final state = _lastState;
    if (state == null || state.status != ExecutionStatus.running) {
      debugPrint(
        'PhoneCallHandler: call started but plan is not running '
        '(status=${state?.status}) — skipping pause.',
      );
      return;
    }

    debugPrint(
      'PhoneCallHandler: phone call started — pausing plan "${state.plan.name}".',
    );

    _interruptedPlanName = state.plan.name;
    _pausedForCall = true;
    // Fire-and-forget: pause does not need to be awaited here because we are
    // in a synchronous interrupt callback.  The engine handles re-entrant
    // pause calls safely.
    _engine.pause();
  }

  /// Shows the resume-prompt notification after the call ends.
  ///
  /// Only fires if [_onPhoneCallStarted] was previously called (guarded by
  /// [_pausedForCall]) so that spurious end-events don't show a stale prompt.
  void _onPhoneCallEnded() {
    if (!_pausedForCall) {
      debugPrint(
        'PhoneCallHandler: call ended but we did not pause for it — ignoring.',
      );
      return;
    }

    final planName = _interruptedPlanName;
    _pausedForCall = false;
    _interruptedPlanName = null;

    if (planName == null) return;

    debugPrint(
      'PhoneCallHandler: phone call ended — showing resume prompt for '
      '"$planName".',
    );

    // Fire-and-forget: the notification is best-effort.  If it fails, the
    // user can still tap the plan card in the library to resume.
    _notificationService.showResumePrompt(planName);
  }
}
