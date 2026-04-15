// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shared_plan_preview.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SharedPlanPreview _$SharedPlanPreviewFromJson(Map<String, dynamic> json) {
  return _SharedPlanPreview.fromJson(json);
}

/// @nodoc
mixin _$SharedPlanPreview {
  /// Human-readable plan name.
  String get name => throw _privateConstructorUsedError;

  /// Optional plan description provided by the creator.
  String? get description => throw _privateConstructorUsedError;

  /// Raw step data for the preview — each element is a map with at least
  /// `name` (String) and `estimatedDurationMs` (int) keys.
  List<dynamic> get steps => throw _privateConstructorUsedError;

  /// Total number of top-level steps in the plan.
  int get stepCount => throw _privateConstructorUsedError;

  /// Sum of all step estimated durations in milliseconds.
  int get estimatedDurationMs => throw _privateConstructorUsedError;

  /// Serializes this SharedPlanPreview to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SharedPlanPreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SharedPlanPreviewCopyWith<SharedPlanPreview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SharedPlanPreviewCopyWith<$Res> {
  factory $SharedPlanPreviewCopyWith(
          SharedPlanPreview value, $Res Function(SharedPlanPreview) then) =
      _$SharedPlanPreviewCopyWithImpl<$Res, SharedPlanPreview>;
  @useResult
  $Res call(
      {String name,
      String? description,
      List<dynamic> steps,
      int stepCount,
      int estimatedDurationMs});
}

/// @nodoc
class _$SharedPlanPreviewCopyWithImpl<$Res, $Val extends SharedPlanPreview>
    implements $SharedPlanPreviewCopyWith<$Res> {
  _$SharedPlanPreviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SharedPlanPreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = freezed,
    Object? steps = null,
    Object? stepCount = null,
    Object? estimatedDurationMs = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      steps: null == steps
          ? _value.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      stepCount: null == stepCount
          ? _value.stepCount
          : stepCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedDurationMs: null == estimatedDurationMs
          ? _value.estimatedDurationMs
          : estimatedDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SharedPlanPreviewImplCopyWith<$Res>
    implements $SharedPlanPreviewCopyWith<$Res> {
  factory _$$SharedPlanPreviewImplCopyWith(_$SharedPlanPreviewImpl value,
          $Res Function(_$SharedPlanPreviewImpl) then) =
      __$$SharedPlanPreviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String? description,
      List<dynamic> steps,
      int stepCount,
      int estimatedDurationMs});
}

/// @nodoc
class __$$SharedPlanPreviewImplCopyWithImpl<$Res>
    extends _$SharedPlanPreviewCopyWithImpl<$Res, _$SharedPlanPreviewImpl>
    implements _$$SharedPlanPreviewImplCopyWith<$Res> {
  __$$SharedPlanPreviewImplCopyWithImpl(_$SharedPlanPreviewImpl _value,
      $Res Function(_$SharedPlanPreviewImpl) _then)
      : super(_value, _then);

  /// Create a copy of SharedPlanPreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = freezed,
    Object? steps = null,
    Object? stepCount = null,
    Object? estimatedDurationMs = null,
  }) {
    return _then(_$SharedPlanPreviewImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      steps: null == steps
          ? _value._steps
          : steps // ignore: cast_nullable_to_non_nullable
              as List<dynamic>,
      stepCount: null == stepCount
          ? _value.stepCount
          : stepCount // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedDurationMs: null == estimatedDurationMs
          ? _value.estimatedDurationMs
          : estimatedDurationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SharedPlanPreviewImpl extends _SharedPlanPreview {
  const _$SharedPlanPreviewImpl(
      {required this.name,
      this.description,
      final List<dynamic> steps = const [],
      required this.stepCount,
      required this.estimatedDurationMs})
      : _steps = steps,
        super._();

  factory _$SharedPlanPreviewImpl.fromJson(Map<String, dynamic> json) =>
      _$$SharedPlanPreviewImplFromJson(json);

  /// Human-readable plan name.
  @override
  final String name;

  /// Optional plan description provided by the creator.
  @override
  final String? description;

  /// Raw step data for the preview — each element is a map with at least
  /// `name` (String) and `estimatedDurationMs` (int) keys.
  final List<dynamic> _steps;

  /// Raw step data for the preview — each element is a map with at least
  /// `name` (String) and `estimatedDurationMs` (int) keys.
  @override
  @JsonKey()
  List<dynamic> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  /// Total number of top-level steps in the plan.
  @override
  final int stepCount;

  /// Sum of all step estimated durations in milliseconds.
  @override
  final int estimatedDurationMs;

  @override
  String toString() {
    return 'SharedPlanPreview(name: $name, description: $description, steps: $steps, stepCount: $stepCount, estimatedDurationMs: $estimatedDurationMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SharedPlanPreviewImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._steps, _steps) &&
            (identical(other.stepCount, stepCount) ||
                other.stepCount == stepCount) &&
            (identical(other.estimatedDurationMs, estimatedDurationMs) ||
                other.estimatedDurationMs == estimatedDurationMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      const DeepCollectionEquality().hash(_steps),
      stepCount,
      estimatedDurationMs);

  /// Create a copy of SharedPlanPreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SharedPlanPreviewImplCopyWith<_$SharedPlanPreviewImpl> get copyWith =>
      __$$SharedPlanPreviewImplCopyWithImpl<_$SharedPlanPreviewImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SharedPlanPreviewImplToJson(
      this,
    );
  }
}

abstract class _SharedPlanPreview extends SharedPlanPreview {
  const factory _SharedPlanPreview(
      {required final String name,
      final String? description,
      final List<dynamic> steps,
      required final int stepCount,
      required final int estimatedDurationMs}) = _$SharedPlanPreviewImpl;
  const _SharedPlanPreview._() : super._();

  factory _SharedPlanPreview.fromJson(Map<String, dynamic> json) =
      _$SharedPlanPreviewImpl.fromJson;

  /// Human-readable plan name.
  @override
  String get name;

  /// Optional plan description provided by the creator.
  @override
  String? get description;

  /// Raw step data for the preview — each element is a map with at least
  /// `name` (String) and `estimatedDurationMs` (int) keys.
  @override
  List<dynamic> get steps;

  /// Total number of top-level steps in the plan.
  @override
  int get stepCount;

  /// Sum of all step estimated durations in milliseconds.
  @override
  int get estimatedDurationMs;

  /// Create a copy of SharedPlanPreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SharedPlanPreviewImplCopyWith<_$SharedPlanPreviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
