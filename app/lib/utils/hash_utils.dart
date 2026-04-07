import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Returns the hex-encoded SHA-256 digest of [input].
///
/// Example:
/// ```dart
/// sha256Hex('hello') // → '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
/// ```
String sha256Hex(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

/// Computes the TTS cache key for a given [provider], [voiceId] and [text].
///
/// The key is the SHA-256 hex digest of `"$provider:$voiceId:$text"`.
/// Including the provider ensures switching between OpenAI and Google Cloud
/// re-renders audio instead of serving a stale cached file from the other
/// provider.
///
/// **Legacy key format** — preserved for backward-compatibility cache lookup.
/// Prefer [fullParamCacheKey] / [mediaCacheKey] for new cache entries.
String ttsCacheKey({
  required String provider,
  required String voiceId,
  required String text,
}) {
  return sha256Hex('$provider:$voiceId:$text');
}

/// Computes the full-parameter TTS cache key matching the server-side format.
///
/// ## Key format
/// Parameters are JSON-serialised with alphabetically sorted keys, then the
/// resulting string is SHA-256 hashed. This matches the backend implementation
/// exactly so that client and server cache keys are always identical.
///
/// ```json
/// {"locale":"en-IN","provider":"gemini","speechRate":"1.0","text":"...","voice":"aoede"}
/// ```
///
/// ## Parameters
/// - [text]       — the text to be synthesised
/// - [voice]      — voice identifier (e.g. 'aoede')
/// - [locale]     — locale identifier (e.g. 'en-IN')
/// - [provider]   — TTS provider ('gemini' or 'kokoro')
/// - [speechRate] — playback speed as a string (e.g. '1.0')
String fullParamCacheKey({
  required String text,
  required String voice,
  required String locale,
  required String provider,
  required String speechRate,
}) {
  // Keys must be in alphabetical order to match server-side JSON serialisation.
  final params = <String, String>{
    'locale': locale,
    'provider': provider,
    'speechRate': speechRate,
    'text': text,
    'voice': voice,
  };

  // Use a sorted map to guarantee deterministic key ordering.
  final sortedKeys = params.keys.toList()..sort();
  final sortedMap = {for (final k in sortedKeys) k: params[k]!};
  final jsonString = jsonEncode(sortedMap);
  return sha256Hex(jsonString);
}

/// Alias for [fullParamCacheKey] — matches the naming convention used in tests
/// and corresponds to the server-side `cacheKey()` function.
///
/// Both [mediaCacheKey] and [fullParamCacheKey] produce identical output.
String mediaCacheKey({
  required String text,
  required String voice,
  required String locale,
  required String provider,
  required String speechRate,
}) =>
    fullParamCacheKey(
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    );
