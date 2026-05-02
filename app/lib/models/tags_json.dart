/// Tag list (de)serialization helpers shared by [Plan] and [Series].
///
/// The server stores tags as a comma-separated TEXT column and returns them
/// in that format on the wire. Dart models expose tags as `List<String>` for
/// ergonomic UI usage, so these helpers bridge the two representations.
///
/// Used via `@JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)` on the
/// `tags` field of any freezed/json_serializable model.
library;

/// Parses a tag list from JSON, accepting either a list (`["a","b"]`) or a
/// comma-separated string (`"a,b"`). Empty/null/unknown shapes return `[]`.
List<String> tagsFromJson(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((t) => t.isNotEmpty).toList();
  }
  if (raw is String) {
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }
  return const [];
}

/// Serialises a tag list as a JSON array. The server normalises this back to
/// its TEXT representation on write.
List<String> tagsToJson(List<String> tags) => List<String>.unmodifiable(tags);
