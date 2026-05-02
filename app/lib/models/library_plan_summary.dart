import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:instructor/models/tags_json.dart';

part 'library_plan_summary.freezed.dart';
part 'library_plan_summary.g.dart';

/// A lightweight summary of a plan from the server library.
///
/// Returned by GET /api/library — contains enough metadata to display
/// a plan card in the [PlanLibraryScreen] without fetching the full [Plan].
@freezed
class LibraryPlanSummary with _$LibraryPlanSummary {
  const LibraryPlanSummary._();

  const factory LibraryPlanSummary({
    required String id,
    required String name,
    String? description,
    @Default('custom') String category,
    @Default('aoede') String defaultVoice,
    String? locale,

    /// Total estimated duration of all steps in seconds.
    @Default(0) int totalDurationSeconds,

    /// Number of steps in the plan.
    @Default(0) int stepCount,
    @Default([])
    @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
    List<String> tags,
  }) = _LibraryPlanSummary;

  factory LibraryPlanSummary.fromJson(Map<String, dynamic> json) =>
      _$LibraryPlanSummaryFromJson(json);
}
