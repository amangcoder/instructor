import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MiniPlayerBar
// ─────────────────────────────────────────────────────────────────────────────

/// Persistent 64dp mini-player bar displayed above the bottom navigation bar
/// whenever a plan execution session is active (playing or paused).
///
/// Shows plan name, current step description, a linear progress indicator, and
/// play/pause/stop controls.  Tapping the body area navigates to NowPlayingScreen.
///
/// Visibility is controlled by [hasActiveSessionProvider] via [AnimatedSize]
/// in [BottomNavShell] — this widget returns [SizedBox.shrink] when inactive.
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(hasActiveSessionProvider);
    if (!isActive) return const SizedBox.shrink();

    final stateAsync = ref.watch(executionStateProvider);
    final progress = ref.watch(stepProgressFractionProvider);

    return stateAsync.maybeWhen(
      data: (state) => _MiniPlayerContent(
        state: state,
        progress: progress,
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MiniPlayerContent — handles gestures, layout, and actions
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayerContent extends ConsumerWidget {
  const _MiniPlayerContent({
    required this.state,
    required this.progress,
  });

  final ExecutionState state;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlaying = state.status == ExecutionStatus.running;

    return GestureDetector(
      // Swipe-up or tap on body area both navigate to NowPlayingScreen.
      // Both handlers live on the outermost GestureDetector to avoid gesture
      // arena conflicts from nested GestureDetectors.
      onTap: () => _navigateToNowPlaying(context),
      onVerticalDragEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -500) {
          _navigateToNowPlaying(context);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // ── Progress indicator along the top edge ─────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                // ── Main row ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                  child: Row(
                    children: [
                      // ── Tappable body: plan name + step text ──────────
                      Expanded(
                        child: Semantics(
                          label: 'Open ${state.plan.name}',
                          button: true,
                          hint: 'Double tap to open now playing screen',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Plan name
                                Text(
                                  state.plan.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                // Current step description
                                Text(
                                  state.currentStepText ??
                                      _stepTypeLabel(state.currentStepType),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Play/Pause button ─────────────────────────────
                      Semantics(
                        label: isPlaying ? 'Pause' : 'Play',
                        button: true,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 28,
                            ),
                            color: colorScheme.primary,
                            onPressed: () => _togglePlayPause(ref),
                            tooltip: isPlaying ? 'Pause' : 'Resume',
                          ),
                        ),
                      ),

                      // ── Stop button ───────────────────────────────────
                      Semantics(
                        label: 'Stop session',
                        button: true,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            icon: const Icon(Icons.stop_rounded, size: 26),
                            color: colorScheme.onSurfaceVariant,
                            onPressed: () =>
                                _confirmStop(context, ref),
                            tooltip: 'Stop session',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToNowPlaying(BuildContext context) {
    final router = GoRouter.of(context);
    final currentLocation =
        router.routerDelegate.currentConfiguration.fullPath;
    if (currentLocation != AppRoutes.nowPlaying) {
      context.go(AppRoutes.nowPlaying);
    }
  }

  void _togglePlayPause(WidgetRef ref) {
    final engine = ref.read(planExecutionEngineProvider);
    if (state.status == ExecutionStatus.running) {
      engine.pause();
    } else {
      engine.resume();
    }
  }

  Future<void> _confirmStop(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End session?'),
        content: const Text(
          'This will stop the current plan session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final engine = ref.read(planExecutionEngineProvider);
      await engine.stop();
    }
  }

  String _stepTypeLabel(StepType? type) {
    switch (type) {
      case StepType.say:
        return 'Speaking…';
      case StepType.wait:
        return 'Waiting…';
      case StepType.play:
        return 'Playing audio…';
      case StepType.notify:
        return 'Notification…';
      case StepType.count:
        return 'Counting…';
      case StepType.stopAudio:
        return 'Stopping audio…';
      default:
        return 'Running…';
    }
  }
}
