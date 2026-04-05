/// BackgroundService — audio_service integration for background execution.
///
/// ## Architecture
///
/// [InstructorAudioHandler] extends [BaseAudioHandler] from the `audio_service`
/// package, which provides:
///   - **Android**: A foreground [Service] with a persistent notification and a
///     MediaSession for lock screen controls.
///   - **iOS**: Registration with AVAudioSession / MediaPlayer / NowPlayingInfo
///     so the app can play audio in the background and respond to lock screen
///     and headphone controls.
///
/// ## Lock screen controls
///
/// Every time [PlanExecutionEngine.stateStream] emits a new [ExecutionState],
/// the handler updates both [BaseAudioHandler.mediaItem] (title = plan name,
/// artist = current step indicator) and [BaseAudioHandler.playbackState]
/// (playing flag + available controls). This triggers iOS / Android to refresh
/// the Now Playing widget on the lock screen.
///
/// ## Phone-call interruptions
///
/// Phone-call interruptions are detected by [PhoneCallHandlerImpl] via
/// `audio_session`'s [AudioSession.interruptionEventStream]. This works on both
/// iOS (AVAudioSession interruption notifications) and Android (audio focus
/// AUDIOFOCUS_LOSS_TRANSIENT during a call) without requiring the dangerous
/// READ_PHONE_STATE permission.
///
/// ## Initialisation
///
/// Call [initializeBackgroundService] from [main] **before** [runApp].  Pass
/// the engine and notification service obtained from a [ProviderContainer] so
/// that the handler has access to them from the moment [AudioService.init]
/// returns.
library background_service;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:instructor/models/enums.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/phone_call_handler.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ────────────────────────────────────────────────────────────────────────────
// AudioHandler
// ────────────────────────────────────────────────────────────────────────────

/// [audio_service] handler that keeps Plan execution alive in the background.
///
/// Provides MediaSession integration for lock screen controls (play/pause,
/// skip forward/backward) on both iOS and Android.
///
/// Phone-call interruptions are handled by the injected [PhoneCallHandler],
/// which uses `audio_session`'s interruption stream — no READ_PHONE_STATE
/// permission is required.
class InstructorAudioHandler extends BaseAudioHandler {
  InstructorAudioHandler({
    required PlanExecutionEngine engine,
    required PhoneCallHandler phoneCallHandler,
  })  : _engine = engine,
        _phoneCallHandler = phoneCallHandler {
    // Subscribe to execution state changes immediately so that the lock screen
    // always reflects the current plan state.
    _stateSub = _engine.stateStream.listen(
      _onExecutionStateChanged,
      onError: (Object err) {
        debugPrint('InstructorAudioHandler: stateStream error: $err');
      },
    );
  }

  final PlanExecutionEngine _engine;
  final PhoneCallHandler _phoneCallHandler;
  StreamSubscription<ExecutionState>? _stateSub;

  // ── BaseAudioHandler overrides (lock screen / headphone controls) ─────────

  /// Resumes plan execution (maps to the ► lock screen button).
  @override
  Future<void> play() async {
    await _engine.resume();
  }

  /// Pauses plan execution (maps to the ‖ lock screen button).
  @override
  Future<void> pause() async {
    await _engine.pause();
  }

  /// Advances to the next step (maps to the ⏭ lock screen button).
  @override
  Future<void> skipToNext() async {
    await _engine.skipForward();
  }

  /// Returns to the previous step (maps to the ⏮ lock screen button).
  @override
  Future<void> skipToPrevious() async {
    await _engine.skipBackward();
  }

  /// Stops plan execution (maps to the ■ lock screen button).
  @override
  Future<void> stop() async {
    await _engine.stop();
  }

  // ── Execution state → lock screen ─────────────────────────────────────────

