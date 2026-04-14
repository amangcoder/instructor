import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/data/starter_templates.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/app_settings.dart';

/// Shows the [TemplatePickerSheet] as a modal bottom sheet.
///
/// Awaits the user's choice. Returns the new plan id when a template was
/// selected, or null when "Start from scratch" was chosen or the sheet was
/// dismissed without a choice.
///
/// This function also writes [AppSettingsKeys.hasCompletedOnboarding] to the
/// database and navigates to the Plan Editor before returning.
Future<void> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const TemplatePickerSheet(),
  );
}

/// A [DraggableScrollableSheet] that presents all 15 starter templates grouped
/// by category.
///
/// Tapping a template:
/// 1. Creates a new [Plan] in the database (a copy of the template metadata).
/// 2. Writes [AppSettingsKeys.hasCompletedOnboarding] = `'true'`.
/// 3. Navigates to `/editor/:newId`.
///
/// Tapping "Start from scratch":
/// 1. Writes [AppSettingsKeys.hasCompletedOnboarding] = `'true'`.
/// 2. Navigates to `/editor/new` (blank editor).
class TemplatePickerSheet extends ConsumerStatefulWidget {
  const TemplatePickerSheet({super.key});

  @override
  ConsumerState<TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<TemplatePickerSheet> {
  bool _isLoading = false;

  // ── Template selection ────────────────────────────────────────────────────

  Future<void> _selectTemplate(StarterTemplate template) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(planRepositoryProvider);
      final settings = ref.read(appSettingsProvider);
      final now = DateTime.now();

      final newId = await repo.createPlan(
        Plan(
          id: '',
          name: template.name,
          description: template.description,
          category: template.category,
          defaultVoice: template.defaultVoice,
          steps: const [],
          createdAt: now,
          updatedAt: now,
        ),
      );

      await settings.setHasCompletedOnboarding();

      if (!mounted) return;
      // Pop the sheet, then navigate.
      Navigator.of(context).pop();
      if (!context.mounted) return;
      context.go('/editor/$newId');
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create Plan — please try again.')),
      );
    }
  }

  Future<void> _startFromScratch() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final settings = ref.read(appSettingsProvider);
      await settings.setHasCompletedOnboarding();

      if (!mounted) return;
      Navigator.of(context).pop();
      if (!context.mounted) return;
      context.go(AppRoutes.editorNew);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final templatesByCategory = starterTemplatesByCategory;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Sheet header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a Starter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pick a template to get started quickly, '
                      'or build your own from scratch.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // ── Template list ─────────────────────────────────────────────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          // Grouped categories
                          ...templatesByCategory.entries.map(
                            (entry) => _CategorySection(
                              category: entry.key,
                              templates: entry.value,
                              onSelect: _selectTemplate,
                            ),
                          ),
                          const Divider(height: 32),
                          // Start from scratch option
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              title: const Text('Start from scratch'),
                              subtitle: const Text('Build your own Plan step by step'),
                              onTap: _startFromScratch,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.templates,
    required this.onSelect,
  });

  final PlanCategory category;
  final List<StarterTemplate> templates;
  final ValueChanged<StarterTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            categoryLabel(category).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        ...templates.map(
          (t) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: ListTile(
              leading: _CategoryIcon(category: category),
              title: Text(t.name),
              subtitle: t.description != null ? Text(t.description!) : null,
              onTap: () => onSelect(t),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Category icon ─────────────────────────────────────────────────────────────

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.category});

  final PlanCategory category;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = _iconData(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  (IconData, Color) _iconData(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (category) {
      case PlanCategory.yoga:
        return (Icons.self_improvement, Colors.green.shade600);
      case PlanCategory.meditation:
        return (Icons.spa, Colors.purple.shade400);
      case PlanCategory.workout:
        return (Icons.fitness_center, Colors.orange.shade600);
      case PlanCategory.cooking:
        return (Icons.restaurant, Colors.red.shade500);
      case PlanCategory.routine:
        return (Icons.wb_sunny, Colors.amber.shade600);
      case PlanCategory.focus:
        return (Icons.timer, colorScheme.primary);
      case PlanCategory.custom:
        return (Icons.edit, colorScheme.onSurfaceVariant);
    }
  }
}
