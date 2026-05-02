// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_plan_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

LibraryPlanSummary _$LibraryPlanSummaryFromJson(Map<String, dynamic> json) {
  return _LibraryPlanSummary.fromJson(json);
}

/// @nodoc
mixin _$LibraryPlanSummary {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  String get defaultVoice => throw _privateConstructorUsedError;
  String? get locale => throw _privateConstructorUsedError;

  /// Total estimated duration of all steps in seconds.
  int get totalDurationSeconds => throw _privateConstructorUsedError;

  /// Number of steps in the plan.
  int get stepCount => throw _privateConstructorUsedError;
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags => throw _privateConstructorUsedError;

  /// Serializes this LibraryPlanSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of LibraryPlanSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LibraryPlanSummaryCopyWith<LibraryPlanSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LibraryPlanSummaryCopyWith<$Res> {
  factory $LibraryPlanSummaryCopyWith(
          LibraryPlanSummary value, $Res Function(LibraryPlanSummary) then) =
      _$LibraryPlanSummaryCopyWithImpl<$Res, LibraryPlanSummary>;
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String category,
      String defaultVoice,
      String? locale,
      int totalDurationSeconds,
      int stepCount,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags});
}

/// @nodoc
class _$LibraryPlanSummaryCopyWithImpl<$Res, $Val extends LibraryPlanSummary>
    implements $LibraryPlanSummaryCopyWith<$Res> {
  _$LibraryPlanSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LibraryPlanSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = null,
    Object? defaultVoice = null,
    Object? locale = freezed,
    Object? totalDurationSeconds = null,
    Object? stepCount = null,
    Object? tags = null,
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
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      locale: freezed == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
      totalDurationSeconds: null == totalDurationSeconds
          ? _value.totalDurationSeconds
          : totalDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      stepCount: null == stepCount
          ? _value.stepCount
          : stepCount // ignore: cast_nullable_to_non_nullable
              as int,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LibraryPlanSummaryImplCopyWith<$Res>
    implements $LibraryPlanSummaryCopyWith<$Res> {
  factory _$$LibraryPlanSummaryImplCopyWith(_$LibraryPlanSummaryImpl value,
          $Res Function(_$LibraryPlanSummaryImpl) then) =
      __$$LibraryPlanSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String? description,
      String category,
      String defaultVoice,
      String? locale,
      int totalDurationSeconds,
      int stepCount,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags});
}

/// @nodoc
class __$$LibraryPlanSummaryImplCopyWithImpl<$Res>
    extends _$LibraryPlanSummaryCopyWithImpl<$Res, _$LibraryPlanSummaryImpl>
    implements _$$LibraryPlanSummaryImplCopyWith<$Res> {
  __$$LibraryPlanSummaryImplCopyWithImpl(_$LibraryPlanSummaryImpl _value,
      $Res Function(_$LibraryPlanSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of LibraryPlanSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = freezed,
    Object? category = null,
    Object? defaultVoice = null,
    Object? locale = freezed,
    Object? totalDurationSeconds = null,
    Object? stepCount = null,
    Object? tags = null,
  }) {
    return _then(_$LibraryPlanSummaryImpl(
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
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      locale: freezed == locale
          ? _value.locale
          : locale // ignore: cast_nullable_to_non_nullable
              as String?,
      totalDurationSeconds: null == totalDurationSeconds
          ? _value.totalDurationSeconds
          : totalDurationSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      stepCount: null == stepCount
          ? _value.stepCount
          : stepCount // ignore: cast_nullable_to_non_nullable
              as int,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$LibraryPlanSummaryImpl extends _LibraryPlanSummary {
  const _$LibraryPlanSummaryImpl(
      {required this.id,
      required this.name,
      this.description,
      this.category = 'custom',
      this.defaultVoice = 'aoede',
      this.locale,
      this.totalDurationSeconds = 0,
      this.stepCount = 0,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags = const []})
      : _tags = tags,
        super._();

  factory _$LibraryPlanSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$LibraryPlanSummaryImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey()
  final String category;
  @override
  @JsonKey()
  final String defaultVoice;
  @override
  final String? locale;

  /// Total estimated duration of all steps in seconds.
  @override
  @JsonKey()
  final int totalDurationSeconds;

  /// Number of steps in the plan.
  @override
  @JsonKey()
  final int stepCount;
  final List<String> _tags;
  @override
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  String toString() {
    return 'LibraryPlanSummary(id: $id, name: $name, description: $description, category: $category, defaultVoice: $defaultVoice, locale: $locale, totalDurationSeconds: $totalDurationSeconds, stepCount: $stepCount, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LibraryPlanSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.defaultVoice, defaultVoice) ||
                other.defaultVoice == defaultVoice) &&
            (identical(other.locale, locale) || other.locale == locale) &&
            (identical(other.totalDurationSeconds, totalDurationSeconds) ||
                other.totalDurationSeconds == totalDurationSeconds) &&
            (identical(other.stepCount, stepCount) ||
                other.stepCount == stepCount) &&
            const DeepCollectionEquality().equals(other._tags, _tags));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      category,
      defaultVoice,
      locale,
      totalDurationSeconds,
      stepCount,
      const DeepCollectionEquality().hash(_tags));

  /// Create a copy of LibraryPlanSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LibraryPlanSummaryImplCopyWith<_$LibraryPlanSummaryImpl> get copyWith =>
      __$$LibraryPlanSummaryImplCopyWithImpl<_$LibraryPlanSummaryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$LibraryPlanSummaryImplToJson(
      this,
    );
  }
}

abstract class _LibraryPlanSummary extends LibraryPlanSummary {
  const factory _LibraryPlanSummary(
      {required final String id,
      required final String name,
      final String? description,
      final String category,
      final String defaultVoice,
      final String? locale,
      final int totalDurationSeconds,
      final int stepCount,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags}) = _$LibraryPlanSummaryImpl;
  const _LibraryPlanSummary._() : super._();

  factory _LibraryPlanSummary.fromJson(Map<String, dynamic> json) =
      _$LibraryPlanSummaryImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  String get category;
  @override
  String get defaultVoice;
  @override
  String? get locale;

  /// Total estimated duration of all steps in seconds.
  @override
  int get totalDurationSeconds;

  /// Number of steps in the plan.
  @override
  int get stepCount;
  @override
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags;

  /// Create a copy of LibraryPlanSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LibraryPlanSummaryImplCopyWith<_$LibraryPlanSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
