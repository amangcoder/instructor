/// Unit tests for MediaCacheService (TASK-013).
///
/// Tests cover:
/// 1. Cache key computation (must match server-side format)
/// 2. Cache hit — returns local file without API call
/// 3. Cache miss — calls API, stores result, returns file
/// 4. Full-parameter key (provider + speechRate change the key)
/// 5. saveToCache — persists audio to local filesystem
/// 6. clearCache — removes all cached files
///
/// ## Running
/// ```
/// flutter test test/services/media_cache_service_test.dart
/// ```
library media_cache_service_test;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/services/media_cache_service.dart';
import 'package:instructor/utils/hash_utils.dart';

// ---------------------------------------------------------------------------
// Fake TTS service for triggering API calls
// ---------------------------------------------------------------------------

class _FakeTtsApiClient {
  final List<({String text, String voice, String locale, String provider, String speechRate})> calls = [];
  Uint8List? responseBytes;
  Exception? error;

  Future<Uint8List> synthesize({
    required String text,
    required String voice,
    required String locale,
    required String provider,
    required String speechRate,
  }) async {
    calls.add((
      text: text,
      voice: voice,
      locale: locale,
      provider: provider,
      speechRate: speechRate,
    ));
    if (error != null) throw error!;
    return responseBytes ?? Uint8List.fromList([0x52, 0x49, 0x46, 0x46]); // RIFF header
  }
}

// ---------------------------------------------------------------------------
// Test parameters
// ---------------------------------------------------------------------------

const _kText = 'Take a deep breath';
const _kVoice = 'aoede';
const _kLocale = 'enUS';
const _kProvider = 'gemini';
const _kSpeechRate = '1.0';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;
  late _FakeTtsApiClient fakeApi;
  late MediaCacheService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('media_cache_test_');
    fakeApi = _FakeTtsApiClient();
    fakeApi.responseBytes = Uint8List.fromList(List.generate(64, (i) => i));

    service = MediaCacheService(
      cacheDirectory: tempDir.path,
      apiClient: fakeApi,
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  // ── computeCacheKey ──────────────────────────────────────────────────────────

  group('computeCacheKey', () {
    test('returns a 64-char hex string', () {
      final key = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(key), isTrue);
    });

    test('matches mediaCacheKey from hash_utils', () {
      final serviceKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final utilKey = mediaCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(serviceKey, equals(utilKey));
    });

    test('different provider produces different key', () {
      final geminiKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: 'gemini', speechRate: _kSpeechRate,
      );
      final kokoroKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: 'kokoro', speechRate: _kSpeechRate,
      );
      expect(geminiKey, isNot(equals(kokoroKey)));
    });

    test('different speechRate produces different key', () {
      final normalKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: '1.0',
      );
      final fastKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: '1.5',
      );
      expect(normalKey, isNot(equals(fastKey)));
    });

    test('is deterministic across calls', () {
      final key1 = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final key2 = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(key1, equals(key2));
    });
  });

  // ── getOrFetchAudio ──────────────────────────────────────────────────────────

  group('getOrFetchAudio — cache miss', () {
    test('calls API when no cached file exists', () async {
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(fakeApi.calls, hasLength(1));
    });

    test('passes correct parameters to API', () async {
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final call = fakeApi.calls.first;
      expect(call.text, _kText);
      expect(call.voice, _kVoice);
      expect(call.locale, _kLocale);
      expect(call.provider, _kProvider);
      expect(call.speechRate, _kSpeechRate);
    });

    test('returns a File pointing to the cached audio', () async {
      final file = await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(file, isA<File>());
      expect(await file.exists(), isTrue);
    });

    test('saves audio bytes to the cache file', () async {
      final file = await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final bytes = await file.readAsBytes();
      expect(bytes, equals(fakeApi.responseBytes));
    });

    test('cached file is in the configured cache directory', () async {
      final file = await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(file.path, startsWith(tempDir.path));
    });
  });

  group('getOrFetchAudio — cache hit', () {
    setUp(() async {
      // Pre-populate the cache
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      fakeApi.calls.clear(); // Reset call tracking
    });

    test('does NOT call API on cache hit', () async {
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(fakeApi.calls, isEmpty);
    });

    test('returns the same File for identical parameters', () async {
      final file1 = await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final file2 = await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(file1.path, equals(file2.path));
    });

    test('cache miss after changing provider (different key)', () async {
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: 'kokoro', // different provider
        speechRate: _kSpeechRate,
      );
      expect(fakeApi.calls, hasLength(1)); // Cache miss — should call API
    });

    test('cache miss after changing speechRate', () async {
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider,
        speechRate: '1.5', // different speed
      );
      expect(fakeApi.calls, hasLength(1)); // Cache miss
    });
  });

  // ── saveToCache ──────────────────────────────────────────────────────────────

  group('saveToCache', () {
    test('stores audio bytes as a file in the cache directory', () async {
      final bytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final file = await service.saveToCache(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
        audioBytes: bytes,
      );

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), equals(bytes));
    });

    test('subsequent getOrFetchAudio returns the saved file (no API call)', () async {
      final bytes = Uint8List.fromList(List.generate(100, (i) => i));
      await service.saveToCache(
        text: 'saved text', voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
        audioBytes: bytes,
      );

      final file = await service.getOrFetchAudio(
        text: 'saved text', voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );

      expect(fakeApi.calls, isEmpty); // No API call needed
      expect(await file.readAsBytes(), equals(bytes));
    });

    test('file path uses the cache key as the filename', () async {
      final bytes = Uint8List.fromList([0xFF, 0xFE]);
      final file = await service.saveToCache(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
        audioBytes: bytes,
      );

      final cacheKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(file.path, contains(cacheKey));
    });
  });

  // ── clearCache ───────────────────────────────────────────────────────────────

  group('clearCache', () {
    setUp(() async {
      // Populate cache with multiple files
      for (var i = 0; i < 3; i++) {
        await service.getOrFetchAudio(
          text: 'text $i', voice: _kVoice, locale: _kLocale,
          provider: _kProvider, speechRate: _kSpeechRate,
        );
      }
    });

    test('removes all cached audio files', () async {
      await service.clearCache();
      final files = await tempDir.list().toList();
      expect(files, isEmpty);
    });

    test('subsequent getOrFetchAudio calls API again after clear', () async {
      await service.clearCache();
      fakeApi.calls.clear();

      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      expect(fakeApi.calls, hasLength(1));
    });

    test('clearCache on empty directory does not throw', () async {
      await service.clearCache();
      await expectLater(service.clearCache(), completes);
    });
  });

  // ── Error handling ───────────────────────────────────────────────────────────

  group('error handling', () {
    test('propagates API errors with a descriptive exception', () async {
      fakeApi.error = Exception('API error: 502 Bad Gateway');

      await expectLater(
        service.getOrFetchAudio(
          text: _kText, voice: _kVoice, locale: _kLocale,
          provider: _kProvider, speechRate: _kSpeechRate,
        ),
        throwsA(isA<MediaCacheException>()),
      );
    });

    test('does not create a partial cache file on API error', () async {
      fakeApi.error = Exception('Network failure');
      await service.getOrFetchAudio(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      ).catchError((_) {});

      final cacheKey = service.computeCacheKey(
        text: _kText, voice: _kVoice, locale: _kLocale,
        provider: _kProvider, speechRate: _kSpeechRate,
      );
      final cacheFile = File('${tempDir.path}/$cacheKey.wav');
      expect(await cacheFile.exists(), isFalse,
          reason: 'Partial cache files should be cleaned up on error');
    });
  });
}
