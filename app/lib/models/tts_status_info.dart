import 'package:freezed_annotation/freezed_annotation.dart';

part 'tts_status_info.freezed.dart';
part 'tts_status_info.g.dart';

/// Represents the server-reported TTS generation status for a single plan.
///
/// Returned by GET /api/tts/status/:planId and used by [TtsStatusPollingProvider]
/// to track progress and trigger audio downloads when generation completes.
@freezed
class TtsStatusInfo with _$TtsStatusInfo {
  const TtsStatusInfo._();

  const factory TtsStatusInfo({
    /// The plan ID this status belongs to.
    required String planId,

    /// Current generation status.
    ///
    /// One of: none | pending | processing | completed | partial | failed.
    required String status,

    /// Total number of TTS audio segments to generate.
    required int total,

    /// Number of TTS audio segments generated so far.
    required int completed,
  }) = _TtsStatusInfo;

  factory TtsStatusInfo.fromJson(Map<String, dynamic> json) =>
      _$TtsStatusInfoFromJson(json);

  /// Returns true when TTS generation has fully completed.
  bool get ready => status == 'completed';
}
