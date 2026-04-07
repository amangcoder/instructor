// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plan_step.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PlanStep _$PlanStepFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'say':
      return SayStep.fromJson(json);
    case 'notify':
      return NotifyStep.fromJson(json);
    case 'play':
      return PlayStep.fromJson(json);
    case 'wait':
      return WaitStep.fromJson(json);
    case 'repeat':
      return RepeatStep.fromJson(json);
    case 'stopAudio':
      return StopAudioStep.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'PlanStep',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$PlanStep {
  String get id => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this PlanStep to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PlanStepCopyWith<PlanStep> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PlanStepCopyWith<$Res> {
  factory $PlanStepCopyWith(PlanStep value, $Res Function(PlanStep) then) =
      _$PlanStepCopyWithImpl<$Res, PlanStep>;
  @useResult
  $Res call({String id});
}

/// @nodoc
class _$PlanStepCopyWithImpl<$Res, $Val extends PlanStep>
    implements $PlanStepCopyWith<$Res> {
  _$PlanStepCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SayStepImplCopyWith<$Res> implements $PlanStepCopyWith<$Res> {
  factory _$$SayStepImplCopyWith(
          _$SayStepImpl value, $Res Function(_$SayStepImpl) then) =
      __$$SayStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id, String text, String? voiceId, Duration? estimatedDuration});
}

