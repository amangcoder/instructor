import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/plan_voice.dart';
import 'package:instructor/models/tags_json.dart';

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
    @Default('custom') String category,
    @Default([])
    @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
    List<String> tags,
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

    /// The library plan ID this plan was cloned from, if any.
    ///
    /// Set when the user adds a plan from the Discover tab. Used to prevent
    /// duplicate additions across sessions.
    String? libraryId,

    /// The series this plan belongs to, if any. NULL for standalone plans.
    /// Used to render "{Series Name} · Day N" in the mini player and to
    /// drive series subscription progress on completion.
    String? seriesId,

    /// Parent plan ID for hierarchical sub-plans. NULL for top-level plans.
    /// Used to build the tree of plans under a single parent.
    String? parentPlanId,

    /// Position of this plan within its parent's children list.
    /// Used for ordering sub-plans.
    @Default(0) int position,

    /// Child plans (sub-plans) under this plan.
    /// Empty for leaf plans.
    @Default([]) List<Plan> children,

    /// List of voice synthesis results for this plan.
    /// Each PlanVoice tracks the status of a specific (voice, locale) rendering.
    /// User-visibility requires at least one PlanVoice with status='ready'.
    @Default([]) List<PlanVoice> voices,

    /// Visibility state of this plan.
    /// Values: 'private' (only owner), 'pending_review' (awaiting admin approval),
    /// 'public' (published and discoverable).
    @Default('public') String visibility,

    /// Whether this plan is published and discoverable by other users.
    @Default(false) bool isPublished,

    /// User ID of the plan's author. Present for user-authored plans.
    /// NULL for admin-created or imported plans.
    String? ownerId,
  }) = _Plan;

  factory Plan.fromJson(Map<String, dynamic> json) => _$PlanFromJson(json);

  /// Computes the total estimated duration by summing all top-level steps.
  Duration get totalDuration => steps.fold(
        Duration.zero,
        (acc, step) => acc + step.estimatedStepDuration,
      );
}
