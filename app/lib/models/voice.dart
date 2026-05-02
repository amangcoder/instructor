import 'package:freezed_annotation/freezed_annotation.dart';

part 'voice.freezed.dart';
part 'voice.g.dart';

/// A TTS voice provider configuration.
///
/// Returned by `GET /api/voices` and `GET /api/admin/voices`.
/// Each voice represents a specific (voice_id, locale) combination
/// that can be used to synthesize a plan into audio.
@freezed
class Voice with _$Voice {
  const Voice._();

  const factory Voice({
    required String id,
    required String slug,
    required String displayName,
    required String locale,
    required String provider,
    String? sampleUrl,
    @Default(false) bool isPublished,
  }) = _Voice;

  factory Voice.fromJson(Map<String, dynamic> json) => _$VoiceFromJson(json);
}
