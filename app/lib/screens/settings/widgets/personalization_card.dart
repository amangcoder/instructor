import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/settings_providers.dart';
import 'package:instructor/services/app_settings.dart';

import 'shared_settings_widgets.dart';

/// Activity level labels — displayed in the UI and lowercased for persistence.
const _activityLevels = ['Beginner', 'Intermediate', 'Advanced'];

/// Goal labels — displayed in the UI and lowercased for persistence.
const _goalLabels = ['Yoga', 'Meditation', 'Workout', 'Cooking', 'Routine', 'Focus'];

/// Personalization card with ChoiceChip activity level selector and
/// multi-select FilterChip goal picker.
///
/// Uses a [surfaceVariant] background tint to visually distinguish itself from
/// normal [SettingsCard] widgets (which use surfaceContainerLowest).
///
/// Local state is updated synchronously for instant (<16 ms) visual feedback,
/// and the persistence write is fired without awaiting.
class PersonalizationCard extends ConsumerStatefulWidget {
  const PersonalizationCard({super.key});

  @override
  ConsumerState<PersonalizationCard> createState() =>
      _PersonalizationCardState();
}

class _PersonalizationCardState extends ConsumerState<PersonalizationCard> {
  /// Currently selected activity level (lowercased), or null when unset.
  String? _selectedLevel;

  /// Currently selected goal tags (lowercased).
  Set<String> _selectedGoals = {};

  /// Whether the 'Saved' indicator is visible.
  bool _showSaved = false;

  /// Timer that auto-hides the 'Saved' indicator after 1.5 s.
  Timer? _savedTimer;

  /// Guards against overwriting user edits with provider-seeded values.
  bool _levelSeeded = false;
  bool _goalsSeeded = false;

  @override
  void dispose() {
    _savedTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Saved indicator animation
  // ─────────────────────────────────────────────────────────────────────────

  void _flashSaved() {
    _savedTimer?.cancel();
    setState(() => _showSaved = true);
    _savedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Persistence helpers
  // ─────────────────────────────────────────────────────────────────────────

  void _onLevelSelected(String label, bool selected) {
    final value = selected ? label.toLowerCase() : '';
    setState(() => _selectedLevel = selected ? label.toLowerCase() : null);
    _levelSeeded = true; // user has interacted — stop seeding

    final settings = ref.read(appSettingsProvider);
    unawaited(settings.write(AppSettingsKeys.profileActivityLevel, value));
    _flashSaved();
  }

  void _onGoalToggled(String label, bool selected) {
    final tag = label.toLowerCase();
    setState(() {
      if (selected) {
        _selectedGoals.add(tag);
      } else {
        _selectedGoals.remove(tag);
      }
    });
    _goalsSeeded = true; // user has interacted — stop seeding

    final settings = ref.read(appSettingsProvider);
    unawaited(settings.write(
      AppSettingsKeys.profileGoals,
      _selectedGoals.join(','),
    ));
    _flashSaved();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    // Seed local state from persisted values (only until the user interacts).
    ref.listen<AsyncValue<String>>(activityLevelSettingProvider, (_, next) {
      if (!_levelSeeded) {
        final value = next.valueOrNull ?? '';
        if (value.isNotEmpty) {
          setState(() {
            _selectedLevel = value;
            _levelSeeded = true;
          });
        }
      }
    });

    ref.listen<AsyncValue<List<String>>>(profileGoalsSettingProvider, (_, next) {
      if (!_goalsSeeded) {
        final values = next.valueOrNull ?? [];
        if (values.isNotEmpty) {
          setState(() {
            _selectedGoals = values.toSet();
            _goalsSeeded = true;
          });
        }
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Activity Level ──────────────────────────────────────────────
          Text('Activity Level', style: textTheme.titleSmall),
          if (_selectedLevel == null)
            Text(
              'Choose one',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Activity level selector',
            child: Wrap(
              spacing: 8,
              children: _activityLevels.map((label) {
                final tag = label.toLowerCase();
                return ChoiceChip(
                  label: Text(label),
                  selected: _selectedLevel == tag,
                  onSelected: (selected) => _onLevelSelected(label, selected),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // ── Goals ───────────────────────────────────────────────────────
          Text('Your Goals', style: textTheme.titleSmall),
          Text(
            'Choose all that apply',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Goal selector',
            child: Wrap(
              spacing: 8,
              children: _goalLabels.map((label) {
                final tag = label.toLowerCase();
                return FilterChip(
                  label: Text(label),
                  selected: _selectedGoals.contains(tag),
                  showCheckmark: true,
                  onSelected: (selected) => _onGoalToggled(label, selected),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Saved indicator ─────────────────────────────────────────────
          AnimatedOpacity(
            opacity: _showSaved ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Saved',
                style:
                    textTheme.bodySmall?.copyWith(color: colorScheme.primary),
              ),
            ),
          ),

          // ── Unauthenticated note ────────────────────────────────────────
          if (!isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Preferences saved on this device only. Sign in to sync across devices.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
