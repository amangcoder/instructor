/// ProviderCatalogManager — fetches, caches, and serves TTS provider catalogs.
///
/// ## Caching strategy
///
/// 1. On app launch (after auth), [fetchAndCacheCatalog] is called in the
///    background. It fetches GET /api/tts/providers, stores the result in the
///    Drift [ProviderCatalogTable] with a [fetchedAt] timestamp.
/// 2. On subsequent launches within 24 hours, [getCachedCatalog] returns the
///    SQLite-cached catalog without a network request.
/// 3. If the device is offline and no cache exists, the static bundled
///    [kStaticVoiceCatalog] is used as an offline fallback.
library provider_catalog_manager;

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/assets/static_voice_catalog.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/provider_catalog_table.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/services/app_settings.dart' show kBackendUrl;

part 'provider_catalog_manager.g.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Local SQLite cache TTL: 24 hours.
const Duration kProviderCatalogLocalTtl = Duration(hours: 24);

/// HTTP timeout for fetching the catalog from the server.
const Duration kProviderCatalogFetchTimeout = Duration(seconds: 15);

// ── Service ───────────────────────────────────────────────────────────────────

/// Fetches, caches, and serves TTS provider catalogs.
///
/// Backed by the Drift [ProviderCatalogTable] for local persistence and
/// [kStaticVoiceCatalog] for offline fallback.
class ProviderCatalogManager {
  ProviderCatalogManager({
    required AppDatabase db,
    http.Client? httpClient,
  })  : _db = db,
        _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final http.Client _httpClient;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Fetches the provider catalog from the server and stores it in SQLite.
  ///
  /// This is a non-blocking call — callers should not await it in the UI path.
  /// Errors are caught and logged; on failure the cached or static catalog
  /// continues to be used.
  ///
  /// Returns the freshly fetched catalog on success, or the cached/static
  /// catalog on failure.
  Future<List<TtsProviderConfig>> fetchAndCacheCatalog() async {
    try {
      final uri = Uri.parse('$kBackendUrl/api/tts/providers');
      final response = await _httpClient
          .get(uri)
          .timeout(kProviderCatalogFetchTimeout);

      if (response.statusCode != 200) {
        throw Exception(
            'Provider catalog fetch failed: HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final providers = TtsProvidersResponse.fromJson(json).providers;

      // Persist to SQLite (single row, INSERT OR REPLACE on id = 1).
      await _db.into(_db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: response.body,
              fetchedAt: DateTime.now().toUtc(),
            ),
          );

      debugPrint(
        'ProviderCatalogManager: catalog fetched and cached '
        '(${providers.length} providers)',
      );
      return providers;
    } catch (e) {
      debugPrint('ProviderCatalogManager: fetch failed — $e');
      return getCachedCatalog();
    }
  }

  /// Returns the provider catalog from SQLite cache, or the static fallback.
  ///
  /// If the cache is older than [kProviderCatalogLocalTtl] (24h) AND the
  /// device has connectivity, [fetchAndCacheCatalog] is triggered in the
  /// background (fire-and-forget). The stale cached catalog is still returned
  /// immediately to avoid blocking the caller.
  ///
  /// Falls back to [kStaticVoiceCatalog] when the SQLite cache is empty.
  Future<List<TtsProviderConfig>> getCachedCatalog() async {
    final row = await (_db.select(_db.providerCatalogTable)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();

    if (row == null) {
      debugPrint(
        'ProviderCatalogManager: no cache — using static fallback',
      );
      return kStaticVoiceCatalog;
    }

    // Check TTL.
    final age = DateTime.now().toUtc().difference(row.fetchedAt);
    if (age > kProviderCatalogLocalTtl) {
      debugPrint(
        'ProviderCatalogManager: cache stale (${age.inHours}h) — '
        'triggering background refresh',
      );
      // Fire-and-forget background refresh; return stale cache immediately.
      unawaited(fetchAndCacheCatalog());
    }

    try {
      final json = jsonDecode(row.catalogJson) as Map<String, dynamic>;
      return TtsProvidersResponse.fromJson(json).providers;
    } catch (e) {
      debugPrint(
        'ProviderCatalogManager: cache parse error — using static fallback: $e',
      );
      return kStaticVoiceCatalog;
    }
  }

  /// Returns only the voices available for [providerId] from the cached catalog.
  ///
  /// Used by the voice picker to show provider-filtered voice lists.
  Future<List<TtsVoiceOption>> getVoicesForProvider(String providerId) async {
    final catalog = await getCachedCatalog();
    final provider = catalog.where((p) => p.id == providerId).firstOrNull;
    return provider?.voices ?? [];
  }

  /// Returns true if [voiceId] exists in [providerId]'s voice list.
  ///
  /// Used by pre-synthesis validation to detect stale voice IDs.
  Future<bool> isVoiceValidForProvider(
    String voiceId,
    String providerId,
  ) async {
    final voices = await getVoicesForProvider(providerId);
    return voices.any((v) => v.id == voiceId);
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

/// Singleton [ProviderCatalogManager] provider.
///
/// Kept alive for the app's lifetime so catalog data is always available
/// without re-reading SQLite on every access.
@Riverpod(keepAlive: true)
ProviderCatalogManager providerCatalogManager(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ProviderCatalogManager(db: db);
}
