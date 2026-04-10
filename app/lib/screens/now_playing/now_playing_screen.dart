import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instructor/theme/step_colors.dart';
import 'package:instructor/screens/now_playing/widgets/next_up_preview.dart';
import 'package:instructor/screens/now_playing/widgets/session_gesture_detector.dart';
import 'package:instructor/screens/now_playing/widgets/step_countdown_timer.dart';

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

  Future<void> _skipBackward() async {
    if (!_tryAcquireDebounce()) return;
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

  // ── Completion ──────────────────────────────────────────────────────────────

  void _handleCompletion(BuildContext context, ExecutionState state) {
    if (_completionHandled) return;
    // Set synchronously — before the post-frame callback is scheduled — so that
    // multiple rapid state emissions (e.g. engine emits 'completed' twice before
    // the frame fires) cannot stack up two dialogs.
    _completionHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showCompletionSummary(state);
      // Guard: the widget may have been disposed while the completion dialog was
      // visible (e.g. the user navigated to the library via another route). Skip
      // navigation when that happens to prevent operating on a dead element.
      if (!mounted) return;
      // Use this.context (the State's BuildContext) rather than the parameter
      // captured in the closure, which could be a stale reference after rebuild.
      this.context.go(AppRoutes.library);
    });
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
                          await engine.resume();
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

                    // ── Timer & Instruction Area ───────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Timer / loading indicator
                            if (state.stepPhase == StepPhase.loadingTts)
                              _TtsLoadingIndicator(color: stepColor)
                            else
                              StepCountdownTimer(
                                timeRemaining: state.timeRemaining,
                                totalDuration: state.currentStepDuration,
                                isPaused: isPaused,
                              ),

                            const SizedBox(height: 32),

                            // ── Current instruction (centered text) ────
                            Text(
                              currentStepText,
                              style: GoogleFonts.manrope(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
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

                            const SizedBox(height: 32),

                            // ── Controls row ───────────────────────────
                            _ControlsRow(
                              isPaused: isPaused,
                              onTogglePause: _togglePause,
                              onSkipForward: _skipForward,
                              onSkipBackward: _skipBackward,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Next Up card + bottom area ─────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: NextUpPreview(
                        nextStepText: nextStepText,
                        nextStepType: state.nextStepType,
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert),
            color: colorScheme.primary,
          ),
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
        GestureDetector(
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

/// Indeterminate loading spinner shown while TTS audio is being fetched.
class _TtsLoadingIndicator extends StatelessWidget {
  const _TtsLoadingIndicator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 288,
      height: 288,
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
