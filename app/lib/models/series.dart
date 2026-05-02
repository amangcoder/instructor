import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/tags_json.dart';

part 'series.freezed.dart';
part 'series.g.dart';

/// A curated multi-session "program" that wraps an ordered sequence of plans
/// (e.g. "10 Days to Meditate", "Couch to 5K").
///
/// Returned by `GET /api/series` and `GET /api/series/:id`. Individual sessions
/// are normal [Plan]s referencing this series via [Plan.seriesId].
@freezed
class Series with _$Series {
  const Series._();

  const factory Series({
    required String id,
    required String name,
    String? description,
    @Default('custom') String category,
    @Default([])
    @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
    List<String> tags,
    @Default('aoede') String defaultVoice,
    @Default('enUS') String locale,
    @Default(false) bool isPublished,
    @Default(0) int sortOrder,

    /// Cached count of plans pointing to this series. Source of truth for
    /// "{N} days" labels in the UI.
    @Default(0) int totalSessions,

    /// Sessions in canonical Day-1-to-Day-N order. Empty when fetched from
    /// the list endpoint; populated by `GET /api/series/:id`.
    @Default([]) List<Plan> sessions,

    /// Category ID for this series.
    /// Associates the series with a category for hierarchical organization.
    String? categoryId,

    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Series;

  factory Series.fromJson(Map<String, dynamic> json) => _$SeriesFromJson(json);
}
