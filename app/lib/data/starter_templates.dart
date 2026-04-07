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
    this.defaultVoice = 'aoede',
  });

  final String name;
  final PlanCategory category;
  final String? description;

  /// Default voice ID — matches [PlanVoice] enum names.
  final String defaultVoice;
}

/// The 5 built-in starter templates, one per core [PlanCategory].
///
/// Each template maps to a deeply detailed, step-by-step guided plan
/// in [starter_plans.dart].
const List<StarterTemplate> kStarterTemplates = [
  // ── Yoga ──────────────────────────────────────────────────────────────────
  StarterTemplate(
    name: '108 Surya Namaskar',
    category: PlanCategory.yoga,
    description:
        'The complete 108 Sun Salutation practice — 5 fully guided rounds '
        'with every pose cued, then 103 self-paced rounds with chime markers, '
        'hydration breaks, and a closing Savasana.',
    defaultVoice: 'leda',
  ),

  // ── Meditation ────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Yoga Nidra',
    category: PlanCategory.meditation,
    description:
        'Traditional 30-minute yogic sleep — Sankalpa, full-body rotation of '
        'consciousness, breath counting, opposite sensations, visualization, '
        'and gentle externalization.',
    defaultVoice: 'leda',
  ),

  // ── Workout ───────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Full Body Strength Circuit',
    category: PlanCategory.workout,
    description:
        'Complete 35-minute session — dynamic warmup, 6 compound exercises '
        'with detailed form cues and 3 sets each, plus a guided cooldown stretch.',
    defaultVoice: 'charon',
  ),

  // ── Routine ───────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Morning Routine',
    category: PlanCategory.routine,
    description:
        'Structured 45-minute morning — hydration, gentle movement, '
        'cold-water face wash, mindful breakfast, journaling, '
        'and daily intention setting with guided prompts throughout.',
    defaultVoice: 'aoede',
  ),

  // ── Focus ─────────────────────────────────────────────────────────────────
  StarterTemplate(
    name: 'Deep Work Session',
    category: PlanCategory.focus,
    description:
        '2-hour guided deep work — environment setup ritual, two 50-minute '
        'focus blocks with a 10-minute active recovery break, progress '
        'check-ins, and a closing reflection.',
    defaultVoice: 'puck',
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
