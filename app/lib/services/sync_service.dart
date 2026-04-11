/// SyncService — debounced SQLite backup/restore to S3 via pre-signed URLs.
///
/// ## Upload flow
/// 1. WAL checkpoint (flush WAL → main .db file) via Drift [AppDatabase.walCheckpoint].
/// 2. SHA-256 the .db file — skip if hash unchanged since last sync.
/// 3. POST /api/sync/upload → receive a pre-signed S3 PUT URL.
/// 4. PUT the .db bytes directly to S3.
/// 5. Record timestamp + size in [AppSettings].
///
/// ## Restore flow
/// 1. GET /api/sync/download → receive a pre-signed S3 GET URL.
/// 2. Download the .db file.
/// 3. Close the Drift database connection.
/// 4. Delete existing .db/.db-wal/.db-shm files.
/// 5. Write the downloaded file.
/// 6. Clear device-specific tables (tts_cache, execution_state).
/// 7. Prompt the user to restart the app so Drift re-opens with migrations.
///
/// ## Debounce
/// [resetDebounce] resets the 30-second debounce timer. Call after any
/// database mutation to schedule a background sync.
library sync_service;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/app_settings.dart';

part 'sync_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a sync operation fails after all retry attempts are exhausted.
final class SyncException implements Exception {
  const SyncException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => cause != null
      ? 'SyncException: $message (cause: $cause)'
      : 'SyncException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class SyncStatus {
  const SyncStatus({
    this.lastSyncAt,
    this.sizeBytes,
    this.isSyncing = false,
    this.lastError,
  });

  /// ISO-8601 string of the last successful sync, or null if never synced.
  final String? lastSyncAt;

  /// Size in bytes of the last uploaded database file, or null.
  final int? sizeBytes;

  final bool isSyncing;
  final String? lastError;

  /// Returns [lastSyncAt] parsed as a [DateTime], or null.
  DateTime? get lastSyncDateTime =>
      lastSyncAt != null ? DateTime.tryParse(lastSyncAt!) : null;

