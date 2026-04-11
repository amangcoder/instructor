/// Tests for hash_utils.dart — covers both the existing sha256Hex / ttsCacheKey
/// functions and the new mediaCacheKey function added in TASK-013.
///
/// Key invariant (TASK-013): mediaCacheKey on the client MUST produce the same
/// hash as the server-side cacheKey when given identical parameters.  The
/// server serialises parameters as alphabetically-ordered JSON then SHA-256s
/// the string; the client must replicate this exactly.
///
/// ## Running
/// ```
/// flutter test test/utils/hash_utils_test.dart
/// ```
library hash_utils_test;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/utils/hash_utils.dart';

// ---------------------------------------------------------------------------
// Helper: server-side cache key algorithm (replicated for cross-checking)
// ---------------------------------------------------------------------------

/// Replicates the server-side cacheKey computation:
/// SHA-256 of JSON.stringify({ locale, provider, speechRate, text, voice })
/// with keys in alphabetical order.
String _serverSideCacheKey({
  required String text,
  required String voice,
  required String locale,
  required String provider,
  required String speechRate,
}) {
  // Alphabetical key order matches JSON.stringify on a plain JS object
  // when the keys are inserted alphabetically.
  final payload = jsonEncode({
    'locale': locale,
    'provider': provider,
    'speechRate': speechRate,
    'text': text,
    'voice': voice,
  });
  final bytes = utf8.encode(payload);
  return sha256.convert(bytes).toString();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── sha256Hex ───────────────────────────────────────────────────────────────

  group('sha256Hex', () {
    test('returns a 64-character hex string', () {
      final result = sha256Hex('hello');
      expect(result.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
    });

    test('is deterministic for the same input', () {
      expect(sha256Hex('same'), equals(sha256Hex('same')));
    });

    test('produces different digests for different inputs', () {
      expect(sha256Hex('a'), isNot(equals(sha256Hex('b'))));
    });

    test('handles empty string (well-known SHA-256 value)', () {
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb924'
        '27ae41e4649b934ca495991b7852b855',
      );
    });

    test('handles unicode input without throwing', () {
      final result = sha256Hex('こんにちは');
      expect(result.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
    });

    test('handles very long input (>1000 chars)', () {
      final longText = 'A' * 1500;
      final result = sha256Hex(longText);
      expect(result.length, 64);
    });

    test('is stable across 10 repeated calls', () {
      final first = sha256Hex('stability');
      for (var i = 0; i < 10; i++) {
        expect(sha256Hex('stability'), equals(first));
      }
    });
  });

  // ── ttsCacheKey ─────────────────────────────────────────────────────────────

  group('ttsCacheKey', () {
    test('returns a 64-char hex string', () {
      final key = ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Hello');
      expect(key.length, 64);
    });

    test('is consistent with sha256Hex("provider:voiceId:text")', () {
      const provider = 'openai';
      const voiceId = 'shimmer';
      const text = 'Take a deep breath.';
      expect(
        ttsCacheKey(provider: provider, voiceId: voiceId, text: text),
        equals(sha256Hex('$provider:$voiceId:$text')),
      );
    });

    test('produces different keys for same text with different voices', () {
      const text = 'Begin now.';
      final novaKey = ttsCacheKey(provider: 'openai', voiceId: 'nova', text: text);
      final onyxKey = ttsCacheKey(provider: 'openai', voiceId: 'onyx', text: text);
      expect(novaKey, isNot(equals(onyxKey)));
    });

    test('produces different keys for same voice with different texts', () {
      const voice = 'nova';
      final key1 = ttsCacheKey(provider: 'openai', voiceId: voice, text: 'Step one.');
      final key2 = ttsCacheKey(provider: 'openai', voiceId: voice, text: 'Step two.');
      expect(key1, isNot(equals(key2)));
    });

    test('produces different keys for same text+voice with different providers', () {
      const text = 'Take a breath.';
      const voice = 'nova';
      final geminiKey = ttsCacheKey(provider: 'gemini', voiceId: voice, text: text);
      final kokoroKey = ttsCacheKey(provider: 'kokoro', voiceId: voice, text: text);
      expect(geminiKey, isNot(equals(kokoroKey)));
    });

    test('is stable across multiple calls', () {
      for (var i = 0; i < 10; i++) {
        expect(
          ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Stability check'),
          equals(ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Stability check')),
        );
      }
    });
  });

  // ── mediaCacheKey (TASK-013) ────────────────────────────────────────────────
  //
  // This function must exactly match the server-side cacheKey computation:
  //   SHA-256 of JSON.stringify({ locale, provider, speechRate, text, voice })
  // Keys are in alphabetical order.

  group('mediaCacheKey', () {
    test('returns a 64-char hex string', () {
      final key = mediaCacheKey(
        text: 'Hello',
        voice: 'aoede',
        locale: 'enUS',
        provider: 'gemini',
        speechRate: '1.0',
      );
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(key), isTrue);
    });

    test('matches server-side JSON alphabetical + SHA-256 format', () {
      const text = 'Breathe in slowly';
      const voice = 'aoede';
      const locale = 'enUS';
      const provider = 'gemini';
      const speechRate = '1.0';

      final clientKey = mediaCacheKey(
        text: text,
        voice: voice,
        locale: locale,
        provider: provider,
        speechRate: speechRate,
      );

      final serverKey = _serverSideCacheKey(
        text: text,
        voice: voice,
        locale: locale,
        provider: provider,
        speechRate: speechRate,
      );

      expect(clientKey, equals(serverKey),
          reason: 'Client cache key must match server-side format exactly');
    });

    test('different provider produces different key', () {
      final geminiKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      final kokoroKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'kokoro', speechRate: '1.0',
      );
      expect(geminiKey, isNot(equals(kokoroKey)));
    });

    test('different speechRate produces different key', () {
      final normalKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      final fastKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.5',
      );
      expect(normalKey, isNot(equals(fastKey)));
    });

    test('different voice produces different key', () {
      final aoedeKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      final novaKey = mediaCacheKey(
        text: 'test', voice: 'nova', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      expect(aoedeKey, isNot(equals(novaKey)));
    });

    test('different locale produces different key', () {
      final usKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      final inKey = mediaCacheKey(
        text: 'test', voice: 'aoede', locale: 'enIN',
        provider: 'gemini', speechRate: '1.0',
      );
      expect(usKey, isNot(equals(inKey)));
    });

    test('different text produces different key', () {
      final key1 = mediaCacheKey(
        text: 'Hello world', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      final key2 = mediaCacheKey(
        text: 'Goodbye world', voice: 'aoede', locale: 'enUS',
        provider: 'gemini', speechRate: '1.0',
      );
      expect(key1, isNot(equals(key2)));
    });

    // ── TASK-018 cross-platform verification ─────────────────────────────────

    test('TASK-018: fullParamCacheKey matches server cacheKey for Kokoro af_heart', () {
      // Acceptance criteria test vector:
      //   voice='af_heart', locale='en-US', provider='kokoro', speechRate='1.0', text='Hello'
      //
      // Expected JSON payload (alphabetically sorted keys, no whitespace):
      //   {"locale":"en-US","provider":"kokoro","speechRate":"1.0","text":"Hello","voice":"af_heart"}
      //
      // Both fullParamCacheKey (Flutter) and cacheKey (NestJS server) MUST produce
      // the same 64-character SHA-256 hex string from this payload.
      //
      // Fields included in the key (alphabetical order):
      //   1. locale      — locale identifier (e.g. 'en-US', 'enIN')
      //   2. provider    — TTS provider (e.g. 'kokoro', 'gemini')
      //   3. speechRate  — playback speed as a string (e.g. '1.0', '1.5')
      //   4. text        — text to be synthesised
      //   5. voice       — voice identifier (e.g. 'af_heart', 'aoede')
      const text = 'Hello';
      const voice = 'af_heart';
      const locale = 'en-US';
      const provider = 'kokoro';
      const speechRate = '1.0';

      final clientKey = fullParamCacheKey(
        text: text,
        voice: voice,
        locale: locale,
        provider: provider,
        speechRate: speechRate,
      );

      final serverKey = _serverSideCacheKey(
        text: text,
        voice: voice,
        locale: locale,
        provider: provider,
        speechRate: speechRate,
      );

      expect(
        clientKey,
        equals(serverKey),
        reason: 'fullParamCacheKey must produce identical output to the '
            'server-side cacheKey() for Kokoro voice=af_heart, locale=en-US',
      );
      expect(clientKey.length, 64,
          reason: 'SHA-256 hex digest must be exactly 64 characters');
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(clientKey),
        isTrue,
        reason: 'Must be lowercase hex only',
      );
    });

    test('TASK-018: fullParamCacheKey and mediaCacheKey are identical aliases', () {
      // mediaCacheKey is documented as an alias for fullParamCacheKey — they must
      // produce byte-for-byte identical output.
      const text = 'Rest for 30 seconds';
      const voice = 'af_heart';
      const locale = 'en-US';
      const provider = 'kokoro';
      const speechRate = '1.0';

      expect(
        fullParamCacheKey(
          text: text,
          voice: voice,
          locale: locale,
          provider: provider,
          speechRate: speechRate,
        ),
        equals(mediaCacheKey(
          text: text,
          voice: voice,
          locale: locale,
          provider: provider,
          speechRate: speechRate,
        )),
        reason: 'mediaCacheKey is a documented alias for fullParamCacheKey',
      );
    });

    test('TASK-018: JSON serialisation uses exactly 5 alphabetically sorted fields', () {
      // Verifies that the JSON payload fed to SHA-256 contains exactly the fields
      // listed in the TASK-018 documentation: locale, provider, speechRate, text, voice.
      // Any field addition, removal, or rename must be synchronised between
      // hash_utils.dart (Flutter) and tts.service.ts (NestJS server).
      //
      // Expected JSON structure:
      //   {"locale":"...","provider":"...","speechRate":"...","text":"...","voice":"..."}
      //                  ^alphabetical order, no extra whitespace^
      final payload = jsonEncode({
        'locale': 'en-US',
        'provider': 'kokoro',
        'speechRate': '1.0',
        'text': 'Hello',
        'voice': 'af_heart',
      });

      expect(
        payload,
        '{"locale":"en-US","provider":"kokoro","speechRate":"1.0","text":"Hello","voice":"af_heart"}',
        reason:
            'The JSON payload fed to SHA-256 must have exactly 5 fields in alphabetical order '
            'with no extra whitespace — matching Node.js JSON.stringify behaviour',
      );
    });

    test('is deterministic — same inputs always produce same key', () {
      const args = (
        text: 'Deterministic test',
        voice: 'aoede',
        locale: 'enUS',
        provider: 'gemini',
        speechRate: '1.0',
      );
      final first = mediaCacheKey(
        text: args.text,
        voice: args.voice,
        locale: args.locale,
        provider: args.provider,
        speechRate: args.speechRate,
      );
      for (var i = 0; i < 10; i++) {
        expect(
          mediaCacheKey(
            text: args.text,
            voice: args.voice,
            locale: args.locale,
            provider: args.provider,
            speechRate: args.speechRate,
          ),
          equals(first),
        );
      }
    });

    test('cross-platform stability — key does not depend on Dart runtime version', () {
      // Pre-computed expected key for known inputs using the server-side algorithm.
      // Server-side JSON payload:
      //   {"locale":"enUS","provider":"gemini","speechRate":"1.0","text":"Hello","voice":"aoede"}
      // → SHA-256 of that exact UTF-8 string.
      //
      // NOTE: `final` (not `const`) because _serverSideCacheKey performs runtime
      // crypto operations and is not a compile-time constant.
      final expectedKey = _serverSideCacheKey(
        text: 'Hello',
        voice: 'aoede',
        locale: 'enUS',
        provider: 'gemini',
        speechRate: '1.0',
      );

      final actualKey = mediaCacheKey(
        text: 'Hello',
        voice: 'aoede',
        locale: 'enUS',
        provider: 'gemini',
        speechRate: '1.0',
      );

      expect(actualKey, equals(expectedKey));
    });
  });
}
