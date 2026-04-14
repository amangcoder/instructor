import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';

part 'plan.freezed.dart';
part 'plan.g.dart';

/// The core domain model for a Plan — a time-sequenced script of steps.
///
/// Stored in the Drift [PlansTable] with [steps] serialised as a JSON column.
@freezed
class Plan with _$Plan {
  const Plan._();

  @Assert("defaultVoice != ''", 'defaultVoice must not be empty')
  const factory Plan({
    required String id,
    required String name,
    String? description,
    @Default(PlanCategory.custom) PlanCategory category,
    @Default([]) List<String> tags,
    @Default('aoede') String defaultVoice,
    @Default([]) List<PlanStep> steps,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? lastUsedAt,
    /// Whether this plan currently has an active GenAI TTS generation job.
    @Default(false) bool isActive,

    /// The current TTS generation status for this plan.
    ///
    /// One of: none | pending | processing | completed | partial | failed.
    @Default('none') String ttsStatus,

    /// Total number of TTS audio segments to generate for this plan.
    @Default(0) int ttsTotal,

    /// Number of TTS audio segments that have been generated so far.
    @Default(0) int ttsCompleted,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);

  /// Computes the total estimated duration by summing all top-level steps.
  Duration get totalDuration => steps.fold(
        Duration.zero,
        (acc, step) => acc + step.estimatedStepDuration,
      );
}