  /// Called on every [ExecutionState] emission.
  ///
  /// Updates both [mediaItem] and [playbackState] so that iOS / Android
  /// refresh the Now Playing / lock screen widget immediately.
  void _onExecutionStateChanged(ExecutionState state) {
    // Update lock screen track metadata.
    mediaItem.add(executionStateToMediaItem(state));

    // Update lock screen controls and playing indicator.
    final isPlaying = state.status == ExecutionStatus.running;

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.pause,
        MediaAction.play,
        MediaAction.skipToNext,
        MediaAction.stop,
      },
      // Compact notification on Android shows indices 0 (prev), 1 (play/pause),
      // 2 (next) — the three most important controls.
      androidCompactActionIndices: const [0, 1, 2],
      processingState: state.status == ExecutionStatus.completed
          ? AudioProcessingState.completed
          : AudioProcessingState.ready,
      playing: isPlaying,
      updatePosition: Duration.zero,
      speed: 1.0,
    ));
  }

  // ── Phone call handler accessor ───────────────────────────────────────────

  /// Starts phone-call interruption listening.
  ///
  /// Called by [initializeBackgroundService] after [AudioSession] is
  /// configured.
  void startPhoneCallHandler() => _phoneCallHandler.startListening();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Releases all subscriptions.
  ///
  /// Called from the Riverpod provider's [onDispose] callback and in tests.
  Future<void> disposeHandler() async {
    _phoneCallHandler.stopListening();
    await _stateSub?.cancel();
    _stateSub = null;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Initialisation
// ────────────────────────────────────────────────────────────────────────────

/// Initialises [audio_service] with [InstructorAudioHandler] and configures
/// the [AudioSession] for background playback.
///
/// Must be called from [main] **before** [runApp].  The [engine] and
/// [notificationService] obtained from a [ProviderContainer] (created before
/// [runApp]) are wired into the handler for lock screen updates and phone-call
/// interruption handling.
///
/// ## What this does
/// 1. Calls [AudioService.init] with an [AndroidNotificationChannelConfig] so
///    Android shows a persistent foreground service notification while a Plan
///    is running (required by Android API 26+).
/// 2. Configures the [AudioSession] for iOS ([AVAudioSessionCategory.playback]
///    + [AVAudioSessionCategoryOptions.mixWithOthers]) and Android.
/// 3. Starts phone-call interruption listening via [PhoneCallHandlerImpl].
Future<InstructorAudioHandler> initializeBackgroundService({
  required PlanExecutionEngine engine,
  required NotificationService notificationService,
}) async {
  // Build the phone-call handler backed by audio_session interruptions.
  final phoneCallHandler = PhoneCallHandlerImpl(
    engine: engine,
    notificationService: notificationService,
  );

  // Initialise audio_service with the Android foreground-service notification
  // configuration.  [androidStopForegroundOnPause: false] keeps the service
  // alive during WaitSteps so the OS cannot suspend the app.
  final handler = await AudioService.init<InstructorAudioHandler>(
    builder: () => InstructorAudioHandler(
      engine: engine,
      phoneCallHandler: phoneCallHandler,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.instructor.app.audio',
      androidNotificationChannelName: 'Instructor',
      androidNotificationOngoing: true,
      // Keep foreground service alive during wait steps (no audio playing).
      androidStopForegroundOnPause: true,
    ),
  );

  // Configure the iOS AVAudioSession (and Android AudioAttributes).
  // [AVAudioSessionCategory.playback] lets the app continue playing when the
  // screen is locked.  [mixWithOthers] prevents the app from silencing other
  // audio (e.g. phone calls, other apps) when it activates.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions:
        AVAudioSessionCategoryOptions.mixWithOthers,
    avAudioSessionMode: AVAudioSessionMode.defaultMode,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.music,
      flags: AndroidAudioFlags.none,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    // Ask Android to pause (rather than duck) when another app needs focus.
    androidWillPauseWhenDucked: true,
  ));

  // Now that the session is configured, start listening for phone-call
  // interruptions (requires AudioSession.instance to be ready).
  handler.startPhoneCallHandler();

  return handler;
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Converts an [ExecutionState] into a [MediaItem] for the lock screen.
///
/// - [MediaItem.title]  = plan name (shown as the track title).
/// - [MediaItem.artist] = "Step N" indicator (shown as the subtitle).
/// - [MediaItem.duration] = total plan duration (shown in the progress bar).
///
/// The [id] is stable for the duration of a single plan execution and changes
/// when a new plan starts, which prompts iOS / Android to refresh the artwork.
MediaItem executionStateToMediaItem(ExecutionState state) {
  // [currentStepIndex] is an index into the engine's internal *flattened*
  // step list, which is not exposed by [ExecutionState]. We display
  // "Step N" as a human-readable indicator; a future enhancement could
  // carry the step display text directly in [ExecutionState].
  final stepLabel = 'Step ${state.currentStepIndex + 1}';

  return MediaItem(
    id: 'instructor:${state.plan.id}',
    title: state.plan.name,
    artist: stepLabel,
    duration: state.plan.totalDuration,
  );
}