/// @nodoc
class __$$SayStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$SayStepImpl>
    implements _$$SayStepImplCopyWith<$Res> {
  __$$SayStepImplCopyWithImpl(
      _$SayStepImpl _value, $Res Function(_$SayStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? voiceId = freezed,
    Object? estimatedDuration = freezed,
  }) {
    return _then(_$SayStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      voiceId: freezed == voiceId
          ? _value.voiceId
          : voiceId // ignore: cast_nullable_to_non_nullable
              as String?,
      estimatedDuration: freezed == estimatedDuration
          ? _value.estimatedDuration
          : estimatedDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SayStepImpl extends SayStep {
  const _$SayStepImpl(
      {required this.id,
      required this.text,
      this.voiceId,
      this.estimatedDuration,
      final String? $type})
      : assert(voiceId == null || voiceId != '',
            'voiceId must be null or non-empty'),
        $type = $type ?? 'say',
        super._();

  factory _$SayStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$SayStepImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final String? voiceId;
  @override
  final Duration? estimatedDuration;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.say(id: $id, text: $text, voiceId: $voiceId, estimatedDuration: $estimatedDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SayStepImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.voiceId, voiceId) || other.voiceId == voiceId) &&
            (identical(other.estimatedDuration, estimatedDuration) ||
                other.estimatedDuration == estimatedDuration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, text, voiceId, estimatedDuration);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SayStepImplCopyWith<_$SayStepImpl> get copyWith =>
      __$$SayStepImplCopyWithImpl<_$SayStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return say(id, text, voiceId, estimatedDuration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return say?.call(id, text, voiceId, estimatedDuration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (say != null) {
      return say(id, text, voiceId, estimatedDuration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return say(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return say?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (say != null) {
      return say(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SayStepImplToJson(
      this,
    );
  }
}

abstract class SayStep extends PlanStep {
  const factory SayStep(
      {required final String id,
      required final String text,
      final String? voiceId,
      final Duration? estimatedDuration}) = _$SayStepImpl;
  const SayStep._() : super._();

  factory SayStep.fromJson(Map<String, dynamic> json) = _$SayStepImpl.fromJson;

  @override
  String get id;
  String get text;
  String? get voiceId;
  Duration? get estimatedDuration;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SayStepImplCopyWith<_$SayStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NotifyStepImplCopyWith<$Res>
    implements $PlanStepCopyWith<$Res> {
  factory _$$NotifyStepImplCopyWith(
          _$NotifyStepImpl value, $Res Function(_$NotifyStepImpl) then) =
      __$$NotifyStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, String title, String body});
}

/// @nodoc
class __$$NotifyStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$NotifyStepImpl>
    implements _$$NotifyStepImplCopyWith<$Res> {
  __$$NotifyStepImplCopyWithImpl(
      _$NotifyStepImpl _value, $Res Function(_$NotifyStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? body = null,
  }) {
    return _then(_$NotifyStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _value.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NotifyStepImpl extends NotifyStep {
  const _$NotifyStepImpl(
      {required this.id,
      required this.title,
      required this.body,
      final String? $type})
      : $type = $type ?? 'notify',
        super._();

  factory _$NotifyStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$NotifyStepImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String body;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.notify(id: $id, title: $title, body: $body)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotifyStepImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, body);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotifyStepImplCopyWith<_$NotifyStepImpl> get copyWith =>
      __$$NotifyStepImplCopyWithImpl<_$NotifyStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return notify(id, title, body);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return notify?.call(id, title, body);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (notify != null) {
      return notify(id, title, body);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return notify(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return notify?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (notify != null) {
      return notify(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$NotifyStepImplToJson(
      this,
    );
  }
}

abstract class NotifyStep extends PlanStep {
  const factory NotifyStep(
      {required final String id,
      required final String title,
      required final String body}) = _$NotifyStepImpl;
  const NotifyStep._() : super._();

  factory NotifyStep.fromJson(Map<String, dynamic> json) =
      _$NotifyStepImpl.fromJson;

  @override
  String get id;
  String get title;
  String get body;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotifyStepImplCopyWith<_$NotifyStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$PlayStepImplCopyWith<$Res>
    implements $PlanStepCopyWith<$Res> {
  factory _$$PlayStepImplCopyWith(
          _$PlayStepImpl value, $Res Function(_$PlayStepImpl) then) =
      __$$PlayStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String audioAssetKey,
      bool loop,
      double volume,
      int? fadeInMs,
      int? fadeOutMs});
}

/// @nodoc
class __$$PlayStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$PlayStepImpl>
    implements _$$PlayStepImplCopyWith<$Res> {
  __$$PlayStepImplCopyWithImpl(
      _$PlayStepImpl _value, $Res Function(_$PlayStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? audioAssetKey = null,
    Object? loop = null,
    Object? volume = null,
    Object? fadeInMs = freezed,
    Object? fadeOutMs = freezed,
  }) {
    return _then(_$PlayStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      audioAssetKey: null == audioAssetKey
          ? _value.audioAssetKey
          : audioAssetKey // ignore: cast_nullable_to_non_nullable
              as String,
      loop: null == loop
          ? _value.loop
          : loop // ignore: cast_nullable_to_non_nullable
              as bool,
      volume: null == volume
          ? _value.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as double,
      fadeInMs: freezed == fadeInMs
          ? _value.fadeInMs
          : fadeInMs // ignore: cast_nullable_to_non_nullable
              as int?,
      fadeOutMs: freezed == fadeOutMs
          ? _value.fadeOutMs
          : fadeOutMs // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PlayStepImpl extends PlayStep {
  const _$PlayStepImpl(
      {required this.id,
      required this.audioAssetKey,
      this.loop = true,
      this.volume = 1.0,
      this.fadeInMs,
      this.fadeOutMs,
      final String? $type})
      : $type = $type ?? 'play',
        super._();

  factory _$PlayStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$PlayStepImplFromJson(json);

  @override
  final String id;
  @override
  final String audioAssetKey;
  @override
  @JsonKey()
  final bool loop;
  @override
  @JsonKey()
  final double volume;
  @override
  final int? fadeInMs;
  @override
  final int? fadeOutMs;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.play(id: $id, audioAssetKey: $audioAssetKey, loop: $loop, volume: $volume, fadeInMs: $fadeInMs, fadeOutMs: $fadeOutMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PlayStepImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.audioAssetKey, audioAssetKey) ||
                other.audioAssetKey == audioAssetKey) &&
            (identical(other.loop, loop) || other.loop == loop) &&
            (identical(other.volume, volume) || other.volume == volume) &&
            (identical(other.fadeInMs, fadeInMs) ||
                other.fadeInMs == fadeInMs) &&
            (identical(other.fadeOutMs, fadeOutMs) ||
                other.fadeOutMs == fadeOutMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, audioAssetKey, loop, volume, fadeInMs, fadeOutMs);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PlayStepImplCopyWith<_$PlayStepImpl> get copyWith =>
      __$$PlayStepImplCopyWithImpl<_$PlayStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return play(id, audioAssetKey, loop, volume, fadeInMs, fadeOutMs);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return play?.call(id, audioAssetKey, loop, volume, fadeInMs, fadeOutMs);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (play != null) {
      return play(id, audioAssetKey, loop, volume, fadeInMs, fadeOutMs);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return play(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return play?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (play != null) {
      return play(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$PlayStepImplToJson(
      this,
    );
  }
}

abstract class PlayStep extends PlanStep {
  const factory PlayStep(
      {required final String id,
      required final String audioAssetKey,
      final bool loop,
      final double volume,
      final int? fadeInMs,
      final int? fadeOutMs}) = _$PlayStepImpl;
  const PlayStep._() : super._();

  factory PlayStep.fromJson(Map<String, dynamic> json) =
      _$PlayStepImpl.fromJson;

  @override
  String get id;
  String get audioAssetKey;
  bool get loop;
  double get volume;
  int? get fadeInMs;
  int? get fadeOutMs;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PlayStepImplCopyWith<_$PlayStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$WaitStepImplCopyWith<$Res>
    implements $PlanStepCopyWith<$Res> {
  factory _$$WaitStepImplCopyWith(
          _$WaitStepImpl value, $Res Function(_$WaitStepImpl) then) =
      __$$WaitStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, Duration duration});
}

/// @nodoc
class __$$WaitStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$WaitStepImpl>
    implements _$$WaitStepImplCopyWith<$Res> {
  __$$WaitStepImplCopyWithImpl(
      _$WaitStepImpl _value, $Res Function(_$WaitStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? duration = null,
  }) {
    return _then(_$WaitStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$WaitStepImpl extends WaitStep {
  const _$WaitStepImpl(
      {required this.id, required this.duration, final String? $type})
      : $type = $type ?? 'wait',
        super._();

  factory _$WaitStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$WaitStepImplFromJson(json);

  @override
  final String id;
  @override
  final Duration duration;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.wait(id: $id, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WaitStepImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, duration);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WaitStepImplCopyWith<_$WaitStepImpl> get copyWith =>
      __$$WaitStepImplCopyWithImpl<_$WaitStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return wait(id, duration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return wait?.call(id, duration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (wait != null) {
      return wait(id, duration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return wait(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return wait?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (wait != null) {
      return wait(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$WaitStepImplToJson(
      this,
    );
  }
}

abstract class WaitStep extends PlanStep {
  const factory WaitStep(
      {required final String id,
      required final Duration duration}) = _$WaitStepImpl;
  const WaitStep._() : super._();

  factory WaitStep.fromJson(Map<String, dynamic> json) =
      _$WaitStepImpl.fromJson;

  @override
  String get id;
  Duration get duration;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WaitStepImplCopyWith<_$WaitStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$RepeatStepImplCopyWith<$Res>
    implements $PlanStepCopyWith<$Res> {
  factory _$$RepeatStepImplCopyWith(
          _$RepeatStepImpl value, $Res Function(_$RepeatStepImpl) then) =
      __$$RepeatStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id, int count, List<PlanStep> children});
}

/// @nodoc
class __$$RepeatStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$RepeatStepImpl>
    implements _$$RepeatStepImplCopyWith<$Res> {
  __$$RepeatStepImplCopyWithImpl(
      _$RepeatStepImpl _value, $Res Function(_$RepeatStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? count = null,
    Object? children = null,
  }) {
    return _then(_$RepeatStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      count: null == count
          ? _value.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      children: null == children
          ? _value._children
          : children // ignore: cast_nullable_to_non_nullable
              as List<PlanStep>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RepeatStepImpl extends RepeatStep {
  const _$RepeatStepImpl(
      {required this.id,
      required this.count,
      required final List<PlanStep> children,
      final String? $type})
      : _children = children,
        $type = $type ?? 'repeat',
        super._();

  factory _$RepeatStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$RepeatStepImplFromJson(json);

  @override
  final String id;
  @override
  final int count;
  final List<PlanStep> _children;
  @override
  List<PlanStep> get children {
    if (_children is EqualUnmodifiableListView) return _children;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_children);
  }

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.repeat(id: $id, count: $count, children: $children)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RepeatStepImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.count, count) || other.count == count) &&
            const DeepCollectionEquality().equals(other._children, _children));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, count, const DeepCollectionEquality().hash(_children));

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RepeatStepImplCopyWith<_$RepeatStepImpl> get copyWith =>
      __$$RepeatStepImplCopyWithImpl<_$RepeatStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return repeat(id, count, children);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return repeat?.call(id, count, children);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (repeat != null) {
      return repeat(id, count, children);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return repeat(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return repeat?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (repeat != null) {
      return repeat(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$RepeatStepImplToJson(
      this,
    );
  }
}

abstract class RepeatStep extends PlanStep {
  const factory RepeatStep(
      {required final String id,
      required final int count,
      required final List<PlanStep> children}) = _$RepeatStepImpl;
  const RepeatStep._() : super._();

  factory RepeatStep.fromJson(Map<String, dynamic> json) =
      _$RepeatStepImpl.fromJson;

  @override
  String get id;
  int get count;
  List<PlanStep> get children;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RepeatStepImplCopyWith<_$RepeatStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$StopAudioStepImplCopyWith<$Res>
    implements $PlanStepCopyWith<$Res> {
  factory _$$StopAudioStepImplCopyWith(
          _$StopAudioStepImpl value, $Res Function(_$StopAudioStepImpl) then) =
      __$$StopAudioStepImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String id});
}

/// @nodoc
class __$$StopAudioStepImplCopyWithImpl<$Res>
    extends _$PlanStepCopyWithImpl<$Res, _$StopAudioStepImpl>
    implements _$$StopAudioStepImplCopyWith<$Res> {
  __$$StopAudioStepImplCopyWithImpl(
      _$StopAudioStepImpl _value, $Res Function(_$StopAudioStepImpl) _then)
      : super(_value, _then);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
  }) {
    return _then(_$StopAudioStepImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$StopAudioStepImpl extends StopAudioStep {
  const _$StopAudioStepImpl({required this.id, final String? $type})
      : $type = $type ?? 'stopAudio',
        super._();

  factory _$StopAudioStepImpl.fromJson(Map<String, dynamic> json) =>
      _$$StopAudioStepImplFromJson(json);

  @override
  final String id;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'PlanStep.stopAudio(id: $id)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StopAudioStepImpl &&
            (identical(other.id, id) || other.id == id));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id);

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StopAudioStepImplCopyWith<_$StopAudioStepImpl> get copyWith =>
      __$$StopAudioStepImplCopyWithImpl<_$StopAudioStepImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)
        say,
    required TResult Function(String id, String title, String body) notify,
    required TResult Function(String id, String audioAssetKey, bool loop,
            double volume, int? fadeInMs, int? fadeOutMs)
        play,
    required TResult Function(String id, Duration duration) wait,
    required TResult Function(String id, int count, List<PlanStep> children)
        repeat,
    required TResult Function(String id) stopAudio,
  }) {
    return stopAudio(id);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult? Function(String id, String title, String body)? notify,
    TResult? Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult? Function(String id, Duration duration)? wait,
    TResult? Function(String id, int count, List<PlanStep> children)? repeat,
    TResult? Function(String id)? stopAudio,
  }) {
    return stopAudio?.call(id);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String id, String text, String? voiceId,
            Duration? estimatedDuration)?
        say,
    TResult Function(String id, String title, String body)? notify,
    TResult Function(String id, String audioAssetKey, bool loop, double volume,
            int? fadeInMs, int? fadeOutMs)?
        play,
    TResult Function(String id, Duration duration)? wait,
    TResult Function(String id, int count, List<PlanStep> children)? repeat,
    TResult Function(String id)? stopAudio,
    required TResult orElse(),
  }) {
    if (stopAudio != null) {
      return stopAudio(id);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SayStep value) say,
    required TResult Function(NotifyStep value) notify,
    required TResult Function(PlayStep value) play,
    required TResult Function(WaitStep value) wait,
    required TResult Function(RepeatStep value) repeat,
    required TResult Function(StopAudioStep value) stopAudio,
  }) {
    return stopAudio(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SayStep value)? say,
    TResult? Function(NotifyStep value)? notify,
    TResult? Function(PlayStep value)? play,
    TResult? Function(WaitStep value)? wait,
    TResult? Function(RepeatStep value)? repeat,
    TResult? Function(StopAudioStep value)? stopAudio,
  }) {
    return stopAudio?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SayStep value)? say,
    TResult Function(NotifyStep value)? notify,
    TResult Function(PlayStep value)? play,
    TResult Function(WaitStep value)? wait,
    TResult Function(RepeatStep value)? repeat,
    TResult Function(StopAudioStep value)? stopAudio,
    required TResult orElse(),
  }) {
    if (stopAudio != null) {
      return stopAudio(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$StopAudioStepImplToJson(
      this,
    );
  }
}

abstract class StopAudioStep extends PlanStep {
  const factory StopAudioStep({required final String id}) = _$StopAudioStepImpl;
  const StopAudioStep._() : super._();

  factory StopAudioStep.fromJson(Map<String, dynamic> json) =
      _$StopAudioStepImpl.fromJson;

  @override
  String get id;

  /// Create a copy of PlanStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StopAudioStepImplCopyWith<_$StopAudioStepImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
