import 'package:flutter/material.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';

// ────────────────────────────────────────────────────────────────────────────
// Shared category helpers (used by PlanCard and CategoryFilter)
// ────────────────────────────────────────────────────────────────────────────

/// Returns the Material icon associated with [category].
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

/// Returns the display label for [category].
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

/// Formats [duration] as a human-readable string (e.g. "5m 30s", "1h 10m").
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

/// Formats [dateTime] as a relative human-readable string (e.g. "2 hours ago").
///
/// Returns "Never used" when [dateTime] is null.
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

// ────────────────────────────────────────────────────────────────────────────
// PlanCard
// ────────────────────────────────────────────────────────────────────────────

/// Displays a [Plan] summary in the library list.
///
/// Shows the plan name (bold), category icon, total duration, and relative
/// last-used date. A [PopupMenuButton] provides Edit, Duplicate, and Delete
/// actions.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Plan plan;

  /// Called when the user taps the card body (triggers countdown → start).
  final VoidCallback onTap;

  /// Called when the user selects Edit from the popup menu.
  final VoidCallback onEdit;

  /// Called when the user selects Duplicate from the popup menu.
  final VoidCallback onDuplicate;

  /// Called when the user selects Delete from the popup menu.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: '${plan.name}, ${planCategoryLabel(plan.category)}, '
          '${formatPlanDuration(plan.totalDuration)}, '
          '${formatRelativeTime(plan.lastUsedAt)}',
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                // Category icon badge
                _CategoryBadge(
                  category: plan.category,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 12),

                // Plan name + meta row
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _MetaRow(plan: plan, colorScheme: colorScheme),
                    ],
                  ),
                ),

                // Overflow menu
                ExcludeSemantics(
                  child: _OverflowMenu(
                    onEdit: onEdit,
                    onDuplicate: onDuplicate,
                    onDelete: onDelete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Private sub-widgets ───────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({
    required this.category,
    required this.colorScheme,
  });

  final PlanCategory category;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        planCategoryIcon(category),
        color: colorScheme.onPrimaryContainer,
        size: 22,
        semanticLabel: planCategoryLabel(category),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.plan, required this.colorScheme});

  final Plan plan;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 13, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(formatPlanDuration(plan.totalDuration), style: style),
        const SizedBox(width: 12),
        Icon(Icons.access_time, size: 13, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            formatRelativeTime(plan.lastUsedAt),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

enum _CardAction { edit, duplicate, delete }

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CardAction>(
      tooltip: 'Plan options',
      onSelected: (action) {
        switch (action) {
          case _CardAction.edit:
            onEdit();
          case _CardAction.duplicate:
            onDuplicate();
          case _CardAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _CardAction.edit,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem(
          value: _CardAction.duplicate,
          child: ListTile(
            leading: Icon(Icons.copy_outlined),
            title: Text('Duplicate'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const PopupMenuItem(
          value: _CardAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
