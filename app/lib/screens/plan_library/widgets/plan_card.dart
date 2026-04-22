import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/widgets/tts_status_badge.dart';

// ────────────────────────────────────────────────────────────────────────────
// Shared category helpers (used by PlanCard and CategoryFilter)
// ────────────────────────────────────────────────────────────────────────────

IconData planCategoryIcon(PlanCategory category) {
  switch (category) {
    case PlanCategory.yoga:
      return Icons.self_improvement;
    case PlanCategory.meditation:
      return Icons.spa;
    case PlanCategory.workout:
      return Icons.fitness_center;
    case PlanCategory.cooking:
      return Icons.restaurant;
    case PlanCategory.routine:
      return Icons.checklist;
    case PlanCategory.focus:
      return Icons.center_focus_strong;
    case PlanCategory.custom:
      return Icons.star_outline;
  }
}

String planCategoryLabel(PlanCategory category) {
  switch (category) {
    case PlanCategory.yoga:
      return 'Yoga';
    case PlanCategory.meditation:
      return 'Meditation';
    case PlanCategory.workout:
      return 'Workout';
    case PlanCategory.cooking:
      return 'Cooking';
    case PlanCategory.routine:
      return 'Routine';
    case PlanCategory.focus:
      return 'Focus';
    case PlanCategory.custom:
      return 'Custom';
  }
}

String formatPlanDuration(Duration duration) {
  final h = duration.inHours;
  final m = duration.inMinutes.remainder(60);
  final s = duration.inSeconds.remainder(60);
  if (h > 0) {
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
  if (m > 0) {
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }
  return '${s}s';
}

String formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return 'Never used';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) {
    return diff.inMinutes == 1 ? '1 min ago' : '${diff.inMinutes} mins ago';
  }
  if (diff.inHours < 24) {
    return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
  }
  if (diff.inDays < 7) {
    return diff.inDays == 1 ? 'Yesterday' : '${diff.inDays} days ago';
  }
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) {
    return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  }
  final months = (diff.inDays / 30).floor();
  if (months < 12) {
    return months == 1 ? '1 month ago' : '$months months ago';
  }
  final years = (diff.inDays / 365).floor();
  return years == 1 ? '1 year ago' : '$years years ago';
}

/// Returns a tonal container color appropriate for [category].
Color categoryBadgeColor(PlanCategory category, ColorScheme cs) {
  switch (category) {
    case PlanCategory.yoga:
    case PlanCategory.meditation:
      return cs.tertiaryContainer;
    case PlanCategory.workout:
    case PlanCategory.cooking:
      return cs.secondaryContainer;
    case PlanCategory.focus:
    case PlanCategory.routine:
    case PlanCategory.custom:
      return cs.primaryContainer;
  }
}

