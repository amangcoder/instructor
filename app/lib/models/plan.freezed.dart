// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Plan _$PlanFromJson(Map<String, dynamic> json) {
  return _Plan.fromJson(json);
}

/// @nodoc
mixin _$Plan {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  PlanCategory get category => throw _privateConstructorUsedError;
  List<String> get tags => throw _privateConstructorUsedError;
  String get defaultVoice => throw _privateConstructorUsedError;
  List<PlanStep> get steps => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  /// Whether this plan was created by the user.
  ///
  /// Seeded starter plans have [isUserCreated]=false; every plan created
  /// through the editor defaults to true.
  bool get isUserCreated => throw _privateConstructorUsedError;

  /// Serializes this Plan to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanCopyWith<Plan> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanCopyWith<$Res> {
  factory $PlanCopyWith(Plan value, $Res Function(Plan) then) =
      _$PlanCopyWithImpl<$Res, Plan>;
  @useResult
  $Res call(
      {int id,
      String name,
      String? description,
      PlanCategory category,
      List<String> tags,
      String defaultVoice,
      List<PlanStep> steps,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? lastUsedAt,
      bool isUserCreated});
}

/// @nodoc
class _$PlanCopyWithImpl<$Res, $Val extends Plan>
    implements $PlanCopyWith<$Res> {
  _$PlanCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Plan
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
    Object? steps = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastUsedAt = freezed,
    Object? isUserCreated = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
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
              as PlanCategory,
      tags: null == tags
          ? _value.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      steps: null == steps
          ? _value.steps
          : steps // ignore: cast_nullable_to_non_nullable
              as List<PlanStep>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isUserCreated: null == isUserCreated
          ? _value.isUserCreated
          : isUserCreated // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PlanImplCopyWith<$Res> implements $PlanCopyWith<$Res> {
  factory _$$PlanImplCopyWith(
          _$PlanImpl value, $Res Function(_$PlanImpl) then) =
      __$$PlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String name,
      String? description,
      PlanCategory category,
      List<String> tags,
      String defaultVoice,
      List<PlanStep> steps,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? lastUsedAt,
      bool isUserCreated});
}

/// @nodoc
class __$$PlanImplCopyWithImpl<$Res>
    extends _$PlanCopyWithImpl<$Res, _$PlanImpl>
    implements _$$PlanImplCopyWith<$Res> {
  __$$PlanImplCopyWithImpl(_$PlanImpl _value, $Res Function(_$PlanImpl) _then)
      : super(_value, _then);

  /// Create a copy of Plan
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
    Object? steps = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? lastUsedAt = freezed,
    Object? isUserCreated = null,
  }) {
    return _then(_$PlanImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
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
              as PlanCategory,
      tags: null == tags
          ? _value._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      defaultVoice: null == defaultVoice
          ? _value.defaultVoice
          : defaultVoice // ignore: cast_nullable_to_non_nullable
              as String,
      steps: null == steps
          ? _value._steps
          : steps // ignore: cast_nullable_to_non_nullable
              as List<PlanStep>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      lastUsedAt: freezed == lastUsedAt
          ? _value.lastUsedAt
          : lastUsedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isUserCreated: null == isUserCreated
          ? _value.isUserCreated
          : isUserCreated // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlanImpl extends _Plan {
  const _$PlanImpl(
      {required this.id,
      required this.name,
      this.description,
      this.category = PlanCategory.custom,
      final List<String> tags = const [],
      this.defaultVoice = 'aoede',
      final List<PlanStep> steps = const [],
      required this.createdAt,
      required this.updatedAt,
      this.lastUsedAt,
      this.isUserCreated = true})
      : assert(defaultVoice != '', 'defaultVoice must not be empty'),
        _tags = tags,
        _steps = steps,
        super._();

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final String? description;
  @override
  @JsonKey()
  final PlanCategory category;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey()
  final String defaultVoice;
  final List<PlanStep> _steps;
  @override
  @JsonKey()
  List<PlanStep> get steps {
    if (_steps is EqualUnmodifiableListView) return _steps;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_steps);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? lastUsedAt;

  /// Whether this plan was created by the user.
  ///
  /// Seeded starter plans have [isUserCreated]=false; every plan created
  /// through the editor defaults to true.
  @override
  @JsonKey()
  final bool isUserCreated;

  @override
  String toString() {
    return 'Plan(id: $id, name: $name, description: $description, category: $category, tags: $tags, defaultVoice: $defaultVoice, steps: $steps, createdAt: $createdAt, updatedAt: $updatedAt, lastUsedAt: $lastUsedAt, isUserCreated: $isUserCreated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.defaultVoice, defaultVoice) ||
                other.defaultVoice == defaultVoice) &&
            const DeepCollectionEquality().equals(other._steps, _steps) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.lastUsedAt, lastUsedAt) ||
                other.lastUsedAt == lastUsedAt) &&
            (identical(other.isUserCreated, isUserCreated) ||
                other.isUserCreated == isUserCreated));
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
      const DeepCollectionEquality().hash(_steps),
      createdAt,
      updatedAt,
      lastUsedAt,
      isUserCreated);

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      __$$PlanImplCopyWithImpl<_$PlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PlanImplToJson(
      this,
    );
  }
}

abstract class _Plan extends Plan {
  const factory _Plan(
      {required final int id,
      required final String name,
      final String? description,
      final PlanCategory category,
      final List<String> tags,
      final String defaultVoice,
      final List<PlanStep> steps,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final DateTime? lastUsedAt,
      final bool isUserCreated}) = _$PlanImpl;
  const _Plan._() : super._();

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  String? get description;
  @override
  PlanCategory get category;
  @override
  List<String> get tags;
  @override
  String get defaultVoice;
  @override
  List<PlanStep> get steps;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get lastUsedAt;

  /// Whether this plan was created by the user.
  ///
  /// Seeded starter plans have [isUserCreated]=false; every plan created
  /// through the editor defaults to true.
  @override
  bool get isUserCreated;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
