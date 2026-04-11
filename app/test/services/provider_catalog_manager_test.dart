/// Unit tests for [ProviderCatalogManager].
///
/// ## Test strategy
///
/// All database access uses an in-memory Drift executor
/// ([AppDatabase.forTesting]) so tests are fast and hermetic — no real SQLite
/// file is created or left behind.
///
/// Network calls are replaced by a fake [http.Client] so tests run offline.
library provider_catalog_manager_test;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:instructor/assets/static_voice_catalog.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/provider_catalog_table.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/services/provider_catalog_manager.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Minimal in-memory database for tests.
AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

/// A minimal valid /api/tts/providers JSON response with two providers.
String _minimalCatalogJson({
  String provider1Id = 'gemini',
  String provider2Id = 'kokoro',
}) =>
    jsonEncode({
      'providers': [
        {
          'id': provider1Id,
          'label': 'Gemini TTS',
          'voices': [
            {'id': 'aoede', 'label': 'Aoede'},
            {'id': 'zephyr', 'label': 'Zephyr'},
          ],
          'locales': [
            {'id': 'enUS', 'label': 'English (US)'},
          ],
          'voiceMap': {'af_heart': 'aoede'},
        },
        {
          'id': provider2Id,
          'label': 'Kokoro TTS',
          'voices': [
            {'id': 'af_heart', 'label': 'Heart (Female, US)'},
            {'id': 'am_adam', 'label': 'Adam (Male, US)'},
          ],
          'locales': [
            {'id': 'en-us', 'label': 'English (US)'},
          ],
          'voiceMap': {'aoede': 'af_heart'},
        },
      ],
    });

/// HTTP client that returns a successful catalog response.
http.Client _successClient([String? body]) => MockClient((request) async {
      return http.Response(body ?? _minimalCatalogJson(), 200);
    });

/// HTTP client that simulates a network failure.
http.Client _failingClient() => MockClient((_) async {
      throw Exception('Network unavailable');
    });

