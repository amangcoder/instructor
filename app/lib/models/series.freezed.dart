// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'series.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Series _$SeriesFromJson(Map<String, dynamic> json) {
  return _Series.fromJson(json);
}

/// @nodoc
mixin _$Series {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags => throw _privateConstructorUsedError;
  String get defaultVoice => throw _privateConstructorUsedError;
  String get locale => throw _privateConstructorUsedError;
  bool get isPublished => throw _privateConstructorUsedError;
  int get sortOrder => throw _privateConstructorUsedError;

  /// Cached count of plans pointing to this series. Source of truth for
  /// "{N} days" labels in the UI.
  int get totalSessions => throw _privateConstructorUsedError;

  /// Sessions in canonical Day-1-to-Day-N order. Empty when fetched from
  /// the list endpoint; populated by `GET /api/series/:id`.
  List<Plan> get sessions => throw _privateConstructorUsedError;

  /// Category ID for this series.
  /// Associates the series with a category for hierarchical organization.
  String? get categoryId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Series to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Series
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SeriesCopyWith<Series> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SeriesCopyWith<$Res> {
  factory $SeriesCopyWith(Series value, $Res Function(Series) then) =
      _$SeriesCopyWithImpl<$Res, Series>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags,
      String defaultVoice,
      String locale,
      bool isPublished,
      int sortOrder,
      int totalSessions,
      List<Plan> sessions,
      String? categoryId,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class _$SeriesCopyWithImpl<$Res, $Val extends Series>
    implements $SeriesCopyWith<$Res> {
  _$SeriesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Series
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = null,
    Object? tags = null,
    Object? defaultVoice = null,
    Object? locale = null,
    Object? isPublished = null,
    Object? sortOrder = null,
    Object? totalSessions = null,
    Object? sessions = null,
    Object? categoryId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      totalSessions: null == totalSessions
          ? _value.totalSessions
          : totalSessions // ignore: cast_nullable_to_non_nullable
              as int,
      sessions: null == sessions
          ? _value.sessions
          : sessions // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SeriesImplCopyWith<$Res> implements $SeriesCopyWith<$Res> {
  factory _$$SeriesImplCopyWith(
          _$SeriesImpl value, $Res Function(_$SeriesImpl) then) =
      __$$SeriesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags,
      String defaultVoice,
      String locale,
      bool isPublished,
      int sortOrder,
      int totalSessions,
      List<Plan> sessions,
      String? categoryId,
      DateTime createdAt,
      DateTime updatedAt});
}

/// @nodoc
class __$$SeriesImplCopyWithImpl<$Res>
    extends _$SeriesCopyWithImpl<$Res, _$SeriesImpl>
    implements _$$SeriesImplCopyWith<$Res> {
  __$$SeriesImplCopyWithImpl(
      _$SeriesImpl _value, $Res Function(_$SeriesImpl) _then)
      : super(_value, _then);

  /// Create a copy of Series
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = null,
    Object? tags = null,
    Object? defaultVoice = null,
    Object? locale = null,
    Object? isPublished = null,
    Object? sortOrder = null,
    Object? totalSessions = null,
    Object? sessions = null,
    Object? categoryId = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$SeriesImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      locale: null == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
      sortOrder: null == sortOrder
          ? _value.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      totalSessions: null == totalSessions
          ? _value.totalSessions
          : totalSessions // ignore: cast_nullable_to_non_nullable
              as int,
      sessions: null == sessions
          ? _value._sessions
          : sessions // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      categoryId: freezed == categoryId
          ? _value.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SeriesImpl extends _Series {
  const _$SeriesImpl(
      {required this.id,
      required this.name,
      this.description,
      this.category = 'custom',
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags = const [],
      this.defaultVoice = 'aoede',
      this.locale = 'enUS',
      this.isPublished = false,
      this.sortOrder = 0,
      this.totalSessions = 0,
      final List<Plan> sessions = const [],
      this.categoryId,
      required this.createdAt,
      required this.updatedAt})
      : _tags = tags,
        _sessions = sessions,
        super._();

  factory _$SeriesImpl.fromJson(Map<String, dynamic> json) =>
      _$$SeriesImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey()
  final String category;
  final List<String> _tags;
  @override
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final String defaultVoice;
  @override
  @JsonKey()
  final String locale;
  @override
  @JsonKey()
  final bool isPublished;
  @override
  @JsonKey()
  final int sortOrder;

  /// Cached count of plans pointing to this series. Source of truth for
  /// "{N} days" labels in the UI.
  @override
  @JsonKey()
  final int totalSessions;

  /// Sessions in canonical Day-1-to-Day-N order. Empty when fetched from
  /// the list endpoint; populated by `GET /api/series/:id`.
  final List<Plan> _sessions;

  /// Sessions in canonical Day-1-to-Day-N order. Empty when fetched from
  /// the list endpoint; populated by `GET /api/series/:id`.
  @override
  @JsonKey()
  List<Plan> get sessions {
    if (_sessions is EqualUnmodifiableListView) return _sessions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sessions);
  }

  /// Category ID for this series.
  /// Associates the series with a category for hierarchical organization.
  @override
  final String? categoryId;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Series(id: $id, name: $name, description: $description, category: $category, tags: $tags, defaultVoice: $defaultVoice, locale: $locale, isPublished: $isPublished, sortOrder: $sortOrder, totalSessions: $totalSessions, sessions: $sessions, categoryId: $categoryId, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SeriesImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.defaultVoice, defaultVoice) ||
                other.defaultVoice == defaultVoice) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.isPublished, isPublished) ||
                other.isPublished == isPublished) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.totalSessions, totalSessions) ||
                other.totalSessions == totalSessions) &&
            const DeepCollectionEquality().equals(other._sessions, _sessions) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      category,
      const DeepCollectionEquality().hash(_tags),
      defaultVoice,
      locale,
      isPublished,
      sortOrder,
      totalSessions,
      const DeepCollectionEquality().hash(_sessions),
      categoryId,
      createdAt,
      updatedAt);

  /// Create a copy of Series
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SeriesImplCopyWith<_$SeriesImpl> get copyWith =>
      __$$SeriesImplCopyWithImpl<_$SeriesImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SeriesImplToJson(
      this,
    );
  }
}

abstract class _Series extends Series {
  const factory _Series(
      {required final String id,
      required final String name,
      final String? description,
      final String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags,
      final String defaultVoice,
      final String locale,
      final bool isPublished,
      final int sortOrder,
      final int totalSessions,
      final List<Plan> sessions,
      final String? categoryId,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$SeriesImpl;
  const _Series._() : super._();

  factory _Series.fromJson(Map<String, dynamic> json) = _$SeriesImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String get category;
  @override
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags;
  @override
  String get defaultVoice;
  @override
  String get locale;
  @override
  bool get isPublished;
  @override
  int get sortOrder;

  /// Cached count of plans pointing to this series. Source of truth for
  /// "{N} days" labels in the UI.
  @override
  int get totalSessions;

  /// Sessions in canonical Day-1-to-Day-N order. Empty when fetched from
  /// the list endpoint; populated by `GET /api/series/:id`.
  @override
  List<Plan> get sessions;

  /// Category ID for this series.
  /// Associates the series with a category for hierarchical organization.
  @override
  String? get categoryId;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Series
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SeriesImplCopyWith<_$SeriesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
