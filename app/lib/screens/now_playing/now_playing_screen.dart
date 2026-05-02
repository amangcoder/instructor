import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/providers/series_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/providers/streak_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instructor/theme/step_colors.dart';
import 'package:instructor/screens/now_playing/widgets/next_up_preview.dart';
import 'package:instructor/screens/now_playing/widgets/session_gesture_detector.dart';
import 'package:instructor/screens/now_playing/widgets/step_countdown_timer.dart';
import 'package:instructor/screens/now_playing/widgets/tts_toggle.dart';
import 'package:instructor/services/live_activity_channel.dart';
import 'package:instructor/widgets/milestone_celebration.dart';

/// Full-screen Now Playing view shown while a Plan is executing.
///
/// ## State source
/// Consumes [executionStateProvider] (a [StreamProvider] wrapping
/// [PlanExecutionEngine.stateStream]).
///
/// ## Gestures
/// Handled by [SessionGestureDetector]:
/// - Single tap → toggle pause/resume
/// - Double-tap / swipe right → skip forward
/// - Triple-tap / swipe left → skip backward
/// - Swipe down / long-press (2 s) → confirmation dialog → stop + navigate /
///
/// ## Auto-dim
/// A [Listener] widget detects pointer events and resets a 10-second timer on
/// each touch. When the timer fires, [screen_brightness] reduces brightness to
/// 30 %. The next touch restores the original brightness.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  // ── Auto-dim ────────────────────────────────────────────────────────────────

  static const _dimDelay = Duration(seconds: 10);
  static const _dimBrightness = 0.3;

  Timer? _dimTimer;
  bool _isDimmed = false;
  double? _originalBrightness;

  // ── Completion handling ──────────────────────────────────────────────────────

  bool _completionHandled = false;

  // ── Instruction full-text sheet ──────────────────────────────────────────
  void _showFullInstruction(String text, String typeLabel) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.85,
          minChildSize: 0.25,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Text(
                      text,
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TTS auto-default ──────────────────────────────────────────────────────
  /// Set to `true` once we have automatically defaulted the playback mode to
  /// [TtsPlaybackMode.genai] for this session.  Prevents repeated auto-switches
  /// if the provider rebuilds while AI Voice is already selected.
  bool _hasAutoDefaultedToGenai = false;

  // ── Gesture debounce ─────────────────────────────────────────────────────────

  /// Timestamp of the last accepted gesture command. Used to collapse rapid
  /// taps (e.g. pause then immediately resume) into a single command.
  DateTime? _lastCommandTime;

  /// Returns `true` and records [_lastCommandTime] if at least 300 ms have
  /// elapsed since the previous accepted command. Returns `false` (no-op) if
  /// called within the debounce window.
  static const _commandDebounce = Duration(milliseconds: 300);

  bool _tryAcquireDebounce() {
    final now = DateTime.now();
    if (_lastCommandTime != null &&
        now.difference(_lastCommandTime!) < _commandDebounce) {
      return false;
    }
    _lastCommandTime = now;
    return true;
  }

  // ── NextUpPreview tap debounce ────────────────────────────────────────────

  /// Timestamp of the last accepted NextUpPreview tap. A separate, longer
  /// debounce (500 ms) prevents accidental double-taps on the card from
  /// triggering multiple skipForward() calls.
  DateTime? _lastNextUpTapTime;
  static const _nextUpTapDebounce = Duration(milliseconds: 500);

  bool _tryAcquireNextUpDebounce() {
    final now = DateTime.now();
    if (_lastNextUpTapTime != null &&
        now.difference(_lastNextUpTapTime!) < _nextUpTapDebounce) {
      return false;
    }
    _lastNextUpTapTime = now;
    return true;
  }

  // ────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _captureOriginalBrightness();
    _resetDimTimer();
  }

  @override
  void dispose() {
    _dimTimer?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _captureOriginalBrightness() async {
    try {
      _originalBrightness =
          await ScreenBrightness().current;
    } catch (_) {
      // screen_brightness not available on desktop/test — ignore.
    }
  }

  void _onTouchDetected() {
    _restoreBrightness();
    _resetDimTimer();
  }

  void _resetDimTimer() {
    _dimTimer?.cancel();
    _dimTimer = Timer(_dimDelay, _dimScreen);
  }

  Future<void> _dimScreen() async {
    if (!mounted) return;
    try {
      await ScreenBrightness().setScreenBrightness(_dimBrightness);
      setState(() => _isDimmed = true);
    } catch (_) {}
  }

  Future<void> _restoreBrightness() async {
    if (!_isDimmed) return;
    _isDimmed = false;
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (_) {}
  }

  // ── Gesture handlers ────────────────────────────────────────────────────────

  Future<void> _togglePause() async {
    if (!_tryAcquireDebounce()) return;
    final engine = ref.read(planExecutionEngineProvider);
    final stateAsync = ref.read(executionStateProvider);
    final state = stateAsync.valueOrNull;
    if (state == null) return;

    if (state.status == ExecutionStatus.running) {
      await engine.pause();
    } else if (state.status == ExecutionStatus.paused) {
      await engine.resume();
    }
  }

  Future<void> _skipForward() async {
    if (!_tryAcquireDebounce()) return;
    final engine = ref.read(planExecutionEngineProvider);
    await engine.skipForward();
  }

  /// Called when the user taps the [NextUpPreview] card.
  ///
  /// Guards with a 500 ms debounce so accidental double-taps do not fire
  /// two skipForward() calls. Restores auto-dim timer on touch.
  Future<void> _onNextUpTap() async {
    _onTouchDetected(); // reset dim timer on tap
    if (!_tryAcquireNextUpDebounce()) return;
    final engine = ref.read(planExecutionEngineProvider);
    await engine.skipForward();
  }

  Future<void> _skipBackward() async {
    if (!_tryAcquireDebounce()) return;

    // When the engine is already at step 0, skipBackward() is a no-op by
    // design (it would re-execute the same step, which confuses the user).
    // Show a brief snackbar instead of forwarding the no-op to the engine.
    final currentState = ref.read(executionStateProvider).valueOrNull;
    if (currentState?.currentStepIndex == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already at the first step'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final engine = ref.read(planExecutionEngineProvider);
    await engine.skipBackward();
  }

  Future<void> _onEndRequested() async {
    final confirmed = await _showEndConfirmation();
    if (!confirmed || !mounted) return;
    final engine = ref.read(planExecutionEngineProvider);
    await engine.stop();
    if (mounted) {
      context.go(AppRoutes.library);
    }
  }

  Future<bool> _showEndConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session?'),
        content: const Text(
          'Are you sure you want to stop this session and return to the library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Stopped / idle ─────────────────────────────────────────────────────────

  /// Called when [stop()] is invoked externally (e.g. from the lock screen or
  /// Android notification) while the NowPlayingScreen is still mounted.
  ///
  /// Without this, the screen would freeze on a loading spinner because the
  /// engine clears its plan reference and the state stream stops emitting.
  void _handleStopped(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      this.context.go(AppRoutes.library);
    });
  }

  // ── Completion ──────────────────────────────────────────────────────────────

  void _handleCompletion(BuildContext context, ExecutionState state) {
    if (_completionHandled) return;
    // Set synchronously — before the post-frame callback is scheduled — so that
    // multiple rapid state emissions (e.g. engine emits 'completed' twice before
    // the frame fires) cannot stack up two dialogs.
    _completionHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // End the Live Activity, showing the completed plan name and duration
      // in the final dismissable state (REQ-023 / AC-022).
      final liveActivity = ref.read(liveActivityChannelProvider);
      await liveActivity.endActivity(
        planName: state.plan.name,
        durationMs: state.plan.totalDuration.inMilliseconds,
      );

      await _recordSeriesProgressIfNeeded(state);

      await _showCompletionSummary(state);
      // Guard: the widget may have been disposed while the completion dialog was
      // visible (e.g. the user navigated to the library via another route). Skip
      // navigation when that happens to prevent operating on a dead element.
      if (!mounted) return;

      // ── Milestone celebration check ──────────────────────────────────────
      // By the time the user dismisses the completion dialog the streak service
      // has had time to recompute the new streak count.  We read the cached
      // value synchronously so we don't re-subscribe to the stream here.
      final streak = ref.read(cachedCurrentStreakProvider);
      if (isMilestoneStreak(streak) && mounted) {
        await showMilestoneCelebration(this.context, streak);
      }

      if (!mounted) return;
      // Use this.context (the State's BuildContext) rather than the parameter
      // captured in the closure, which could be a stale reference after rebuild.
      this.context.go(AppRoutes.library);
    });
  }

  /// Advance the user's series subscription when the just-completed plan
  /// belongs to a series the user opened from the program detail screen.
  /// Failures are logged but never block the completion UI — progress will
  /// reconcile on the next subscription refresh.
  Future<void> _recordSeriesProgressIfNeeded(ExecutionState state) async {
    final ctx = ref.read(activeSeriesSessionProvider);
    if (ctx == null) return;
    if (state.plan.seriesId != ctx.seriesId) return;

    try {
      await ref
          .read(seriesApiServiceProvider)
          .recordProgress(ctx.seriesId, ctx.sessionIndex);
      ref.invalidate(mySubscriptionsProvider);
      ref.invalidate(mySubscriptionForProvider(ctx.seriesId));
    } catch (e, stack) {
      debugPrint('recordProgress failed: $e\n$stack');
    } finally {
      ref.read(activeSeriesSessionProvider.notifier).state = null;
    }
  }

  Future<void> _showCompletionSummary(ExecutionState state) async {
    final planName = state.plan.name;
    final stepCount = state.plan.steps.length;
    final totalDuration = state.plan.totalDuration;
    final durationText = _formatDuration(totalDuration);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Session Complete 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              planName,
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '$stepCount steps • $durationText',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    // Guard: navigation to the library (or any other route change) could have
    // disposed this widget while the dialog was open. The caller checks mounted
    // too, but an explicit guard here keeps this method self-contained and safe.
    if (!mounted) return;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }


  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(executionStateProvider);

    // Announce step transitions to screen-reader users via SemanticsService.
    ref.listen<AsyncValue<ExecutionState>>(executionStateProvider,
        (prev, next) {
      final prevState = prev?.valueOrNull;
      final currState = next.valueOrNull;
      if (prevState != null &&
          currState != null &&
          prevState.currentStepIndex != currState.currentStepIndex &&
          currState.status == ExecutionStatus.running) {
        // Use currentStepText from engine (correct for repeat-block plans).
        final announcement =
            currState.currentStepText ?? 'Next step';
        SemanticsService.announce(
          announcement,
          TextDirection.ltr,
        ).ignore();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: stateAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) {
          final colorScheme = Theme.of(context).colorScheme;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Session error',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: colorScheme.onSurface),
                ),
                // Show the raw error in debug builds so developers can diagnose
                // without needing to attach a debugger.
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      e.toString(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontFamily: 'monospace',
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Retry re-subscribes to the execution state stream and
                // attempts to resume from a recoverable session.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        ref.invalidate(executionStateProvider);
                        final engine = ref.read(planExecutionEngineProvider);
                        final session = await engine.getRecoverableSession();
                        if (session != null) {
                          await engine.resumeFromPersistedState(
                            session.plan.id,
                          );
                          // TASK-058: After crash recovery, default the TTS
                          // toggle based on isTtsReadyProvider: AI Voice if
                          // TTS files are ready, Device (platform) otherwise.
                          if (!mounted) return;
                          final isTtsReady =
                              ref.read(isTtsReadyProvider(session.plan.id));
                          ref.read(ttsPlaybackModeProvider.notifier).state =
                              isTtsReady
                                  ? TtsPlaybackMode.genai
                                  : TtsPlaybackMode.platform;
                        } else {
                          // No persisted session — nothing to recover.
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No session to recover — returning to library',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            context.go(AppRoutes.library);
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        side: BorderSide(color: colorScheme.outline),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.library),
                      child: const Text('Return to Library'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ExecutionState state) {
    // Handle completion state.
    if (state.status == ExecutionStatus.completed) {
      _handleCompletion(context, state);
    }

    // Handle stopped/idle state — e.g. stop() invoked from lock screen or
    // Android notification while the NowPlayingScreen is still visible.
    // navigate back to the library on the next frame so the current build
    // completes without trying to push/pop during build.
    if (state.status == ExecutionStatus.idle) {
      _handleStopped(context);
    }

    // ── TTS readiness & download state ───────────────────────────────────────
    // isTtsReadyProvider orchestrates both the local-cache fast-path and
    // live server polling (via planTtsStatusProvider) internally.
    final isTtsReady = ref.watch(isTtsReadyProvider(state.plan.id));

    // Show a snackbar the moment AI Voice transitions from not-ready to ready
    // during an active playback session.  The `prev == false` guard ensures
    // the notification only fires on a genuine false→true transition — it is
    // NOT triggered on initial load (prev == null) or when the value was
    // already true when the screen mounted.
    ref.listen<bool>(isTtsReadyProvider(state.plan.id), (prev, next) {
      if (prev == false && next == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Voice is now ready'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // Auto-default to AI Voice the first time TTS becomes ready in this
    // session.  The post-frame callback avoids mutating provider state during
    // the build phase.
    if (isTtsReady && !_hasAutoDefaultedToGenai) {
      _hasAutoDefaultedToGenai = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(ttsPlaybackModeProvider.notifier).state =
              TtsPlaybackMode.genai;
        }
      });
    }

    // Live ttsStatus: watch the polling provider so the toggle updates in
    // real time as generation progresses (pending → processing → completed).
    // Falls back to the plan's last-known cached status when polling hasn't
    // emitted yet (i.e. the plan is not active or already completed).
    final liveStatusAsync = ref.watch(planTtsStatusProvider(state.plan.id));
    final effectiveTtsStatus =
        liveStatusAsync.valueOrNull?.status ?? state.plan.ttsStatus;

    // Use ExecutionState text fields populated by the engine from the flattened
    // step list. This correctly handles plans with RepeatStep blocks where the
    // flattened index differs from the top-level step index.
    final currentStepText = state.currentStepText ?? 'Preparing...';
    final nextStepText = state.nextStepText;
    final stepType = state.currentStepType ?? StepType.wait;

    // Determine step-type colour for accents.
    final stepColor = StepColors.colorForType(stepType);
    final colorScheme = Theme.of(context).colorScheme;

    final isPaused = state.status == ExecutionStatus.paused;

    // Stitch "Active Session" layout: header, timer, instruction, controls,
    // next-up card. Full-screen gesture detector kept for tap/swipe support.
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Atmospheric background gradient ─────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerLow,
                  colorScheme.surface,
                ],
              ),
            ),
          ),
        ),

        // ── Full-screen gesture layer (excluded from semantics) ─────────
        ExcludeSemantics(
          child: Listener(
            onPointerDown: (_) => _onTouchDetected(),
            child: SessionGestureDetector(
              onTogglePause: _togglePause,
              onSkipForward: _skipForward,
              onSkipBackward: _skipBackward,
              onEnd: _onEndRequested,
              onTouchDetected: _onTouchDetected,
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Header: close | Instructor | more ──────────────
                    _TopBar(onClose: _onEndRequested),

                    // ── TTS Voice mode toggle ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Center(
                        child: TtsToggle(
                          ttsStatus: effectiveTtsStatus,
                          isActive: state.plan.isActive,
                          isLocked: stepType == StepType.say ||
                              stepType == StepType.count,
                        ),
                      ),
                    ),

                    // ── Timer & Instruction Area ───────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        // LayoutBuilder measures the actual available height so
                        // timer size and spacing are always proportional — no
                        // overflow on any screen size or orientation.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availH = constraints.maxHeight;
                            // Original timer size — unchanged.
                            final timerSize = (availH * 0.45).clamp(160.0, 288.0);
                            // Vertical gaps scale with height (8–32 px).
                            final spacing = (availH * 0.04).clamp(8.0, 32.0);

                            // Only offer expand when the text is long enough
                            // that it would overflow 3 lines (~90 chars is a
                            // safe heuristic for a typical phone width).
                            final isLongText = currentStepText.length > 90;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Timer / loading indicator
                                if (state.stepPhase == StepPhase.loadingTts)
                                  _TtsLoadingIndicator(color: stepColor, size: timerSize)
                                else
                                  StepCountdownTimer(
                                    timeRemaining: state.timeRemaining,
                                    totalDuration: state.currentStepDuration,
                                    isPaused: isPaused,
                                    size: timerSize,
                                  ),

                                SizedBox(height: spacing),

                                // ── Current instruction ─────────────────────
                                // Short texts: shown in full.
                                // Long texts: 3 lines + "Show more" tap →
                                // opens a bottom sheet with the full text.
                                GestureDetector(
                                  onTap: isLongText
                                      ? () => _showFullInstruction(
                                            currentStepText,
                                            _stepTypeLabel(stepType),
                                          )
                                      : null,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        currentStepText,
                                        style: GoogleFonts.manrope(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                          height: 1.45,
                                          color: colorScheme.onSurface,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: isLongText ? 3 : null,
                                        overflow: isLongText
                                            ? TextOverflow.ellipsis
                                            : null,
                                      ),
                                      if (isLongText) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Show more',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Text(
                                  _stepTypeLabel(stepType),
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),

                                SizedBox(height: spacing),

                                // ── Controls row ───────────────────────────
                                _ControlsRow(
                                  isPaused: isPaused,
                                  onTogglePause: _togglePause,
                                  onSkipForward: _skipForward,
                                  onSkipBackward: _skipBackward,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // ── Next Up card + bottom area ─────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: NextUpPreview(
                        nextStepText: nextStepText,
                        nextStepType: state.nextStepType,
                        // Tapping the card skips to the next step immediately.
                        // onTap is null when nextStepText is null (last step),
                        // so the FINAL STEP card remains non-interactive.
                        onTap: nextStepText != null ? _onNextUpTap : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Accessible buttons for screen readers (invisible) ───────────
        Positioned(
          bottom: 96,
          left: 0,
          right: 0,
          child: Center(
            child: Semantics(
              button: true,
              label: isPaused ? 'Resume session' : 'Pause session',
              hint: isPaused
                  ? 'Activates to resume plan playback'
                  : 'Activates to pause plan playback',
              onTap: _togglePause,
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),
        Positioned(
          bottom: 96,
          right: 40,
          child: Semantics(
            button: true,
            label: 'Skip forward to next step',
            onTap: _skipForward,
            child: const SizedBox(width: 64, height: 80),
          ),
        ),
        Positioned(
          bottom: 96,
          left: 40,
          child: Semantics(
            button: true,
            label: 'Go back to previous step',
            onTap: _skipBackward,
            child: const SizedBox(width: 64, height: 80),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: Semantics(
            button: true,
            label: 'End session',
            onTap: _onEndRequested,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

String _stepTypeLabel(StepType type) => switch (type) {
      StepType.say => 'Say',
      StepType.notify => 'Notify',
      StepType.play => 'Play',
      StepType.wait => 'Wait',
      StepType.count => 'Count',
      StepType.repeat => 'Repeat',
      StepType.stopAudio => 'Stop Audio',
    };

/// Stitch header: close (left) | "Instructor" centered | more_vert (right).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            color: colorScheme.primary,
            tooltip: 'End session',
          ),
          Expanded(
            child: Center(
              child: Text(
                'Instructor',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.25,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const _SpeedButton(),
        ],
      ),
    );
  }
}

/// Stitch controls: skip_previous | gradient pause/play circle | skip_next.
class _ControlsRow extends StatelessWidget {
  const _ControlsRow({
    required this.isPaused,
    required this.onTogglePause,
    required this.onSkipForward,
    required this.onSkipBackward,
  });

  final bool isPaused;
  final VoidCallback onTogglePause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip previous
        IconButton(
          onPressed: onSkipBackward,
          icon: const Icon(Icons.skip_previous, size: 32),
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 24),
        // Pause/Play — large gradient circle (Stitch: w-20 h-20)
        Semantics(
          button: true,
          label: isPaused ? 'Resume session' : 'Pause session',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTogglePause,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isPaused ? Icons.play_arrow : Icons.pause,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Skip next
        IconButton(
          onPressed: onSkipForward,
          icon: const Icon(Icons.skip_next, size: 32),
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}

/// Speed cycle button shown in the top-right corner of the Now Playing screen.
///
/// Tapping cycles through playback speed presets: 0.75×, 1×, 1.25×, 1.5×, 2×.
/// The selected speed is persisted to [AppSettingsKeys.speechRate] and takes
/// effect on the next say step. The button label updates reactively via
/// [speechRateSettingProvider].
class _SpeedButton extends ConsumerWidget {
  const _SpeedButton();

  static const _presets = [0.75, 1.0, 1.25, 1.5, 2.0];

  String _label(double speed) {
    if (speed == speed.truncateToDouble() && speed >= 1.0) {
      return '${speed.toInt()}×';
    }
    return '$speed×';
  }

  void _cycleSpeed(WidgetRef ref, double current) {
    final idx = _presets.indexWhere((p) => (p - current).abs() < 0.01);
    final nextIdx = (idx < 0 || idx == _presets.length - 1) ? 0 : idx + 1;
    final next = _presets[nextIdx];
    final writeFuture = ref.read(appSettingsProvider).write(
      AppSettingsKeys.speechRate,
      next.toStringAsFixed(2),
    );
    unawaited(writeFuture);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(speechRateSettingProvider).valueOrNull ?? 1.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Playback speed: ${_label(speed)}. Tap to change.',
      child: SizedBox(
        width: 48,
        height: 48,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 48),
            foregroundColor: colorScheme.primary,
          ),
          onPressed: () => _cycleSpeed(ref, speed),
          child: Text(
            _label(speed),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Indeterminate loading spinner shown while TTS audio is being fetched.
class _TtsLoadingIndicator extends StatelessWidget {
  const _TtsLoadingIndicator({required this.color, this.size = 288.0});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading audio...',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
