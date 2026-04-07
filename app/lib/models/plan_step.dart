import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:instructor/models/enums.dart';

part 'plan_step.freezed.dart';
part 'plan_step.g.dart';

/// Sealed hierarchy of Plan step types.
///
/// Each concrete subclass maps to a [StepType] enum value and carries the
/// data needed by [PlanExecutionEngine] to perform the step.
///
/// Serialised to/from JSON and stored as a JSON column in the Drift Plans
/// table via [StepListConverter].
@freezed
sealed class PlanStep with _$PlanStep {
  const PlanStep._();

  /// A step that speaks [text] aloud using TTS.
  @Assert("voiceId == null || voiceId != ''",
      'voiceId must be null or non-empty')
  const factory PlanStep.say({
    required String id,
    required String text,
    String? voiceId,
    Duration? estimatedDuration,
  }) = SayStep;

  /// A step that fires a local push notification.
  const factory PlanStep.notify({
    required String id,
    required String title,
    required String body,
  }) = NotifyStep;

  /// A step that starts or changes the ambient audio track.
  const factory PlanStep.play({
    required String id,
    required String audioAssetKey,
    @Default(true) bool loop,
    @Default(1.0) double volume,
    int? fadeInMs,
    int? fadeOutMs,
  }) = PlayStep;

  /// A step that waits silently for [duration].
  const factory PlanStep.wait({
    required String id,
    required Duration duration,
  }) = WaitStep;

  /// A step that repeats its [children] [count] times.
  const factory PlanStep.repeat({
    required String id,
    required int count,
    required List<PlanStep> children,
  }) = RepeatStep;

  /// A step that stops all ambient audio.
  const factory PlanStep.stopAudio({
    required String id,
  }) = StopAudioStep;

  /// Deserialise from a JSON map produced by [toJson].
  factory PlanStep.fromJson(Map<String, dynamic> json) =>
      _$PlanStepFromJson(json);

  /// Returns the [StepType] discriminator for this step.
  StepType get type => switch (this) {
        SayStep() => StepType.say,
        NotifyStep() => StepType.notify,
        PlayStep() => StepType.play,
        WaitStep() => StepType.wait,
        RepeatStep() => StepType.repeat,
        StopAudioStep() => StepType.stopAudio,
      };

  /// Estimated duration contributed by this step to the Plan's total.
  ///
  /// Only [SayStep] and [WaitStep] have deterministic durations at edit time.
  /// [RepeatStep] accumulates its children's durations multiplied by [count].
  Duration get estimatedStepDuration => switch (this) {
        SayStep(:final estimatedDuration) => estimatedDuration ?? Duration.zero,
        WaitStep(:final duration) => duration,
        RepeatStep(:final count, :final children) =>
          children.fold(Duration.zero, (acc, s) => acc + s.estimatedStepDuration) *
              count,
        _ => Duration.zero,
      };
}