  SyncStatus copyWith({
    String? lastSyncAt,
    int? sizeBytes,
    bool? isSyncing,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncStatus(
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      isSyncing: isSyncing ?? this.isSyncing,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SyncService {
  /// Uploads the local SQLite database to S3.
  ///
  /// Checkpoints WAL, checks content hash to avoid redundant uploads, then
  /// GETs a pre-signed PUT URL and uploads the file directly to S3.
  Future<void> syncToCloud();

  /// Downloads the S3 backup and replaces the local database.
  ///
  /// Closes the Drift connection, deletes existing files, writes the download,
  /// and clears device-specific tables. **The caller must restart the app.**
  Future<void> restoreFromCloud();

  /// Returns the last sync timestamp and file size from [AppSettings].
  Future<SyncStatus> getSyncStatus();

  /// Resets the debounce timer and clears the stored content hash, allowing
  /// the next [syncToCloud] call to upload even if the file hasn't changed.
  ///
  /// Primarily used in tests to simulate 30 seconds passing without actually
  /// waiting. Production code can call this after a forced sync.
  Future<void> resetDebounce();

  /// Schedules a debounced sync (fires at most once per 30 seconds).
  ///
  /// Default implementation is a no-op — concrete classes override as needed.
  void scheduleDebouncedSync() {}

  /// Cancels any pending debounced sync.
  ///
  /// Default implementation is a no-op — concrete classes override as needed.
  void cancelDebouncedSync() {}

  /// Starts a repeating background sync that fires every [interval].
  ///
  /// If a sync is already in progress when the timer fires, it is skipped
  /// (shared [_isUploading] guard prevents concurrent uploads).
  ///
  /// Default implementation is a no-op — concrete classes override as needed.
  void schedulePeriodicSync(Duration interval) {}

  /// Cancels the repeating periodic sync timer.
  ///
  /// Default implementation is a no-op — concrete classes override as needed.
  void cancelPeriodicSync() {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

class SyncServiceImpl implements SyncService {
  SyncServiceImpl({
    required AppDatabase db,
    required AppSettings settings,
    required ApiClient apiClient,
    http.Client? httpClient,
  })  : _db = db,
        _settings = settings,
        _apiClient = apiClient,
        _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final AppSettings _settings;
  final ApiClient _apiClient;
  final http.Client _httpClient;

  Timer? _debounceTimer;
  Timer? _periodicTimer;

  /// Guards concurrent uploads — true while [syncToCloud] is executing.
  ///
  /// Both the debounced mutation sync and the periodic timer check this flag
  /// before starting an upload to prevent overlapping requests.
  bool _isUploading = false;

  static const Duration _debounceDuration = Duration(seconds: 30);
  static const int _maxRetries = 3;

  // ── Public API ─────────────────────────────────────────────────────────

  @override
  Future<void> syncToCloud() async {
    // Prevent concurrent uploads from both the debounce timer and the periodic
    // timer running at the same time.
    if (_isUploading) {
      debugPrint('SyncService: upload already in progress, skipping');
      return;
    }

    final dbPath = _db.dbFilePath;
    if (dbPath.isEmpty) {
      debugPrint('SyncService: no db file path (in-memory db?), skipping sync');
      return;
    }

    _isUploading = true;
    try {
      // 1. Checkpoint WAL to merge pending writes into the main .db file.
      debugPrint('SyncService: checkpointing WAL…');
      await _db.walCheckpoint();

      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        debugPrint('SyncService: db file not found at $dbPath');
        return;
      }

      final dbBytes = await dbFile.readAsBytes();

      // 2. Check if content has changed since last sync.
      // Compute hash directly on the raw bytes to avoid double-encoding issues
      // with binary data (String.fromCharCodes may mangle bytes > 127).
      final currentHash = sha256.convert(dbBytes).toString();
      final lastHash = await _settings.read(AppSettingsKeys.lastSyncHash);
      if (lastHash == currentHash) {
        debugPrint('SyncService: db unchanged (hash match), skipping upload.');
        return;
      }

      // 3. Get pre-signed PUT URL from backend.
      debugPrint('SyncService: requesting upload URL…');
      final uploadResponse = await _withRetry(() async {
        final baseUrl = await _apiClient.backendBaseUrl;
        return _apiClient.postJson(
            Uri.parse('$baseUrl/api/sync/upload'), {});
      });

      final uploadUrl = uploadResponse['uploadUrl']?.toString();
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw Exception('Server returned an empty upload URL.');
      }

      // 4. Upload directly to S3.
      debugPrint('SyncService: uploading ${dbBytes.length} bytes to S3…');
      await _withRetry(() async {
        final response = await _httpClient
            .put(
              Uri.parse(uploadUrl),
              headers: {
                'Content-Type': 'application/octet-stream',
                'Content-Length': '${dbBytes.length}',
              },
              body: dbBytes,
            )
            .timeout(const Duration(minutes: 5));

        if (response.statusCode != 200 && response.statusCode != 204) {
          throw Exception(
              'S3 upload failed (HTTP ${response.statusCode})');
        }
        return response;
      });

      // 5. Record sync metadata.
      final now = DateTime.now();
      await Future.wait([
        _settings.write(AppSettingsKeys.lastSyncAt, now.toIso8601String()),
        _settings.write(
            AppSettingsKeys.lastSyncSizeBytes, dbBytes.length.toString()),
        _settings.write(AppSettingsKeys.lastSyncHash, currentHash),
      ]);

      debugPrint(
          'SyncService: sync complete — ${dbBytes.length} bytes at $now');
    } finally {
      _isUploading = false;
    }
  }

  @override
  Future<void> restoreFromCloud() async {
    // Cancel any pending debounced sync — we're about to close the database.
    cancelDebouncedSync();

    // 1. Get pre-signed GET URL.
    debugPrint('SyncService: requesting download URL…');
    final downloadResponse = await _withRetry(() async {
      final baseUrl = await _apiClient.backendBaseUrl;
      return _apiClient.getJson(Uri.parse('$baseUrl/api/sync/download'));
    });

    final downloadUrl = downloadResponse['downloadUrl']?.toString();
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw Exception('Server returned an empty download URL.');
    }

    // 2. Download the database file.
    debugPrint('SyncService: downloading database from S3…');
    final dbBytes = await _withRetry(() async {
      final response = await _httpClient
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        throw Exception(
            'S3 download failed (HTTP ${response.statusCode})');
      }
      return response.bodyBytes;
    });
    debugPrint('SyncService: downloaded ${dbBytes.length} bytes');

    final dbPath = _db.dbFilePath;
    if (dbPath.isEmpty) {
      throw Exception('Cannot restore: db file path is unknown.');
    }

    // 3. Close the Drift connection.
    await _db.close();

    // 4. Delete existing .db, .db-wal, .db-shm files.
    final dbFile = File(dbPath);
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');

    for (final f in [dbFile, walFile, shmFile]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('SyncService: could not delete ${f.path}: $e');
      }
    }

    // 5. Write the downloaded file.
    await dbFile.writeAsBytes(dbBytes);
    debugPrint('SyncService: wrote restored database to $dbPath');

    // 6. Clear device-specific tables so paths/state from the source device
    //    don't pollute the restored device.
    //    tts_cache_table: audio file paths are device-specific.
    //    execution_state_table: transient runtime state that should not carry over.
    //    Best-effort: the restore itself already succeeded at this point, so
    //    a failure here (e.g. schema mismatch) should not undo the restore.
    final restoredDb = AppDatabase();
    try {
      await restoredDb.delete(restoredDb.ttsCacheTable).go();
      await restoredDb.delete(restoredDb.executionStateTable).go();
      debugPrint(
          'SyncService: cleared tts_cache_table and execution_state_table after restore');

      // Write sync metadata so the UI shows "Last synced" instead of
      // "Never synced". The uploaded file on S3 was captured *before*
      // sync metadata was written, so the restored DB lacks it.
      final restoredSettings = AppSettings(restoredDb);
      final now = DateTime.now();
      await Future.wait([
        restoredSettings.write(
            AppSettingsKeys.lastSyncAt, now.toIso8601String()),
        restoredSettings.write(
            AppSettingsKeys.lastSyncSizeBytes, dbBytes.length.toString()),
      ]);
      debugPrint('SyncService: wrote restore metadata to restored database');
    } catch (e) {
      debugPrint(
          'SyncService: warning: could not clear device-specific tables: $e');
    } finally {
      await restoredDb.close();
    }

    // NOTE: The app must be restarted for Drift to re-open the database with
    // migrations applied. The UI layer (sync_section.dart) handles the prompt.
  }

  @override
  Future<SyncStatus> getSyncStatus() async {
    final lastSyncAtStr = await _settings.read(AppSettingsKeys.lastSyncAt);
    final sizeBytesStr =
        await _settings.read(AppSettingsKeys.lastSyncSizeBytes);

    DateTime? lastSyncAt;
    if (lastSyncAtStr != null && lastSyncAtStr.isNotEmpty) {
      lastSyncAt = DateTime.tryParse(lastSyncAtStr);
    }

    int? sizeBytes;
    if (sizeBytesStr != null && sizeBytesStr.isNotEmpty) {
      sizeBytes = int.tryParse(sizeBytesStr);
    }

    return SyncStatus(lastSyncAt: lastSyncAt?.toIso8601String(), sizeBytes: sizeBytes);
  }

  @override
  void scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      syncToCloud().catchError((e) {
        debugPrint('SyncService: debounced sync failed: $e');
      });
    });
    debugPrint('SyncService: sync scheduled in ${_debounceDuration.inSeconds}s');
  }

  @override
  void cancelDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  @override
  void schedulePeriodicSync(Duration interval) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      // Skip if a sync is already in progress (guarded by _isUploading).
      syncToCloud().catchError((e) {
        debugPrint('SyncService: periodic sync failed: $e');
      });
    });
    debugPrint(
        'SyncService: periodic sync started (interval: ${interval.inMinutes}m)');
  }

  @override
  void cancelPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('SyncService: periodic sync cancelled');
  }

  @override
  Future<void> resetDebounce() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    // Clear stored hash so the next syncToCloud() re-uploads even if unchanged.
    await _settings.write(AppSettingsKeys.lastSyncHash, '');
    debugPrint('SyncService: debounce reset');
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Future<T> _withRetry<T>(Future<T> Function() fn) async {
    Exception? lastError;
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < _maxRetries - 1) {
          final delay = Duration(seconds: 1 << attempt); // 1s, 2s, 4s
          debugPrint(
              'SyncService: attempt ${attempt + 1} failed ($e), retrying in ${delay.inSeconds}s…');
          await Future<void>.delayed(delay);
        }
      }
    }
    throw lastError!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final settings = ref.watch(appSettingsProvider);
  final client = ref.watch(apiClientProvider);
  return SyncServiceImpl(db: db, settings: settings, apiClient: client);
}
