/// Unit tests for [AudioDownloadService] (TASK-034).
///
/// ## Test Coverage
///
/// 1. **[_FakeAudioDownloadService]** — verifies the interface contract.
///
/// 2. **[AudioDownloadServiceImpl] — happy path** — downloads all files,
///    saves to disk, inserts DB rows, emits progress.
///
/// 3. **Skip already-cached** — files already in [TtsCacheTable] with the
///    audio file on disk are excluded from the download batch.
///
/// 4. **HTTP 403 retry** — on 403, re-fetches URLs via API and retries once.
///
/// 5. **isFullyDownloaded** — returns true/false based on DB + disk state.
///
/// 6. **downloadProgress stream** — emits correct (completed, total) tuples.
///
/// ## Note
/// DB-dependent tests use [AppDatabase.forTesting] with an in-memory SQLite
/// database. Run `flutter pub run build_runner build` first to generate the
/// required Drift code.
///
/// ## Running
/// ```
/// flutter test test/services/audio_download_service_test.dart
/// ```
library audio_download_service_test;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/plan_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake AudioDownloadService (interface-level tests)
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory fake that records calls and returns configurable results.
///
/// Useful for testing callers of [AudioDownloadService] without any
/// real HTTP, database, or filesystem dependencies.
class _FakeAudioDownloadService implements AudioDownloadService {
  final List<String> downloadPlanAudioCalls = [];
  final List<String> isFullyDownloadedCalls = [];

  bool isFullyDownloadedResult = false;
  Exception? nextError;

  final _progressController =
      StreamController<DownloadProgress>.broadcast();

  void emitProgress(DownloadProgress progress) =>
      _progressController.add(progress);

  @override
  Stream<DownloadProgress> get downloadProgress =>
      _progressController.stream;

  @override
  Future<void> downloadPlanAudio(String planId) async {
    downloadPlanAudioCalls.add(planId);
    if (nextError != null) {
      final e = nextError!;
      nextError = null;
      throw e;
    }
  }

  @override
  Future<bool> isFullyDownloaded(String planId) async {
    isFullyDownloadedCalls.add(planId);
    if (nextError != null) {
      final e = nextError!;
      nextError = null;
      throw e;
    }
    return isFullyDownloadedResult;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fake PlanApiService
// ─────────────────────────────────────────────────────────────────────────────

class _FakePlanApiService implements PlanApiService {
  List<AudioFileUrl> audioUrlsResult = [];
  Exception? audioUrlsError;
  int getAudioUrlsCallCount = 0;

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async {
    getAudioUrlsCallCount++;
    if (audioUrlsError != null) throw audioUrlsError!;
    return List.of(audioUrlsResult);
  }

  @override
  Future<List<Plan>> fetchUserPlans() =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<Plan> getPlanById(String id) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<String> savePlan(Plan plan) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<void> deletePlan(String id) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<void> activatePlan(String planId, {required String voice, required String locale, required String speechRate}) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<Plan> getLibraryPlanById(String id) =>
      throw UnimplementedError('not used in audio download tests');

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) =>
      throw UnimplementedError('not used in audio download tests');
}

// ─────────────────────────────────────────────────────────────────────────────
// Stub HTTP client
// ─────────────────────────────────────────────────────────────────────────────

/// A stub [http.Client] that returns pre-programmed responses by URL.
/// Unregistered URLs return HTTP 404.
class _StubHttpClient extends http.BaseClient {
  final _responses = <String, ({int statusCode, List<int> bytes})>{};
  final _callLog = <String>[];

  List<String> get callLog => List.unmodifiable(_callLog);