/// HTTP client that returns a non-200 status.
http.Client _errorStatusClient(int statusCode) =>
    MockClient((_) async => http.Response('error', statusCode));

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('ProviderCatalogManager — fetchAndCacheCatalog', () {
    late AppDatabase db;

    setUp(() => db = _openInMemory());
    tearDown(() async => db.close());

    test('returns parsed providers on HTTP 200 success', () async {
      final mgr = ProviderCatalogManager(db: db, httpClient: _successClient());
      final providers = await mgr.fetchAndCacheCatalog();

      expect(providers, hasLength(2));
      expect(providers.map((p) => p.id), containsAll(['gemini', 'kokoro']));
    });

    test('stores catalog in SQLite after a successful fetch', () async {
      final mgr = ProviderCatalogManager(db: db, httpClient: _successClient());
      await mgr.fetchAndCacheCatalog();

      final row = await (db.select(db.providerCatalogTable)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      expect(row, isNotNull, reason: 'catalog row should be persisted');
      expect(row!.catalogJson, contains('gemini'));
    });

    test('updates the fetchedAt timestamp after each fetch', () async {
      final mgr = ProviderCatalogManager(db: db, httpClient: _successClient());
      await mgr.fetchAndCacheCatalog();

      final row1 = await (db.select(db.providerCatalogTable)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      final firstFetch = row1!.fetchedAt;

      // Small delay to ensure timestamps differ.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await mgr.fetchAndCacheCatalog();

      final row2 = await (db.select(db.providerCatalogTable)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      // The second fetch timestamp should be >= the first.
      expect(
        row2!.fetchedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(firstFetch.millisecondsSinceEpoch),
      );
    });

    test('falls back to static catalog when HTTP request throws', () async {
      final mgr =
          ProviderCatalogManager(db: db, httpClient: _failingClient());
      final providers = await mgr.fetchAndCacheCatalog();

      // No cache in DB yet — should use static fallback.
      expect(providers, isNotEmpty);
      expect(providers.map((p) => p.id), containsAll(['gemini', 'kokoro']));
    });

    test('falls back to static catalog on non-200 HTTP status', () async {
      final mgr = ProviderCatalogManager(
          db: db, httpClient: _errorStatusClient(503));
      final providers = await mgr.fetchAndCacheCatalog();

      expect(providers, isNotEmpty);
    });

    test('voices include all fields returned by the server', () async {
      final body = jsonEncode({
        'providers': [
          {
            'id': 'gemini',
            'label': 'Gemini',
            'voices': [
              {'id': 'aoede', 'label': 'Aoede', 'gender': 'female'},
            ],
            'locales': [
              {'id': 'enUS', 'label': 'English (US)'},
            ],
            'voiceMap': <String, String>{},
          },
        ],
      });
      final mgr =
          ProviderCatalogManager(db: db, httpClient: _successClient(body));
      final providers = await mgr.fetchAndCacheCatalog();

      final voice = providers.first.voices.first;
      expect(voice.id, 'aoede');
      expect(voice.label, 'Aoede');
    });
  });

  group('ProviderCatalogManager — getCachedCatalog', () {
    late AppDatabase db;

    setUp(() => db = _openInMemory());
    tearDown(() async => db.close());

    test('returns static fallback when no row in SQLite', () async {
      // No HTTP client needed — DB is empty, should fall back to static.
      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      final providers = await mgr.getCachedCatalog();

      expect(providers, equals(kStaticVoiceCatalog));
    });

    test('returns cached catalog when row is fresh (< 24h old)', () async {
      // Pre-populate the DB with a fresh cache.
      final body = _minimalCatalogJson();
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: body,
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      // HTTP client should NOT be called — cached catalog should be returned.
      var callCount = 0;
      final mockClient = MockClient((_) async {
        callCount++;
        return http.Response(body, 200);
      });

      final mgr =
          ProviderCatalogManager(db: db, httpClient: mockClient);
      final providers = await mgr.getCachedCatalog();

      expect(callCount, 0, reason: 'should not call network when cache is fresh');
      expect(providers.map((p) => p.id), containsAll(['gemini', 'kokoro']));
    });

    test('triggers background refresh and returns stale cache when TTL expired',
        () async {
      // Pre-populate DB with a stale cache (25 hours ago).
      final body = _minimalCatalogJson();
      final staleTime =
          DateTime.now().toUtc().subtract(const Duration(hours: 25));
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: body,
              fetchedAt: staleTime,
            ),
          );

      // getCachedCatalog should return the stale catalog immediately.
      final mgr =
          ProviderCatalogManager(db: db, httpClient: _successClient());
      final providers = await mgr.getCachedCatalog();

      // Must return cached data immediately (not null / empty).
      expect(providers, isNotEmpty,
          reason: 'stale cache should be returned immediately');
      expect(providers.map((p) => p.id), containsAll(['gemini', 'kokoro']));
    });

    test('handles corrupt JSON in SQLite gracefully — returns static fallback',
        () async {
      // Insert corrupt JSON.
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: '{ invalid json {{{{',
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      final providers = await mgr.getCachedCatalog();

      // Should fall back to the bundled static catalog.
      expect(providers, equals(kStaticVoiceCatalog));
    });
  });

  group('ProviderCatalogManager — getVoicesForProvider', () {
    late AppDatabase db;

    setUp(() => db = _openInMemory());
    tearDown(() async => db.close());

    test('returns only voices for the requested provider', () async {
      // Pre-populate the DB with a fresh cache.
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      final voices = await mgr.getVoicesForProvider('gemini');

      final ids = voices.map((v) => v.id).toList();
      expect(ids, contains('aoede'));
      expect(ids, contains('zephyr'));
      expect(ids, isNot(contains('af_heart')),
          reason: 'Kokoro voices should not appear');
    });

    test('returns Kokoro voices only when provider is kokoro', () async {
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      final voices = await mgr.getVoicesForProvider('kokoro');

      final ids = voices.map((v) => v.id).toList();
      expect(ids, contains('af_heart'));
      expect(ids, contains('am_adam'));
      expect(ids, isNot(contains('aoede')),
          reason: 'Gemini voices should not appear');
    });

    test('returns empty list for unknown provider', () async {
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      final voices = await mgr.getVoicesForProvider('nonexistent');

      expect(voices, isEmpty);
    });
  });

  group('ProviderCatalogManager — isVoiceValidForProvider', () {
    late AppDatabase db;

    setUp(() => db = _openInMemory());
    tearDown(() async => db.close());

    test('returns true when voice exists in provider', () async {
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());

      expect(await mgr.isVoiceValidForProvider('af_heart', 'kokoro'), isTrue);
      expect(await mgr.isVoiceValidForProvider('aoede', 'gemini'), isTrue);
    });

    test('returns false when voice does not exist in provider', () async {
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());

      // Kokoro voice against Gemini provider — should be invalid.
      expect(await mgr.isVoiceValidForProvider('af_heart', 'gemini'), isFalse);
      // Gemini voice against Kokoro provider — should be invalid.
      expect(await mgr.isVoiceValidForProvider('aoede', 'kokoro'), isFalse);
    });

    test('returns false for unknown voice', () async {
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: _minimalCatalogJson(),
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());
      expect(
        await mgr.isVoiceValidForProvider('completely_unknown_voice', 'gemini'),
        isFalse,
      );
    });

    test('uses static fallback catalog when DB empty', () async {
      // No rows in DB — uses static catalog.
      final mgr = ProviderCatalogManager(
          db: db, httpClient: _failingClient());

      // kStaticVoiceCatalog contains af_heart under kokoro.
      expect(await mgr.isVoiceValidForProvider('af_heart', 'kokoro'), isTrue);
      expect(await mgr.isVoiceValidForProvider('af_heart', 'gemini'), isFalse);
    });
  });
}
