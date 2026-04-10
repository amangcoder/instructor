import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';

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
Color _categoryBadgeColor(PlanCategory category, ColorScheme cs) {
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

Color _categoryBadgeForeground(PlanCategory category, ColorScheme cs) {
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
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.onPlay,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
  });

  final Plan plan;
  /// Called when the card body is tapped (navigate to detail/editor).
  final VoidCallback onTap;
  /// Called when the play button is tapped (start plan).
  final VoidCallback? onPlay;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    var badgeColor = _categoryBadgeColor(plan.category, colorScheme);
    var badgeFg = _categoryBadgeForeground(plan.category, colorScheme);

    return Semantics(
      button: true,
      label: '${plan.name}, ${planCategoryLabel(plan.category)}, '
          '${formatPlanDuration(plan.totalDuration)}, '
          '${formatRelativeTime(plan.lastUsedAt)}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: (onEdit != null || onDuplicate != null || onDelete != null)
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
              // ── Top row: icon badge + category tag ──────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 48x48 icon badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      planCategoryIcon(plan.category),
                      color: badgeFg,
                      size: 24,
                    ),
                  ),
                  // Category tag pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      planCategoryLabel(plan.category).toUpperCase(),
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

              const SizedBox(height: 16),

              // ── Title ──────────────────────────────────────────────────
              Text(
                plan.name,
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
                plan.description ??
                    '${plan.steps.length} steps · ${formatRelativeTime(plan.lastUsedAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 24),

              // ── Bottom row: duration + play button ─────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${formatPlanDuration(plan.totalDuration)} SESSION'
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.outline,
                      letterSpacing: -0.3,
                    ),
                  ),
                  // Round play button
                  GestureDetector(
                    onTap: onPlay,
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEdit!();
                },
              ),
            if (onDuplicate != null)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Duplicate'),
                onTap: () {
                  Navigator.pop(ctx);
                  onDuplicate!();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text('Delete',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
