import 'package:drift/drift.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';

/// Mixin providing shared helper methods for plan repository implementations.
///
/// Both [DriftPlanRepository] and [ApiPlanRepository] perform identical
/// conversions between domain [Plan] objects and Drift [PlansTableData]/
/// [PlansTableCompanion] rows. This mixin eliminates 120+ lines of duplication.
///
/// All methods are pure functions of their arguments — the mixin carries no state.
mixin PlanRepositoryMixin {
  /// Converts a Drift [PlansTableData] row into a domain [Plan].
  Plan rowToPlan(PlansTableData row) {
    return Plan(
      id: row.id,
      name: row.name,
      description: row.description,
      category: row.category,
      tags: row.tags,
      defaultVoice: row.defaultVoice,
      steps: row.steps,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      lastUsedAt: row.lastUsedAt,
      isActive: row.isActive,
      ttsStatus: row.ttsStatus,
      ttsTotal: row.ttsTotal,
      ttsCompleted: row.ttsCompleted,
      libraryId: row.libraryId,
    );
  }

  /// Converts a domain [Plan] into a Drift [PlansTableCompanion] for updates.
  ///
  /// The [id] column is intentionally excluded — callers that need to set the
  /// id (e.g. in [createPlan]) add it via [PlansTableCompanion.copyWith].
  PlansTableCompanion planToCompanion(Plan plan) {
    return PlansTableCompanion(
      name: Value(plan.name),
      description: Value(plan.description),
      category: Value(plan.category),
      tags: Value(plan.tags),
      defaultVoice: Value(plan.defaultVoice),
      steps: Value(plan.steps),
      createdAt: Value(plan.createdAt),
      updatedAt: Value(plan.updatedAt),
      lastUsedAt: Value(plan.lastUsedAt),
      isActive: Value(plan.isActive),
      ttsStatus: Value(plan.ttsStatus),
      ttsTotal: Value(plan.ttsTotal),
      ttsCompleted: Value(plan.ttsCompleted),
      libraryId: Value(plan.libraryId),
    );
  }

  /// Recursively remaps voiceId in [SayStep]s and [RepeatStep] children.
  ///
  /// Returns null if no step was changed. This allows callers to skip the
  /// database update when remapping produces no changes.
  ///
  /// Recursion handles nested [RepeatStep] structures containing [SayStep]s.
  List<PlanStep>? remapSteps(
    List<PlanStep> steps,
    Map<String, String> voiceMap,
  ) {
    var changed = false;
    final result = steps.map((step) {
      return switch (step) {
        SayStep(:final voiceId) when voiceId != null &&
            voiceMap.containsKey(voiceId) =>
          () {
            changed = true;
            return (step as SayStep).copyWith(voiceId: voiceMap[voiceId]);
          }(),
        RepeatStep(:final children) => () {
            final remapped = remapSteps(children, voiceMap);
            if (remapped != null) {
              changed = true;
              return (step as RepeatStep).copyWith(children: remapped);
            }
            return step;
          }(),
        _ => step,
      };
    }).toList();
    return changed ? result : null;
  }

  /// Escapes special LIKE pattern characters (`%`, `_`, `\`) in [input].
  ///
  /// Converts user-typed text to a literal string that does not match
  /// as a LIKE pattern wildcard. Used to safely embed user search queries
  /// into LIKE clauses.
  ///
  /// Example:
  ///   ```dart
  ///   final query = 'yoga 50%';
  ///   final escaped = escapeLikePattern(query);  // 'yoga 50\%'
  ///   // query.where((t) => t.name.like('%$escaped%'))  // matches literal '50%'
  ///   ```
  String escapeLikePattern(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
