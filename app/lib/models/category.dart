import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';
part 'category.g.dart';

/// A curated content category that groups series and plans.
///
/// Returned by `GET /api/categories` and `GET /api/admin/categories`.
/// Categories provide the top-level organization of the content hierarchy.
@freezed
class Category with _$Category {
  const Category._();

  const factory Category({
    required String id,
    required String slug,
    required String name,
    String? icon,
    String? color,
    @Default(0) int sortOrder,
    @Default(false) bool isPublished,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}