  void addResponse(
    String url, {
    int statusCode = 200,
    List<int>? bytes,
  }) {
    _responses[url] = (
      statusCode: statusCode,
      bytes: bytes ?? _defaultAudioBytes(),
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    _callLog.add(url);
    final entry =
        _responses[url] ?? (statusCode: 404, bytes: <int>[]);
    return http.StreamedResponse(
      Stream.value(Uint8List.fromList(entry.bytes)),
      entry.statusCode,
    );
  }
}

/// Returns minimal audio-like bytes for testing.
List<int> _defaultAudioBytes([int size = 128]) =>
    List.generate(size, (i) => i % 256);

// ─────────────────────────────────────────────────────────────────────────────
// Test data builders
// ─────────────────────────────────────────────────────────────────────────────

AudioFileUrl _makeUrl(String cacheKey, {String? url}) => AudioFileUrl(
      cacheKey: cacheKey,
      url: url ?? 'https://s3.example.com/$cacheKey.wav',
    );

/// Inserts a pre-cached row into [db] and creates the file at [path].
Future<void> _precache(
  AppDatabase db, {
  required String path,
  required String cacheKey,
  required String planId,
}) async {
  await File(path).writeAsBytes(_defaultAudioBytes());
  await db.into(db.ttsCacheTable).insert(
        TtsCacheTableCompanion.insert(
          textHash: cacheKey,
          voiceId: kGenAiVoiceId,
          filePath: path,
          fileSizeBytes: const Value(128),
          planId: Value(planId),
          provider: const Value(kGenAiProvider),
          speechRate: const Value('1.0'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Fake interface tests ────────────────────────────────────────────────────

  group('_FakeAudioDownloadService (interface contract)', () {
    late _FakeAudioDownloadService fake;

    setUp(() => fake = _FakeAudioDownloadService());

    test('downloadPlanAudio records planId', () async {
      await fake.downloadPlanAudio('plan-1');
      expect(fake.downloadPlanAudioCalls, ['plan-1']);
    });

    test('downloadPlanAudio throws configured error', () async {
      fake.nextError = const AudioDownloadException('network failure');
      expect(
        () => fake.downloadPlanAudio('plan-1'),
        throwsA(isA<AudioDownloadException>()),
      );
    });

    test('isFullyDownloaded returns configured value', () async {
      fake.isFullyDownloadedResult = true;
      expect(await fake.isFullyDownloaded('plan-2'), isTrue);
      expect(fake.isFullyDownloadedCalls, ['plan-2']);
    });

    test('downloadProgress emits events via emitProgress helper', () async {
      final received = <DownloadProgress>[];
      final sub = fake.downloadProgress.listen(received.add);
      addTearDown(sub.cancel);

      fake.emitProgress((completed: 1, total: 3));
      fake.emitProgress((completed: 3, total: 3));

      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(2));
      expect(received[0].completed, 1);
      expect(received[1].completed, 3);
    });
  });

  // ── AudioDownloadServiceImpl tests ──────────────────────────────────────────

  group('AudioDownloadServiceImpl', () {
    late Directory tempDir;
    late AppDatabase db;
    late _FakePlanApiService api;
    late _StubHttpClient httpClient;
    late AudioDownloadServiceImpl service;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('audio_dl_test_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      api = _FakePlanApiService();
      httpClient = _StubHttpClient();
      service = AudioDownloadServiceImpl(
        db: db,
        api: api,
        audioDirectory: tempDir.path,
        httpClient: httpClient,
      );
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    // ── empty URL list ──────────────────────────────────────────────────────

    test('returns early when API returns no URLs', () async {
      api.audioUrlsResult = [];
      await expectLater(service.downloadPlanAudio('plan-empty'), completes);
      expect(httpClient.callLog, isEmpty);
    });

    // ── happy path ──────────────────────────────────────────────────────────

    test('downloads all files and saves to disk', () async {
      const cacheKey1 = 'abc123';
      const cacheKey2 = 'def456';
      final url1 = 'https://s3.example.com/$cacheKey1.wav';
      final url2 = 'https://s3.example.com/$cacheKey2.wav';

      api.audioUrlsResult = [
        _makeUrl(cacheKey1, url: url1),
        _makeUrl(cacheKey2, url: url2),
      ];
      httpClient.addResponse(url1, bytes: _defaultAudioBytes(100));
      httpClient.addResponse(url2, bytes: _defaultAudioBytes(200));

      await service.downloadPlanAudio('plan-happy');

      expect(
        File('${tempDir.path}/$cacheKey1.wav').existsSync(),
        isTrue,
      );
      expect(
        File('${tempDir.path}/$cacheKey2.wav').existsSync(),
        isTrue,
      );
    });

    test('inserts rows into TtsCacheTable with correct planId and provider',
        () async {
      const cacheKey = 'cache-key-insert';
      final url = 'https://s3.example.com/$cacheKey.wav';

      api.audioUrlsResult = [_makeUrl(cacheKey, url: url)];
      httpClient.addResponse(url, bytes: _defaultAudioBytes(64));

      await service.downloadPlanAudio('plan-insert-test');

      final rows = await db.select(db.ttsCacheTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.textHash, cacheKey);
      expect(rows.first.planId, 'plan-insert-test');
      expect(rows.first.provider, kGenAiProvider);
      expect(rows.first.fileSizeBytes, 64);
    });

    test('saved file bytes match downloaded response bytes', () async {
      const cacheKey = 'content-check';
      final url = 'https://s3.example.com/$cacheKey.wav';
      final expected = _defaultAudioBytes(48);

      api.audioUrlsResult = [_makeUrl(cacheKey, url: url)];
      httpClient.addResponse(url, bytes: expected);

      await service.downloadPlanAudio('plan-content');

      final actual =
          await File('${tempDir.path}/$cacheKey.wav').readAsBytes();
      expect(actual, equals(expected));
    });

    // ── skip already-cached ─────────────────────────────────────────────────

    test('skips files already in DB and on disk', () async {
      const cachedKey = 'already-cached';
      const newKey = 'needs-download';

      await _precache(
        db,
        path: '${tempDir.path}/$cachedKey.wav',
        cacheKey: cachedKey,
        planId: 'plan-skip',
      );

      final newUrl = 'https://s3.example.com/$newKey.wav';
      api.audioUrlsResult = [
        _makeUrl(cachedKey), // must be skipped
        _makeUrl(newKey, url: newUrl),
      ];
      httpClient.addResponse(newUrl, bytes: _defaultAudioBytes(64));

      await service.downloadPlanAudio('plan-skip');

      // Only the new URL must have been fetched.
      expect(httpClient.callLog, [newUrl]);
    });

    test('does not re-download on a second identical call', () async {
      const cacheKey = 'idempotent';
      final url = 'https://s3.example.com/$cacheKey.wav';
      api.audioUrlsResult = [_makeUrl(cacheKey, url: url)];
      httpClient.addResponse(url, bytes: _defaultAudioBytes());

      await service.downloadPlanAudio('plan-idem');
      final countAfterFirst = httpClient.callLog.length;

      await service.downloadPlanAudio('plan-idem');
      // No new HTTP calls on the second invocation.
      expect(httpClient.callLog.length, countAfterFirst);
    });

    test('treats stale DB row (file missing on disk) as a cache miss',
        () async {
      const staleKey = 'stale-db-entry';
      // Insert DB row without creating the file.
      await db.into(db.ttsCacheTable).insert(
            TtsCacheTableCompanion.insert(
              textHash: staleKey,
              voiceId: kGenAiVoiceId,
              filePath: '${tempDir.path}/$staleKey.wav', // file does NOT exist
              fileSizeBytes: const Value(128),
              planId: const Value('plan-stale'),
              provider: const Value(kGenAiProvider),
              speechRate: const Value('1.0'),
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final url = 'https://s3.example.com/$staleKey.wav';
      api.audioUrlsResult = [_makeUrl(staleKey, url: url)];
      httpClient.addResponse(url, bytes: _defaultAudioBytes());

      await service.downloadPlanAudio('plan-stale');

      // The stale row must have triggered a re-download.
      expect(httpClient.callLog, contains(url));
      expect(
        File('${tempDir.path}/$staleKey.wav').existsSync(),
        isTrue,
      );
    });

    // ── HTTP 403 retry ──────────────────────────────────────────────────────

    test('retries with refreshed URL on HTTP 403', () async {
      const cacheKey = '403-retry';
      const staleUrl = 'https://s3.example.com/stale/$cacheKey.wav';
      const freshUrl = 'https://s3.example.com/fresh/$cacheKey.wav';

      httpClient.addResponse(staleUrl, statusCode: 403);
      httpClient.addResponse(freshUrl, bytes: _defaultAudioBytes());

      final refreshApi = _RefreshingFakePlanApiService(
        initial: [_makeUrl(cacheKey, url: staleUrl)],
        refreshed: [_makeUrl(cacheKey, url: freshUrl)],
      );
      final retryService = AudioDownloadServiceImpl(
        db: db,
        api: refreshApi,
        audioDirectory: tempDir.path,
        httpClient: httpClient,
      );

      await retryService.downloadPlanAudio('plan-403');

      expect(httpClient.callLog, containsAll([staleUrl, freshUrl]));
      expect(
        File('${tempDir.path}/$cacheKey.wav').existsSync(),
        isTrue,
      );
    });

    test('throws AudioDownloadException when retried URL also returns 403',
        () async {
      const cacheKey = 'double-403';
      const staleUrl = 'https://s3.example.com/stale/$cacheKey.wav';
      const alsoStaleUrl =
          'https://s3.example.com/also-stale/$cacheKey.wav';

      httpClient.addResponse(staleUrl, statusCode: 403);
      httpClient.addResponse(alsoStaleUrl, statusCode: 403);

      final failApi = _RefreshingFakePlanApiService(
        initial: [_makeUrl(cacheKey, url: staleUrl)],
        refreshed: [_makeUrl(cacheKey, url: alsoStaleUrl)],
      );
      final failService = AudioDownloadServiceImpl(
        db: db,
        api: failApi,
        audioDirectory: tempDir.path,
        httpClient: httpClient,
      );

      await expectLater(
        failService.downloadPlanAudio('plan-double-403'),
        throwsA(isA<AudioDownloadException>()),
      );
    });

    test('throws AudioDownloadException when key is absent after URL refresh',
        () async {
      const cacheKey = 'missing-after-refresh';
      const url = 'https://s3.example.com/$cacheKey.wav';

      httpClient.addResponse(url, statusCode: 403);

      // Refresh returns an empty list — key is gone.
      final missingApi = _RefreshingFakePlanApiService(
        initial: [_makeUrl(cacheKey, url: url)],
        refreshed: [],
      );
      final missingService = AudioDownloadServiceImpl(
        db: db,
        api: missingApi,
        audioDirectory: tempDir.path,
        httpClient: httpClient,
      );

      await expectLater(
        missingService.downloadPlanAudio('plan-key-gone'),
        throwsA(isA<AudioDownloadException>()),
      );
    });

    // ── API error ───────────────────────────────────────────────────────────

    test('throws AudioDownloadException when getAudioUrls API call fails',
        () async {
      api.audioUrlsError = const PlanApiException('server error');
      await expectLater(
        service.downloadPlanAudio('plan-api-error'),
        throwsA(isA<AudioDownloadException>()),
      );
    });

    // ── downloadProgress stream ─────────────────────────────────────────────

    test('emits initial progress snapshot including pre-cached files',
        () async {
      const cachedKey = 'cached-progress';
      const newKey = 'new-progress';

      await _precache(
        db,
        path: '${tempDir.path}/$cachedKey.wav',
        cacheKey: cachedKey,
        planId: 'plan-prog',
      );

      final newUrl = 'https://s3.example.com/$newKey.wav';
      api.audioUrlsResult = [
        _makeUrl(cachedKey),
        _makeUrl(newKey, url: newUrl),
      ];
      httpClient.addResponse(newUrl, bytes: _defaultAudioBytes());

      final snapshots = <DownloadProgress>[];
      final sub = service.downloadProgress.listen(snapshots.add);
      addTearDown(sub.cancel);

      await service.downloadPlanAudio('plan-prog');

      // Initial snapshot: 1 cached, total = 2.
      expect(snapshots.first.total, 2);
      expect(snapshots.first.completed, 1);
      // Final snapshot: all 2 completed.
      expect(snapshots.last.completed, 2);
      expect(snapshots.last.total, 2);
    });

    test('emits one event per downloaded file plus the initial event',
        () async {
      const urlList = [
        'https://s3.example.com/p1.wav',
        'https://s3.example.com/p2.wav',
        'https://s3.example.com/p3.wav',
      ];
      api.audioUrlsResult = [
        _makeUrl('p1', url: urlList[0]),
        _makeUrl('p2', url: urlList[1]),
        _makeUrl('p3', url: urlList[2]),
      ];
      for (final url in urlList) {
        httpClient.addResponse(url, bytes: _defaultAudioBytes());
      }

      final snapshots = <DownloadProgress>[];
      final sub = service.downloadProgress.listen(snapshots.add);
      addTearDown(sub.cancel);

      await service.downloadPlanAudio('plan-events');

      // 1 initial + 3 per-download = 4 events for 3 files.
      expect(snapshots, hasLength(4));
      expect(snapshots.last.completed, 3);
      expect(snapshots.last.total, 3);
    });

    test('emits completed == total when all files already cached', () async {
      const cacheKey = 'all-cached';
      await _precache(
        db,
        path: '${tempDir.path}/$cacheKey.wav',
        cacheKey: cacheKey,
        planId: 'plan-ac',
      );
      api.audioUrlsResult = [_makeUrl(cacheKey)];

      final snapshots = <DownloadProgress>[];
      final sub = service.downloadProgress.listen(snapshots.add);
      addTearDown(sub.cancel);

      await service.downloadPlanAudio('plan-ac');

      expect(snapshots.first.completed, 1);
      expect(snapshots.first.total, 1);
    });

    // ── isFullyDownloaded ───────────────────────────────────────────────────

    test('isFullyDownloaded returns false when no files are cached',
        () async {
      api.audioUrlsResult = [_makeUrl('key-a'), _makeUrl('key-b')];
      expect(
        await service.isFullyDownloaded('plan-not-cached'),
        isFalse,
      );
    });

    test('isFullyDownloaded returns false when only some files are cached',
        () async {
      const cachedKey = 'half-cached';
      await _precache(
        db,
        path: '${tempDir.path}/$cachedKey.wav',
        cacheKey: cachedKey,
        planId: 'plan-half',
      );
      api.audioUrlsResult = [
        _makeUrl(cachedKey),
        _makeUrl('half-uncached'),
      ];
      expect(await service.isFullyDownloaded('plan-half'), isFalse);
    });

    test('isFullyDownloaded returns true when every file is cached', () async {
      const keys = ['full-1', 'full-2'];
      for (final key in keys) {
        await _precache(
          db,
          path: '${tempDir.path}/$key.wav',
          cacheKey: key,
          planId: 'plan-full',
        );
      }
      api.audioUrlsResult = keys.map(_makeUrl).toList();
      expect(await service.isFullyDownloaded('plan-full'), isTrue);
    });

    test(
        'isFullyDownloaded returns false when DB row exists but file is missing',
        () async {
      const key = 'stale-full';
      // Insert DB row without creating the file.
      await db.into(db.ttsCacheTable).insert(
            TtsCacheTableCompanion.insert(
              textHash: key,
              voiceId: kGenAiVoiceId,
              filePath: '${tempDir.path}/$key.wav', // does NOT exist
              fileSizeBytes: const Value(128),
              planId: const Value('plan-stale-full'),
              provider: const Value(kGenAiProvider),
              speechRate: const Value('1.0'),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      api.audioUrlsResult = [_makeUrl(key)];
      expect(await service.isFullyDownloaded('plan-stale-full'), isFalse);
    });

    test('isFullyDownloaded returns false when API throws', () async {
      api.audioUrlsError = const PlanApiException('server error');
      expect(await service.isFullyDownloaded('plan-api-fail'), isFalse);
    });

    test('isFullyDownloaded returns false when API returns empty list',
        () async {
      api.audioUrlsResult = [];
      expect(await service.isFullyDownloaded('plan-no-urls'), isFalse);
    });

    // ── Concurrency ─────────────────────────────────────────────────────────

    test('handles 5 concurrent files with max-4 semaphore without error',
        () async {
      final keys = ['c1', 'c2', 'c3', 'c4', 'c5'];
      api.audioUrlsResult = keys
          .map((k) => _makeUrl(k, url: 'https://s3.example.com/$k.wav'))
          .toList();
      for (final k in keys) {
        httpClient.addResponse(
          'https://s3.example.com/$k.wav',
          bytes: _defaultAudioBytes(),
        );
      }

      await expectLater(
        service.downloadPlanAudio('plan-concurrent'),
        completes,
      );

      for (final k in keys) {
        expect(
          File('${tempDir.path}/$k.wav').existsSync(),
          isTrue,
          reason: 'Expected $k.wav to exist after download',
        );
      }
    });
  });

  // ── AudioDownloadException ──────────────────────────────────────────────────

  group('AudioDownloadException', () {
    test('toString includes class name and message', () {
      const e = AudioDownloadException('download failed');
      expect(e.toString(), contains('AudioDownloadException'));
      expect(e.toString(), contains('download failed'));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _RefreshingFakePlanApiService
// ─────────────────────────────────────────────────────────────────────────────

/// [PlanApiService] fake that returns [initial] URLs on the first
/// [getAudioUrls] call and [refreshed] URLs on all subsequent calls.
///
/// Used to simulate the HTTP 403 URL-refresh scenario.
class _RefreshingFakePlanApiService implements PlanApiService {
  _RefreshingFakePlanApiService({
    required this.initial,
    required this.refreshed,
  });

  final List<AudioFileUrl> initial;
  final List<AudioFileUrl> refreshed;
  int _callCount = 0;

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async {
    _callCount++;
    return _callCount == 1 ? List.of(initial) : List.of(refreshed);
  }

  @override
  Future<List<Plan>> fetchUserPlans() => throw UnimplementedError();

  @override
  Future<Plan> getPlanById(String id) => throw UnimplementedError();

  @override
  Future<String> savePlan(Plan plan) => throw UnimplementedError();

  @override
  Future<void> deletePlan(String id) => throw UnimplementedError();

  @override
  Future<void> activatePlan(String planId, {required String voice, required String locale, required String speechRate}) => throw UnimplementedError();

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) =>
      throw UnimplementedError();

  @override
  Future<Plan> getLibraryPlanById(String id) => throw UnimplementedError();

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) =>
      throw UnimplementedError();
}
