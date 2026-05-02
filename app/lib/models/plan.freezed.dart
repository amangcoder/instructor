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
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
  List<String> get tags => throw _privateConstructorUsedError;
  String get defaultVoice => throw _privateConstructorUsedError;
  List<PlanStep> get steps => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;
  DateTime? get lastUsedAt => throw _privateConstructorUsedError;

  /// Whether this plan currently has an active GenAI TTS generation job.
  bool get isActive => throw _privateConstructorUsedError;

  /// The current TTS generation status for this plan.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  String get ttsStatus => throw _privateConstructorUsedError;

  /// Total number of TTS audio segments to generate for this plan.
  int get ttsTotal => throw _privateConstructorUsedError;

  /// Number of TTS audio segments that have been generated so far.
  int get ttsCompleted => throw _privateConstructorUsedError;

  /// The library plan ID this plan was cloned from, if any.
  ///
  /// Set when the user adds a plan from the Discover tab. Used to prevent
  /// duplicate additions across sessions.
  String? get libraryId => throw _privateConstructorUsedError;

  /// The series this plan belongs to, if any. NULL for standalone plans.
  /// Used to render "{Series Name} · Day N" in the mini player and to
  /// drive series subscription progress on completion.
  String? get seriesId => throw _privateConstructorUsedError;

  /// Parent plan ID for hierarchical sub-plans. NULL for top-level plans.
  /// Used to build the tree of plans under a single parent.
  String? get parentPlanId => throw _privateConstructorUsedError;

  /// Position of this plan within its parent's children list.
  /// Used for ordering sub-plans.
  int get position => throw _privateConstructorUsedError;

  /// Child plans (sub-plans) under this plan.
  /// Empty for leaf plans.
  List<Plan> get children => throw _privateConstructorUsedError;

  /// List of voice synthesis results for this plan.
  /// Each PlanVoice tracks the status of a specific (voice, locale) rendering.
  /// User-visibility requires at least one PlanVoice with status='ready'.
  List<PlanVoice> get voices => throw _privateConstructorUsedError;

  /// Visibility state of this plan.
  /// Values: 'private' (only owner), 'pending_review' (awaiting admin approval),
  /// 'public' (published and discoverable).
  String get visibility => throw _privateConstructorUsedError;

  /// Whether this plan is published and discoverable by other users.
  bool get isPublished => throw _privateConstructorUsedError;

  /// User ID of the plan's author. Present for user-authored plans.
  /// NULL for admin-created or imported plans.
  String? get ownerId => throw _privateConstructorUsedError;

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
      {String id,
      String name,
      String? description,
      String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags,
      String defaultVoice,
      List<PlanStep> steps,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? lastUsedAt,
      bool isActive,
      String ttsStatus,
      int ttsTotal,
      int ttsCompleted,
      String? libraryId,
      String? seriesId,
      String? parentPlanId,
      int position,
      List<Plan> children,
      List<PlanVoice> voices,
      String visibility,
      bool isPublished,
      String? ownerId});
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
    Object? isActive = null,
    Object? ttsStatus = null,
    Object? ttsTotal = null,
    Object? ttsCompleted = null,
    Object? libraryId = freezed,
    Object? seriesId = freezed,
    Object? parentPlanId = freezed,
    Object? position = null,
    Object? children = null,
    Object? voices = null,
    Object? visibility = null,
    Object? isPublished = null,
    Object? ownerId = freezed,
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
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      ttsStatus: null == ttsStatus
          ? _value.ttsStatus
          : ttsStatus // ignore: cast_nullable_to_non_nullable
              as String,
      ttsTotal: null == ttsTotal
          ? _value.ttsTotal
          : ttsTotal // ignore: cast_nullable_to_non_nullable
              as int,
      ttsCompleted: null == ttsCompleted
          ? _value.ttsCompleted
          : ttsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      libraryId: freezed == libraryId
          ? _value.libraryId
          : libraryId // ignore: cast_nullable_to_non_nullable
              as String?,
      seriesId: freezed == seriesId
          ? _value.seriesId
          : seriesId // ignore: cast_nullable_to_non_nullable
              as String?,
      parentPlanId: freezed == parentPlanId
          ? _value.parentPlanId
          : parentPlanId // ignore: cast_nullable_to_non_nullable
              as String?,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      children: null == children
          ? _value.children
          : children // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      voices: null == voices
          ? _value.voices
          : voices // ignore: cast_nullable_to_non_nullable
              as List<PlanVoice>,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
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
      {String id,
      String name,
      String? description,
      String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson) List<String> tags,
      String defaultVoice,
      List<PlanStep> steps,
      DateTime createdAt,
      DateTime updatedAt,
      DateTime? lastUsedAt,
      bool isActive,
      String ttsStatus,
      int ttsTotal,
      int ttsCompleted,
      String? libraryId,
      String? seriesId,
      String? parentPlanId,
      int position,
      List<Plan> children,
      List<PlanVoice> voices,
      String visibility,
      bool isPublished,
      String? ownerId});
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
    Object? isActive = null,
    Object? ttsStatus = null,
    Object? ttsTotal = null,
    Object? ttsCompleted = null,
    Object? libraryId = freezed,
    Object? seriesId = freezed,
    Object? parentPlanId = freezed,
    Object? position = null,
    Object? children = null,
    Object? voices = null,
    Object? visibility = null,
    Object? isPublished = null,
    Object? ownerId = freezed,
  }) {
    return _then(_$PlanImpl(
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
      isActive: null == isActive
          ? _value.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      ttsStatus: null == ttsStatus
          ? _value.ttsStatus
          : ttsStatus // ignore: cast_nullable_to_non_nullable
              as String,
      ttsTotal: null == ttsTotal
          ? _value.ttsTotal
          : ttsTotal // ignore: cast_nullable_to_non_nullable
              as int,
      ttsCompleted: null == ttsCompleted
          ? _value.ttsCompleted
          : ttsCompleted // ignore: cast_nullable_to_non_nullable
              as int,
      libraryId: freezed == libraryId
          ? _value.libraryId
          : libraryId // ignore: cast_nullable_to_non_nullable
              as String?,
      seriesId: freezed == seriesId
          ? _value.seriesId
          : seriesId // ignore: cast_nullable_to_non_nullable
              as String?,
      parentPlanId: freezed == parentPlanId
          ? _value.parentPlanId
          : parentPlanId // ignore: cast_nullable_to_non_nullable
              as String?,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      children: null == children
          ? _value._children
          : children // ignore: cast_nullable_to_non_nullable
              as List<Plan>,
      voices: null == voices
          ? _value._voices
          : voices // ignore: cast_nullable_to_non_nullable
              as List<PlanVoice>,
      visibility: null == visibility
          ? _value.visibility
          : visibility // ignore: cast_nullable_to_non_nullable
              as String,
      isPublished: null == isPublished
          ? _value.isPublished
          : isPublished // ignore: cast_nullable_to_non_nullable
              as bool,
      ownerId: freezed == ownerId
          ? _value.ownerId
          : ownerId // ignore: cast_nullable_to_non_nullable
              as String?,
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
      this.category = 'custom',
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags = const [],
      this.defaultVoice = 'aoede',
      final List<PlanStep> steps = const [],
      required this.createdAt,
      required this.updatedAt,
      this.lastUsedAt,
      this.isActive = false,
      this.ttsStatus = 'none',
      this.ttsTotal = 0,
      this.ttsCompleted = 0,
      this.libraryId,
      this.seriesId,
      this.parentPlanId,
      this.position = 0,
      final List<Plan> children = const [],
      final List<PlanVoice> voices = const [],
      this.visibility = 'public',
      this.isPublished = false,
      this.ownerId})
      : assert(defaultVoice != '', 'defaultVoice must not be empty'),
        _tags = tags,
        _steps = steps,
        _children = children,
        _voices = voices,
        super._();

  factory _$PlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlanImplFromJson(json);

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

  /// Whether this plan currently has an active GenAI TTS generation job.
  @override
  @JsonKey()
  final bool isActive;

  /// The current TTS generation status for this plan.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  @override
  @JsonKey()
  final String ttsStatus;

  /// Total number of TTS audio segments to generate for this plan.
  @override
  @JsonKey()
  final int ttsTotal;

  /// Number of TTS audio segments that have been generated so far.
  @override
  @JsonKey()
  final int ttsCompleted;

  /// The library plan ID this plan was cloned from, if any.
  ///
  /// Set when the user adds a plan from the Discover tab. Used to prevent
  /// duplicate additions across sessions.
  @override
  final String? libraryId;

  /// The series this plan belongs to, if any. NULL for standalone plans.
  /// Used to render "{Series Name} · Day N" in the mini player and to
  /// drive series subscription progress on completion.
  @override
  final String? seriesId;

  /// Parent plan ID for hierarchical sub-plans. NULL for top-level plans.
  /// Used to build the tree of plans under a single parent.
  @override
  final String? parentPlanId;

  /// Position of this plan within its parent's children list.
  /// Used for ordering sub-plans.
  @override
  @JsonKey()
  final int position;

  /// Child plans (sub-plans) under this plan.
  /// Empty for leaf plans.
  final List<Plan> _children;

  /// Child plans (sub-plans) under this plan.
  /// Empty for leaf plans.
  @override
  @JsonKey()
  List<Plan> get children {
    if (_children is EqualUnmodifiableListView) return _children;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_children);
  }

  /// List of voice synthesis results for this plan.
  /// Each PlanVoice tracks the status of a specific (voice, locale) rendering.
  /// User-visibility requires at least one PlanVoice with status='ready'.
  final List<PlanVoice> _voices;

  /// List of voice synthesis results for this plan.
  /// Each PlanVoice tracks the status of a specific (voice, locale) rendering.
  /// User-visibility requires at least one PlanVoice with status='ready'.
  @override
  @JsonKey()
  List<PlanVoice> get voices {
    if (_voices is EqualUnmodifiableListView) return _voices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_voices);
  }

  /// Visibility state of this plan.
  /// Values: 'private' (only owner), 'pending_review' (awaiting admin approval),
  /// 'public' (published and discoverable).
  @override
  @JsonKey()
  final String visibility;

  /// Whether this plan is published and discoverable by other users.
  @override
  @JsonKey()
  final bool isPublished;

  /// User ID of the plan's author. Present for user-authored plans.
  /// NULL for admin-created or imported plans.
  @override
  final String? ownerId;

  @override
  String toString() {
    return 'Plan(id: $id, name: $name, description: $description, category: $category, tags: $tags, defaultVoice: $defaultVoice, steps: $steps, createdAt: $createdAt, updatedAt: $updatedAt, lastUsedAt: $lastUsedAt, isActive: $isActive, ttsStatus: $ttsStatus, ttsTotal: $ttsTotal, ttsCompleted: $ttsCompleted, libraryId: $libraryId, seriesId: $seriesId, parentPlanId: $parentPlanId, position: $position, children: $children, voices: $voices, visibility: $visibility, isPublished: $isPublished, ownerId: $ownerId)';
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
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.ttsStatus, ttsStatus) ||
                other.ttsStatus == ttsStatus) &&
            (identical(other.ttsTotal, ttsTotal) ||
                other.ttsTotal == ttsTotal) &&
            (identical(other.ttsCompleted, ttsCompleted) ||
                other.ttsCompleted == ttsCompleted) &&
            (identical(other.libraryId, libraryId) ||
                other.libraryId == libraryId) &&
            (identical(other.seriesId, seriesId) ||
                other.seriesId == seriesId) &&
            (identical(other.parentPlanId, parentPlanId) ||
                other.parentPlanId == parentPlanId) &&
            (identical(other.position, position) ||
                other.position == position) &&
            const DeepCollectionEquality().equals(other._children, _children) &&
            const DeepCollectionEquality().equals(other._voices, _voices) &&
            (identical(other.visibility, visibility) ||
                other.visibility == visibility) &&
            (identical(other.isPublished, isPublished) ||
                other.isPublished == isPublished) &&
            (identical(other.ownerId, ownerId) || other.ownerId == ownerId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
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
        isActive,
        ttsStatus,
        ttsTotal,
        ttsCompleted,
        libraryId,
        seriesId,
        parentPlanId,
        position,
        const DeepCollectionEquality().hash(_children),
        const DeepCollectionEquality().hash(_voices),
        visibility,
        isPublished,
        ownerId
      ]);

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
      {required final String id,
      required final String name,
      final String? description,
      final String category,
      @JsonKey(fromJson: tagsFromJson, toJson: tagsToJson)
      final List<String> tags,
      final String defaultVoice,
      final List<PlanStep> steps,
      required final DateTime createdAt,
      required final DateTime updatedAt,
      final DateTime? lastUsedAt,
      final bool isActive,
      final String ttsStatus,
      final int ttsTotal,
      final int ttsCompleted,
      final String? libraryId,
      final String? seriesId,
      final String? parentPlanId,
      final int position,
      final List<Plan> children,
      final List<PlanVoice> voices,
      final String visibility,
      final bool isPublished,
      final String? ownerId}) = _$PlanImpl;
  const _Plan._() : super._();

  factory _Plan.fromJson(Map<String, dynamic> json) = _$PlanImpl.fromJson;

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
  List<PlanStep> get steps;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  DateTime? get lastUsedAt;

  /// Whether this plan currently has an active GenAI TTS generation job.
  @override
  bool get isActive;

  /// The current TTS generation status for this plan.
  ///
  /// One of: none | pending | processing | completed | partial | failed.
  @override
  String get ttsStatus;

  /// Total number of TTS audio segments to generate for this plan.
  @override
  int get ttsTotal;

  /// Number of TTS audio segments that have been generated so far.
  @override
  int get ttsCompleted;

  /// The library plan ID this plan was cloned from, if any.
  ///
  /// Set when the user adds a plan from the Discover tab. Used to prevent
  /// duplicate additions across sessions.
  @override
  String? get libraryId;

  /// The series this plan belongs to, if any. NULL for standalone plans.
  /// Used to render "{Series Name} · Day N" in the mini player and to
  /// drive series subscription progress on completion.
  @override
  String? get seriesId;

  /// Parent plan ID for hierarchical sub-plans. NULL for top-level plans.
  /// Used to build the tree of plans under a single parent.
  @override
  String? get parentPlanId;

  /// Position of this plan within its parent's children list.
  /// Used for ordering sub-plans.
  @override
  int get position;

  /// Child plans (sub-plans) under this plan.
  /// Empty for leaf plans.
  @override
  List<Plan> get children;

  /// List of voice synthesis results for this plan.
  /// Each PlanVoice tracks the status of a specific (voice, locale) rendering.
  /// User-visibility requires at least one PlanVoice with status='ready'.
  @override
  List<PlanVoice> get voices;

  /// Visibility state of this plan.
  /// Values: 'private' (only owner), 'pending_review' (awaiting admin approval),
  /// 'public' (published and discoverable).
  @override
  String get visibility;

  /// Whether this plan is published and discoverable by other users.
  @override
  bool get isPublished;

  /// User ID of the plan's author. Present for user-authored plans.
  /// NULL for admin-created or imported plans.
  @override
  String? get ownerId;

  /// Create a copy of Plan
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlanImplCopyWith<_$PlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