Color categoryBadgeForeground(PlanCategory category, ColorScheme cs) {
  switch (category) {
    case PlanCategory.yoga:
    case PlanCategory.meditation:
      return cs.onTertiaryContainer;
    case PlanCategory.workout:
    case PlanCategory.cooking:
      return cs.onSecondaryContainer;
    case PlanCategory.focus:
    case PlanCategory.routine:
    case PlanCategory.custom:
      return cs.onPrimaryContainer;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PlanCard — Stitch "Square Card" style
// ────────────────────────────────────────────────────────────────────────────

/// Displays a [Plan] summary in the library list.
///
/// Stitch design: bg-surface-container-low p-6 rounded-xl, with icon badge,
/// category tag, title, description, duration, and play button.
///
/// When [onActivate] is provided and [plan.isActive] is false, a prominent
/// "Activate AI Voice" button is rendered between the description and the
/// bottom row. The button shows a loading indicator while the activation
/// request is in-flight and an inline error message on failure.
class PlanCard extends StatefulWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.onPlay,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
    this.onActivate,
    this.onPlayWithAiVoice,
  });

  final Plan plan;

  /// Called when the card body is tapped (navigate to detail/editor).
  final VoidCallback onTap;

  /// Called when the play button is tapped (start plan).
  final VoidCallback? onPlay;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  /// Async callback that triggers server-side TTS pre-generation for this
  /// plan. When non-null and [plan.isActive] is false, the card renders an
  /// "Activate AI Voice" button. The callback must throw (or complete with an
  /// error) to signal failure — the card then displays an inline error message.
  final Future<void> Function()? onActivate;

  /// Called when the "Play with AI Voice" button is tapped (TTS is ready).
  ///
  /// When non-null, this is used instead of [onPlay] for the AI-voice action
  /// so that callers can set the TTS playback mode to genai before navigating.
  /// Falls back to [onPlay] when null.
  final VoidCallback? onPlayWithAiVoice;

  @override
  State<PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<PlanCard> {
  bool _isActivating = false;
  String? _errorMessage;

  // ── Activate handler ──────────────────────────────────────────────────────

  Future<void> _handleActivate() async {
    if (widget.onActivate == null) return;
    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });
    try {
      await widget.onActivate!();
    } catch (e) {
      if (mounted) {
        setState(() {
          // Strip the Dart "Exception: " prefix for a cleaner user message.
          final raw = e.toString();
          _errorMessage = raw.startsWith('Exception: ')
              ? raw.substring('Exception: '.length)
              : raw.isNotEmpty
                  ? raw
                  : 'Failed to activate AI voice. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = categoryBadgeColor(widget.plan.category, colorScheme);
    final badgeFg = categoryBadgeForeground(widget.plan.category, colorScheme);

    final bool showTtsBadge = widget.plan.ttsStatus != 'none';
    final ttsStatus = widget.plan.ttsStatus;
    final bool isTtsLoading = _isActivating ||
        ttsStatus == 'pending' ||
        ttsStatus == 'processing';
    final bool isTtsReady =
        ttsStatus == 'completed' || ttsStatus == 'partial';
    final bool showActivateButton =
        (ttsStatus == 'none' || ttsStatus == 'failed') &&
            widget.onActivate != null;
    final bool showTtsActionButton =
        showActivateButton || _isActivating || isTtsLoading || isTtsReady;
    final double? ttsProgress = isTtsLoading && widget.plan.ttsTotal > 0
        ? widget.plan.ttsCompleted / widget.plan.ttsTotal
        : null;

    return Semantics(
      button: true,
      label: '${widget.plan.name}, ${planCategoryLabel(widget.plan.category)}, '
          '${formatPlanDuration(widget.plan.totalDuration)}, '
          '${formatRelativeTime(widget.plan.lastUsedAt)}',
      explicitChildNodes: true,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: (widget.onEdit != null ||
                widget.onDuplicate != null ||
                widget.onDelete != null)
            ? () => _showContextMenu(context)
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: icon badge + [TTS badge] + category tag ──────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 48×48 icon badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      planCategoryIcon(widget.plan.category),
                      color: badgeFg,
                      size: 24,
                    ),
                  ),
                  // Right side: optional TTS status + category tag
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showTtsBadge) ...[
                        TtsStatusBadge(
                          status: widget.plan.ttsStatus,
                          completed: widget.plan.ttsCompleted,
                          total: widget.plan.ttsTotal,
                          onRetry: (widget.plan.ttsStatus == 'failed' ||
                                      widget.plan.ttsStatus == 'partial') &&
                                  widget.onActivate != null
                              ? _handleActivate
                              : null,
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Category tag pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          planCategoryLabel(widget.plan.category).toUpperCase(),
                          style: TextStyle(
                            color: badgeFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────
              Text(
                widget.plan.name,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // ── Description / last used ────────────────────────────────
              Text(
                widget.plan.description ??
                    (widget.plan.steps.isEmpty
                        ? formatRelativeTime(widget.plan.lastUsedAt)
                        : '${widget.plan.steps.length} steps · '
                            '${formatRelativeTime(widget.plan.lastUsedAt)}'),
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // ── TTS action button ────────────────────────────────────
              if (showTtsActionButton) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: isTtsLoading
                        ? 'Loading Instructor Voice, please wait'
                        : isTtsReady
                            ? 'Play with AI Voice'
                            : 'Activate AI Voice for ${widget.plan.name}',
                    child: FilledButton.tonal(
                      onPressed: isTtsLoading
                          ? null
                          : isTtsReady
                              ? (widget.onPlayWithAiVoice ?? widget.onPlay)
                              : _handleActivate,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: isTtsLoading
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color:
                                            colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Loading Instructor Voice'),
                                    if (ttsProgress != null) ...[
                                      const Spacer(),
                                      Text(
                                        '${(ttsProgress * 100).round()}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme
                                              .onSecondaryContainer
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ttsProgress,
                                    minHeight: 3,
                                    backgroundColor: colorScheme
                                        .onSecondaryContainer
                                        .withValues(alpha: 0.2),
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            )
                          : isTtsReady
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_outline,
                                        size: 16,
                                        color:
                                            colorScheme.onSecondaryContainer,),
                                    const SizedBox(width: 6),
                                    const Text('Play with AI Voice'),
                                  ],
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.auto_awesome, size: 16),
                                    SizedBox(width: 6),
                                    Text('Activate AI Voice'),
                                  ],
                                ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // ── Bottom row: duration + play button ─────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.plan.totalDuration == Duration.zero
                        ? 'NEW'
                        : '${formatPlanDuration(widget.plan.totalDuration)} SESSION'
                            .toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.outline,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Play ${widget.plan.name}',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: widget.onPlay,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: colorScheme.onPrimaryContainer,
                          size: 24,
                          fill: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Context menu ──────────────────────────────────────────────────────────

  void _showContextMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onEdit!();
                },
              ),
            if (widget.onDuplicate != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Duplicate'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDuplicate!();
                },
              ),
            if (widget.onDelete != null)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
