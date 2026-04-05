import 'package:instructor/models/enums.dart';

/// A lightweight descriptor for a built-in starter Plan template.
///
/// Templates are shown in the [TemplatePickerSheet] during onboarding.
/// Selecting a template creates a new [Plan] in the database with the
/// template's metadata, then opens the Plan Editor so the user can
/// customise the steps.
class StarterTemplate {
  const StarterTemplate({
    required this.name,
    required this.category,
    this.description,
    this.defaultVoice = 'nova',
  });

  final String name;
  final PlanCategory category;
  final String? description;

  /// Default voice ID — matches [PlanVoice] enum names.
  final String defaultVoice;
}

/// The 15 built-in starter templates, grouped by [PlanCategory].
///
/// Ordered so that all templates for the same category are contiguous,
/// making it easy to build the grouped list view in [TemplatePickerSheet].
const List<StarterTemplate> kStarterTemplates = [
  // ── Yoga (3) ──────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Morning Yoga Flow',
    category: PlanCategory.yoga,
    description: 'Gentle 20-minute flow to energise your morning.',
    defaultVoice: 'shimmer',
  ),
  StarterTemplate(
    name: 'Sun Salutation',
    category: PlanCategory.yoga,
    description: '12-step sun salutation with timed holds.',
    defaultVoice: 'shimmer',
  ),
  StarterTemplate(
    name: 'Evening Wind Down',
    category: PlanCategory.yoga,
    description: 'Restorative poses to prepare you for restful sleep.',
    defaultVoice: 'shimmer',
  ),

  // ── Meditation (3) ────────────────────────────────────────────────────────
  StarterTemplate(
    name: '5-Minute Calm',
    category: PlanCategory.meditation,
    description: 'Quick mindfulness reset for busy days.',
    defaultVoice: 'shimmer',
  ),
  StarterTemplate(
    name: 'Body Scan',
    category: PlanCategory.meditation,
    description: 'Progressive relaxation from head to toe.',
    defaultVoice: 'shimmer',
  ),
  StarterTemplate(
    name: 'Breathing Focus',
    category: PlanCategory.meditation,
    description: 'Box breathing pattern with timed cues.',
    defaultVoice: 'shimmer',
  ),

  // ── Workout (3) ───────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'HIIT Circuit',
    category: PlanCategory.workout,
    description: '20/10 interval circuit — work, rest, repeat.',
    defaultVoice: 'onyx',
  ),
  StarterTemplate(
    name: 'Core Strength',
    category: PlanCategory.workout,
    description: 'Timed core exercises with rest intervals.',
    defaultVoice: 'onyx',
  ),
  StarterTemplate(
    name: 'Full Body Warmup',
    category: PlanCategory.workout,
    description: 'Dynamic warmup routine before any workout.',
    defaultVoice: 'onyx',
  ),

  // ── Cooking (2) ───────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Meal Prep Session',
    category: PlanCategory.cooking,
    description: 'Guided timer sequence for weekly meal prep.',
  ),
  StarterTemplate(
    name: 'Pasta Perfection',
    category: PlanCategory.cooking,
    description: 'Step-by-step timer guide for a perfect pasta dish.',
  ),

  // ── Routine (2) ───────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Morning Routine',
    category: PlanCategory.routine,
    description: 'Timed prompts to structure your morning.',
  ),
  StarterTemplate(
    name: 'Evening Routine',
    category: PlanCategory.routine,
    description: 'Wind down with a structured evening sequence.',
  ),

  // ── Focus (2) ─────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Pomodoro Session',
    category: PlanCategory.focus,
    description: '25-minute focus blocks with 5-minute breaks.',
  ),
  StarterTemplate(
    name: 'Deep Work Block',
    category: PlanCategory.focus,
    description: '90-minute focus session with scheduled breaks.',
  ),
];

/// Returns a map of [PlanCategory] → templates in that category,
/// preserving the insertion order of [kStarterTemplates].
Map<PlanCategory, List<StarterTemplate>> get starterTemplatesByCategory {
  final map = <PlanCategory, List<StarterTemplate>>{};
  for (final t in kStarterTemplates) {
    map.putIfAbsent(t.category, () => []).add(t);
  }
  return map;
}

/// Human-readable label for each [PlanCategory] used in the template picker.
String categoryLabel(PlanCategory category) {
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
      return 'Daily Routine';
    case PlanCategory.focus:
      return 'Focus';
    case PlanCategory.custom:
      return 'Custom';
  }
}
