import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/series.dart';
import 'package:instructor/models/series_subscription.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';

/// Compact card for a [Series] in the Library "Programs" rail.
///
/// Uses a subtle category-tinted gradient so each card reads as a hero tile
/// rather than a plain surface. Layout: icon + category/progress header,
/// title, description, and a footer with sessions count + chevron affordance.
///
/// [width] defaults to null (fill parent) so the card stretches in vertical
/// lists. In horizontal rails, pass an explicit width for a fixed footprint.
class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.series,
    required this.onTap,
    this.subscription,
    this.width,
    this.onRemove,
  });

  final Series series;
  final SeriesSubscription? subscription;
  final VoidCallback onTap;
  final double? width;

  /// If provided, long-pressing the card shows a context menu with a
  /// "Remove from My Programs" option that calls this callback.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeColor = _categoryBadgeColor(series.category, colorScheme);
    final badgeFg = _categoryBadgeForeground(series.category, colorScheme);

    final progressLabel = subscription == null
        ? null
        : 'Day ${(subscription!.currentSessionIndex + 1).clamp(1, series.totalSessions == 0 ? 1 : series.totalSessions)} of ${series.totalSessions}';

    return Semantics(
      label: '${series.name}, ${planCategoryLabel(series.category)}, '
          '${series.totalSessions} session${series.totalSessions == 1 ? '' : 's'}'
          '${progressLabel == null ? '' : ', $progressLabel'}',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  badgeColor.withValues(alpha: 0.22),
                  colorScheme.surfaceContainerLow,
                ),
                colorScheme.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onRemove != null ? () => _showContextMenu(context) : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: icon + category/progress ────────────────────
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          planCategoryIcon(series.category),
                          color: badgeFg,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      if (progressLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            progressLabel,
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                      else
                        Text(
                          planCategoryLabel(series.category).toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Title ────────────────────────────────────────────────
                  Text(
                    series.name,
                    style: GoogleFonts.manrope(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // ── Description ──────────────────────────────────────────
                  if (series.description != null &&
                      series.description!.isNotEmpty)
                    Text(
                      series.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 12),

                  // ── Footer: sessions count + chevron ─────────────────────
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${series.totalSessions} session${series.totalSessions == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.outline,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                series.name,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.remove_circle_outline, color: colorScheme.error),
              title: Text(
                'Remove from My Programs',
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                onRemove!();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Color _categoryBadgeColor(String category, ColorScheme cs) =>
    categoryBadgeColor(category, cs);

Color _categoryBadgeForeground(String category, ColorScheme cs) =>
    categoryBadgeForeground(category, cs);
