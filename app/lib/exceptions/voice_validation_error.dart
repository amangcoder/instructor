/// Exception thrown when a voice ID is not valid for the current TTS provider.
///
/// Thrown by [TTSServiceImpl.synthesize] and caught by [PlanExecutionEngine]
/// or the plan editor to show a voice selection dialog.
class VoiceValidationError implements Exception {
  const VoiceValidationError({
    required this.voiceId,
    required this.providerId,
    required this.providerName,
  });

  /// The invalid voice ID that was requested.
  final String voiceId;

  /// The provider that doesn't support this voice.
  final String providerId;

  /// Human-readable provider name.
  final String providerName;

  @override
  String toString() =>
      'VoiceValidationError: voice "$voiceId" is not available '
      'in provider "$providerName" ($providerId)';
}
