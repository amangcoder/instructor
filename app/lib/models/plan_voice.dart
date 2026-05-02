import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_voice.freezed.dart';
part 'plan_voice.g.dart';

/// A specific voice synthesis result for a plan.
///
/// Represents a single (plan, voice, locale) tuple and tracks the status
/// of TTS synthesis for that combination. User visibility of a plan requires
/// at least one [PlanVoice] with status='ready'.
@freezed
class PlanVoice with _$PlanVoice {
  const PlanVoice._();

  const factory PlanVoice({
    required String id,
    required String planId,
    required String voiceId,
    required String locale,

    /// TTS synthesis status: 'pending' | 'processing' | 'ready' | 'failed'
    required String status,

    /// URL to the synthesized audio file (present when status='ready').
    String? audioUrl,

    /// Duration of the synthesized audio in milliseconds.
    int? durationMs,

    /// Timestamp when the audio was generated (present when status='ready').
    DateTime? generatedAt,
  }) = _PlanVoice;

  factory PlanVoice.fromJson(Map<String, dynamic> json) =>
      _$PlanVoiceFromJson(json);
}
