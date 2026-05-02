import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LibraryPlanCard
// ─────────────────────────────────────────────────────────────────────────────

/// Displays a [LibraryPlanSummary] from the server library as a card with an
/// "Add to My Plans" action button.
///
/// Layout matches the existing [PlanCard] visual style:
///   bg-surface-container-low p-6 rounded-xl, icon badge, category tag,
///   title, description, duration + step count row, and an add button.
class LibraryPlanCard extends StatelessWidget {
  const LibraryPlanCard({
    super.key,
    required this.plan,
    required this.onAddTap,
  });

  final LibraryPlanSummary plan;

  /// Called when the user taps "Add to My Plans".
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = _categoryBadgeColor(plan.category, colorScheme);
    final badgeFg = _categoryBadgeForeground(plan.category, colorScheme);

    final duration = Duration(seconds: plan.totalDurationSeconds);
    final durationLabel = formatPlanDuration(duration);

    return Semantics(
      label: '${plan.name}, ${planCategoryLabel(plan.category)}, '
          '$durationLabel, ${plan.stepCount} steps',
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon badge + category tag ──────────────────────────
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
                    planCategoryIcon(plan.category),
                    color: badgeFg,
                    size: 24,
                  ),
                ),
                // Category tag pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

            // ── Title ────────────────────────────────────────────────────────
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

            // ── Description ──────────────────────────────────────────────────
            if (plan.description != null && plan.description!.isNotEmpty)
              Text(
                plan.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 24),

            // ── Bottom row: duration + step count + add button ───────────────
            Row(
              children: [
                // Duration chip
                Text(
                  '$durationLabel · ${plan.stepCount} step${plan.stepCount == 1 ? '' : 's'}'
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.outline,
                    letterSpacing: -0.3,
                  ),
                ),

                const Spacer(),

                // "Add to My Plans" button
                Semantics(
                  button: true,
                  label: 'Add ${plan.name} to My Plans',
                  child: TextButton.icon(
                    onPressed: onAddTap,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      backgroundColor: colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      Icons.add,
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    label: Text(
                      'Add to My Plans',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private category colour helpers (mirrors plan_card.dart)
// ─────────────────────────────────────────────────────────────────────────────

Color _categoryBadgeColor(String category, ColorScheme cs) =>
    categoryBadgeColor(category, cs);

Color _categoryBadgeForeground(String category, ColorScheme cs) =>
    categoryBadgeForeground(category, cs);
