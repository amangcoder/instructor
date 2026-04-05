import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/screens/plan_library/plan_library_screen.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';

/// Horizontal scrollable row of [FilterChip] widgets for each [PlanCategory].
///
/// Includes an "All" chip that clears the category filter. The active chip is
/// highlighted. Tapping the already-selected chip deselects it (returns to
/// "All").
class CategoryFilter extends ConsumerWidget {
  const CategoryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryProvider);

    return SizedBox(
      height: 50,
      child: Semantics(
        label: 'Category filter',
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            // "All" chip
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) =>
                    ref.read(selectedCategoryProvider.notifier).state = null,
              ),
            ),
            // One chip per category
            ...PlanCategory.values.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  avatar: Icon(planCategoryIcon(category), size: 16),
                  label: Text(planCategoryLabel(category)),
                  selected: selected == category,
                  onSelected: (_) {
                    final notifier =
                        ref.read(selectedCategoryProvider.notifier);
                    // Tapping the active chip toggles it off.
                    notifier.state =
                        notifier.state == category ? null : category;
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
