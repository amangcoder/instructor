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
  final String category;
  final String? description;

  /// Default voice ID — matches [PlanVoice] enum names.
  final String defaultVoice;
}

/// The 5 built-in starter templates, one per core category slug.
const List<StarterTemplate> kStarterTemplates = [
  StarterTemplate(
    name: '108 Surya Namaskar',
    category: 'yoga',
    description:
        'The complete 108 Sun Salutation practice — 5 fully guided rounds '
        'with every pose cued, then 103 self-paced rounds with chime markers, '
        'hydration breaks, and a closing Savasana.',
    defaultVoice: 'leda',
  ),
  StarterTemplate(
    name: 'Yoga Nidra',
    category: 'meditation',
    description:
        'Traditional 30-minute yogic sleep — Sankalpa, full-body rotation of '
        'consciousness, breath counting, opposite sensations, visualization, '
        'and gentle externalization.',
    defaultVoice: 'leda',
  ),
  StarterTemplate(
    name: 'Full Body Strength Circuit',
    category: 'workout',
    description:
        'Complete 35-minute session — dynamic warmup, 6 compound exercises '
        'with detailed form cues and 3 sets each, plus a guided cooldown stretch.',
    defaultVoice: 'charon',
  ),
  StarterTemplate(
    name: 'Morning Routine',
    category: 'routine',
    description:
        'Structured 45-minute morning — hydration, gentle movement, '
        'cold-water face wash, mindful breakfast, journaling, '
        'and daily intention setting with guided prompts throughout.',
    defaultVoice: 'aoede',
  ),
  StarterTemplate(
    name: 'Deep Work Session',
    category: 'focus',
    description:
        '2-hour guided deep work — environment setup ritual, two 50-minute '
        'focus blocks with a 10-minute active recovery break, progress '
        'check-ins, and a closing reflection.',
    defaultVoice: 'puck',
  ),
];

/// Groups [kStarterTemplates] by category slug.
Map<String, List<StarterTemplate>> get starterTemplatesByCategory {
  final map = <String, List<StarterTemplate>>{};
  for (final t in kStarterTemplates) {
    map.putIfAbsent(t.category, () => []).add(t);
  }
  return map;
}

/// Human-readable label for a category slug. Capitalises unknown slugs.
String categoryLabel(String category) {
  switch (category) {
    case 'yoga':
      return 'Yoga';
    case 'meditation':
      return 'Meditation';
    case 'workout':
      return 'Workout';
    case 'cooking':
      return 'Cooking';
    case 'routine':
      return 'Daily Routine';
    case 'focus':
      return 'Focus';
    case 'sleep':
      return 'Sleep';
    case 'stress':
      return 'Stress';
    default:
      return category.isNotEmpty
          ? '${category[0].toUpperCase()}${category.substring(1)}'
          : 'Custom';
  }
}
