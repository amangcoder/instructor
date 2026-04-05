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

/// Computes the TTS cache key for a given [voiceId] and [text] pair.
///
/// The key is the SHA-256 hex digest of `"$voiceId:$text"`, matching the
/// column comment on [TtsCacheTable.textHash]:
/// > SHA-256 hash of (voiceId + ":" + text) — used as the deduplication key.
///
/// Identical text across multiple Plans that use the same voice will share
/// a single cached audio file.
String ttsCacheKey({required String voiceId, required String text}) {
  return sha256Hex('$voiceId:$text');
}
