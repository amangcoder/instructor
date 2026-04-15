import 'package:freezed_annotation/freezed_annotation.dart';

part 'shared_plan_preview.freezed.dart';
part 'shared_plan_preview.g.dart';

/// A lightweight preview of a shared plan, returned by the public
/// GET /api/plans/shared/:shareToken endpoint (no auth required).
///
/// Contains enough information to display a preview screen and prompt
/// the viewer to add the plan to their library.
@freezed
class SharedPlanPreview with _$SharedPlanPreview {
  const SharedPlanPreview._();

  const factory SharedPlanPreview({
    /// Human-readable plan name.
    required String name,

    /// Optional plan description provided by the creator.
    String? description,

    /// Raw step data for the preview — each element is a map with at least
    /// `name` (String) and `estimatedDurationMs` (int) keys.
    @Default([]) List<dynamic> steps,

    /// Total number of top-level steps in the plan.
    required int stepCount,

    /// Sum of all step estimated durations in milliseconds.
    required int estimatedDurationMs,
  }) = _SharedPlanPreview;

  factory SharedPlanPreview.fromJson(Map<String, dynamic> json) =>
      _$SharedPlanPreviewFromJson(json);
}
