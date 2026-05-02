import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/categories_providers.dart';
import 'package:instructor/screens/plan_library/plan_library_screen.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';

/// Horizontal scrollable row of category chips matching the Stitch design:
/// px-6 py-2.5 rounded-full, selected bg-primary text-on-primary,
/// unselected bg-surface-container-low text-on-surface-variant.
///
/// Categories are fetched dynamically from the API so new categories (e.g.
/// "sleep") appear automatically without any code change.
class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoriesProvider);

    final slugs = categoriesAsync.whenData((cats) => cats.map((c) => c.slug).toList()).valueOrNull ?? [];

    return SizedBox(
      height: 56,
      child: Semantics(
        label: 'Category filter',
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _StitchChip(
                label: 'All',
                isSelected: selected == null,
                colorScheme: colorScheme,
                onTap: () =>
                    ref.read(selectedCategoryProvider.notifier).state = null,
              ),
            ),
            // One chip per category slug from the API
            ...slugs.map((slug) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StitchChip(
                  label: planCategoryLabel(slug),
                  isSelected: selected == slug,
                  colorScheme: colorScheme,
                  onTap: () {
                    final notifier = ref.read(selectedCategoryProvider.notifier);
                    notifier.state = notifier.state == slug ? null : slug;
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// A single chip matching Stitch design: rounded-full, large padding,
/// gradient-style selected state.
class _StitchChip extends StatelessWidget {
  const _StitchChip({
    required this.label,
    required this.isSelected,
    required this.colorScheme,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
