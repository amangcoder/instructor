import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screen_brightness/screen_brightness.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_execution_engine.dart';
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
    final engine = ref.read(planExecutionEngineProvider);
    await engine.skipForward();
  }

  Future<void> _skipBackward() async {
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
    _completionHandled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showCompletionSummary(state);
      if (mounted) {
        context.go(AppRoutes.library);
      }
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
      backgroundColor: Colors.black,
      body: stateAsync.when(
        data: (state) => _buildContent(context, state),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Session error',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(AppRoutes.library),
                child: const Text('Return to Library'),
              ),
            ],
          ),
        ),
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

    // Determine step-type colour for the background accent.
    final stepColor = StepColors.colorForType(stepType);
    final stepBgColor = stepColor.withValues(alpha: 0.18);

    final isPaused = state.status == ExecutionStatus.paused;

    // The full-screen gesture detector is excluded from the semantics tree
    // because its tap/swipe controls conflict with VoiceOver/TalkBack
    // navigation gestures. A dedicated Semantics button below provides the
    // pause action for screen-reader users.
    return Stack(
      fit: StackFit.expand,
      children: [
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Top bar: plan name + pause indicator ──────────
                      _TopBar(
                        planName: state.plan.name,
                        isPaused: isPaused,
                        onClose: _onEndRequested,
                      ),

                      const Spacer(),

                      // ── Countdown timer ───────────────────────────────
                      StepCountdownTimer(
                        timeRemaining: state.timeRemaining,
                        totalDuration: state.timeRemaining.inSeconds > 0
                            ? state.timeRemaining
                            : const Duration(minutes: 1),
                        color: stepColor,
                      ),

                      const SizedBox(height: 32),

                      // ── Current step text with step-type color bg ─────
                      _CurrentStepCard(
                        text: currentStepText,
                        stepType: stepType,
                        backgroundColor: stepBgColor,
                        accentColor: stepColor,
                      ),

                      const SizedBox(height: 24),

                      // ── Next-up preview ───────────────────────────────
                      NextUpPreview(
                        nextStepText: nextStepText,
                        nextStepType: stepType,
                      ),

                      const Spacer(),

                      // ── Gesture hint ──────────────────────────────────
                      _GestureHint(isPaused: isPaused),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Dedicated accessible pause/resume button for screen readers ─
        // Positioned at bottom-centre; invisible visually but reachable by
        // VoiceOver/TalkBack swipe navigation.
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
              onTap: () {
                _togglePause();
              },
              child: const SizedBox(width: 80, height: 80),
            ),
          ),
        ),

        // ── Dedicated accessible end-session button for screen readers ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: Semantics(
            button: true,
            label: 'End session',
            hint: 'Activates to stop the session and return to the library',
            onTap: _onEndRequested,
            child: const SizedBox(width: 48, height: 48),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

/// Top bar showing the plan name and a small pause/playing badge.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.planName,
    required this.isPaused,
    required this.onClose,
  });

  final String planName;
  final bool isPaused;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            planName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        if (isPaused)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pause, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text(
                  'Paused',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          color: Colors.white.withValues(alpha: 0.6),
          tooltip: 'End session',
        ),
      ],
    );
  }
}

/// Displays the current step's instruction text with the step-type colour
/// as a background tint.
class _CurrentStepCard extends StatelessWidget {
  const _CurrentStepCard({
    required this.text,
    required this.stepType,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String text;
  final StepType stepType;
  final Color backgroundColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Current step: $text',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step-type label
            Row(
              children: [
                StepColors.iconForType(stepType, size: 16),
                const SizedBox(width: 6),
                Text(
                  _stepTypeLabel(stepType),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Main instruction text (≥ 24sp as required)
            Text(
              text.isEmpty ? '—' : text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepTypeLabel(StepType type) => switch (type) {
        StepType.say => 'SAY',
        StepType.notify => 'NOTIFY',
        StepType.play => 'PLAY',
        StepType.wait => 'WAIT',
        StepType.repeat => 'REPEAT',
        StepType.stopAudio => 'STOP AUDIO',
      };
}

/// Small hint text at the bottom explaining available gestures.
class _GestureHint extends StatelessWidget {
  const _GestureHint({required this.isPaused});

  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final hintText = isPaused
        ? 'Tap to resume  •  Swipe right to skip'
        : 'Tap to pause  •  Swipe to skip  •  Hold 2s to end';

    return Text(
      hintText,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 12,
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
    );
  }
}
