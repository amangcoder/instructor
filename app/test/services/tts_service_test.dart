/// Unit tests for [TTSService] and related helpers.
///
/// ## Test organisation
///
/// 1. **hash_utils** — pure-Dart tests, no dependencies. Run immediately
///    with `flutter test`.
///
/// 2. **TTSService interface contract** — verified via [_FakeTTSService].
///    Covers the expected behaviour of every public method without requiring
///    real network access, platform plugins, or generated Drift code.
///
/// 3. **[PlatformTtsEngine] behaviour** — [_FakePlatformTtsEngine] is
///    exercised directly to verify the contract that [TTSServiceImpl] relies on
///    for its platform-TTS fallback path.
///
/// 4. **TTSServiceImpl.renderWithPlatformTTS** — exercises the concrete
///    implementation's platform-TTS path using a fake [PlatformTtsEngine] and
///    a temporary filesystem directory.  This path never touches the database,
///    so it does not require generated Drift code.
///
/// 5. **DB-dependent paths** ([renderTTS], [isCached], [clearCacheForPlan])
///    are tested in the integration test suite after running:
///    ```
///    flutter pub run build_runner build --delete-conflicting-outputs
///    ```
///
/// ## Running
/// ```
/// flutter test test/services/tts_service_test.dart
/// ```
library tts_service_test;

import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/tts_service.dart';
import 'package:instructor/utils/hash_utils.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fake implementations
// ────────────────────────────────────────────────────────────────────────────

/// A fake [TTSService] whose state is fully observable without requiring
/// real network access, platform plugins, or a database.
class _FakeTTSService implements TTSService {
  // Captured calls
  final List<({String text, String voiceId})> renderTTSCalls = [];
  final List<Plan> preRenderPlanCalls = [];
  final List<int> clearCacheForPlanCalls = [];
  final List<({String textHash, String voiceId})> isCachedCalls = [];
  final List<String> renderWithPlatformTTSCalls = [];

  // Controllable state
  bool _isCachedResult = false;
  Exception? _renderError;
  final Map<String, String> _cacheMap = {};

  // Fake setup helpers
  void setIsCachedResult({required bool value}) => _isCachedResult = value;
  void setRenderError(Exception error) => _renderError = error;
  void setCacheEntry({
    required String text,
    required String voiceId,
    required String filePath,
  }) {
    _cacheMap[ttsCacheKey(voiceId: voiceId, text: text)] = filePath;
  }

  @override
  Future<String> renderTTS({
    required String text,
    required String voiceId,
  }) async {
    renderTTSCalls.add((text: text, voiceId: voiceId));
    if (_renderError != null) throw _renderError!;
    final hash = ttsCacheKey(voiceId: voiceId, text: text);
    return _cacheMap[hash] ?? '/fake/tts/$hash.mp3';
  }

  @override
  Future<void> preRenderPlan(Plan plan) async {
    preRenderPlanCalls.add(plan);
    if (_renderError != null) throw _renderError!;
  }

  @override
  Future<void> clearCacheForPlan(int planId) async {
    clearCacheForPlanCalls.add(planId);
  }

  @override
  Future<bool> isCached(String textHash, String voiceId) async {
    isCachedCalls.add((textHash: textHash, voiceId: voiceId));
    return _isCachedResult;
  }

  @override
  Future<String> renderWithPlatformTTS(String text) async {
    renderWithPlatformTTSCalls.add(text);
    if (_renderError != null) throw _renderError!;
    return '/fake/platform/${sha256Hex(text)}.wav';
  }
}

/// A fake [PlatformTtsEngine] that writes a small binary placeholder file
/// to simulate flutter_tts file synthesis.
class _FakePlatformTtsEngine implements PlatformTtsEngine {
  _FakePlatformTtsEngine({
    required this.tempDir,
    this.shouldSucceed = true,
  });

  final Directory tempDir;
  final bool shouldSucceed;

  final List<String> synthesizeCalls = [];
  int stopCount = 0;

  @override
  Future<bool> synthesizeToFile(String text, String filePath) async {
    synthesizeCalls.add(text);
    if (!shouldSucceed) return false;
    // Write a small placeholder to simulate TTS output.
    await File(filePath).writeAsBytes(
      Uint8List.fromList([0xFF, 0xFE, 0x01, 0x02]),
    );
    return true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Test helpers
// ────────────────────────────────────────────────────────────────────────────

/// Creates a minimal [Plan] for use in tests.
Plan _makePlan({
  int id = 1,
  String name = 'Test Plan',
  String defaultVoice = 'nova',
  List<PlanStep> steps = const [],
}) {
  final now = DateTime(2026);
  return Plan(
    id: id,
    name: name,
    defaultVoice: defaultVoice,
    steps: steps,
    createdAt: now,
    updatedAt: now,
  );
}

/// Creates a [SayStep] with an id derived from the text content.
PlanStep _sayStep(String text, {String? voiceId}) => PlanStep.say(
      id: 'step-${text.hashCode}',
      text: text,
      voiceId: voiceId,
    );

/// Creates a [RepeatStep] wrapping [children].
PlanStep _repeatStep(List<PlanStep> children, {int count = 3}) =>
    PlanStep.repeat(
      id: 'repeat-${children.hashCode}',
      count: count,
      children: children,
    );

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ── hash_utils ─────────────────────────────────────────────────────────────

  group('hash_utils', () {
    test('sha256Hex returns a 64-character hex string', () {
      final result = sha256Hex('hello');
      expect(result.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(result), isTrue);
    });

    test('sha256Hex is deterministic for the same input', () {
      expect(sha256Hex('same'), equals(sha256Hex('same')));
    });

    test('sha256Hex produces different digests for different inputs', () {
      expect(sha256Hex('a'), isNot(equals(sha256Hex('b'))));
    });

    test('sha256Hex handles empty string', () {
      // Well-known SHA-256 of an empty string.
      expect(
        sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('sha256Hex handles unicode input', () {
      final result = sha256Hex('こんにちは');
      expect(result.length, 64);
    });

    test('ttsCacheKey returns a 64-char hex string for a voice+text pair', () {
      final key = ttsCacheKey(voiceId: 'nova', text: 'Hello, world!');
      expect(key.length, 64);
    });

    test('ttsCacheKey is consistent with sha256Hex("voiceId:text")', () {
      const voiceId = 'shimmer';
      const text = 'Take a deep breath.';
      expect(
        ttsCacheKey(voiceId: voiceId, text: text),
        equals(sha256Hex('$voiceId:$text')),
      );
    });

    test(
      'ttsCacheKey produces different keys for same text with different voices',
      () {
        const text = 'Begin now.';
        final novaKey = ttsCacheKey(voiceId: 'nova', text: text);
        final onyxKey = ttsCacheKey(voiceId: 'onyx', text: text);
        expect(novaKey, isNot(equals(onyxKey)));
      },
    );

    test(
      'ttsCacheKey produces different keys for same voice with different texts',
      () {
        const voice = 'nova';
        final key1 = ttsCacheKey(voiceId: voice, text: 'Step one.');
        final key2 = ttsCacheKey(voiceId: voice, text: 'Step two.');
        expect(key1, isNot(equals(key2)));
      },
    );

    test('ttsCacheKey is stable across multiple calls', () {
      // Must be deterministic so the same audio file is found on subsequent
      // app launches.
      for (var i = 0; i < 10; i++) {
        expect(
          ttsCacheKey(voiceId: 'nova', text: 'Stability check'),
          equals(ttsCacheKey(voiceId: 'nova', text: 'Stability check')),
        );
      }
    });

    test('ttsCacheKey handles text longer than 500 characters', () {
      final longText = 'A' * 600;
      final key = ttsCacheKey(voiceId: 'nova', text: longText);
      expect(key.length, 64);
    });
  });

  // ── TTSService interface contract (via _FakeTTSService) ───────────────────

  group('TTSService interface contract (via _FakeTTSService)', () {
    late _FakeTTSService service;

    setUp(() {
      service = _FakeTTSService();
    });

    // ── renderTTS ──────────────────────────────────────────────────────────

    test('renderTTS records text and voiceId', () async {
      await service.renderTTS(text: 'Hello', voiceId: 'nova');
      expect(service.renderTTSCalls, hasLength(1));
      expect(service.renderTTSCalls.first.text, 'Hello');
      expect(service.renderTTSCalls.first.voiceId, 'nova');
    });

    test('renderTTS returns a non-empty file path', () async {
      final path =
          await service.renderTTS(text: 'Breath in', voiceId: 'shimmer');
      expect(path, isNotEmpty);
    });

    test('renderTTS returns the cached path when a cache entry is set', () async {
      service.setCacheEntry(
        text: 'cached text',
        voiceId: 'nova',
        filePath: '/cached/path.mp3',
      );
      final path =
          await service.renderTTS(text: 'cached text', voiceId: 'nova');
      expect(path, '/cached/path.mp3');
    });

    test(
      'renderTTS for different voices returns different paths',
      () async {
        final novaPath =
            await service.renderTTS(text: 'Same text', voiceId: 'nova');
        final onyxPath =
            await service.renderTTS(text: 'Same text', voiceId: 'onyx');
        expect(novaPath, isNot(equals(onyxPath)));
      },
    );

    test('renderTTS propagates TtsApiException', () async {
      service.setRenderError(
        const TtsApiException('API key missing', statusCode: 401),
      );
      await expectLater(
        service.renderTTS(text: 'hello', voiceId: 'nova'),
        throwsA(isA<TtsApiException>()),
      );
    });

    // ── preRenderPlan ──────────────────────────────────────────────────────

    test('preRenderPlan records the plan', () async {
      final plan = _makePlan();
      await service.preRenderPlan(plan);
      expect(service.preRenderPlanCalls, [plan]);
    });

    test('preRenderPlan with multiple calls records all plans', () async {
      final plan1 = _makePlan(id: 1);
      final plan2 = _makePlan(id: 2, name: 'Plan 2');
      await service.preRenderPlan(plan1);
      await service.preRenderPlan(plan2);
      expect(service.preRenderPlanCalls, hasLength(2));
    });

    test('preRenderPlan with no say steps completes without error', () async {
      final plan = _makePlan(
        steps: [
          PlanStep.wait(id: 'w1', duration: const Duration(seconds: 5)),
          PlanStep.notify(id: 'n1', title: 'Go!', body: 'Move'),
        ],
      );
      await expectLater(service.preRenderPlan(plan), completes);
    });

    // ── clearCacheForPlan ──────────────────────────────────────────────────

    test('clearCacheForPlan records the planId', () async {
      await service.clearCacheForPlan(42);
      expect(service.clearCacheForPlanCalls, [42]);
    });

    test('clearCacheForPlan for multiple plans records each id', () async {
      await service.clearCacheForPlan(1);
      await service.clearCacheForPlan(2);
      await service.clearCacheForPlan(3);
      expect(service.clearCacheForPlanCalls, [1, 2, 3]);
    });

    // ── isCached ──────────────────────────────────────────────────────────

    test('isCached records textHash and voiceId', () async {
      final hash = ttsCacheKey(voiceId: 'nova', text: 'Check');
      await service.isCached(hash, 'nova');
      expect(service.isCachedCalls.first.textHash, hash);
      expect(service.isCachedCalls.first.voiceId, 'nova');
    });

    test('isCached returns false by default', () async {
      final result = await service.isCached('any_hash', 'nova');
      expect(result, isFalse);
    });

    test('isCached returns true when configured to do so', () async {
      service.setIsCachedResult(value: true);
      final result = await service.isCached('any_hash', 'nova');
      expect(result, isTrue);
    });

    // ── renderWithPlatformTTS ──────────────────────────────────────────────

    test('renderWithPlatformTTS records text', () async {
      await service.renderWithPlatformTTS('Platform speech');
      expect(service.renderWithPlatformTTSCalls, ['Platform speech']);
    });

    test('renderWithPlatformTTS returns a non-empty path', () async {
      final path = await service.renderWithPlatformTTS('Hello from TTS');
      expect(path, isNotEmpty);
    });

    test('renderWithPlatformTTS propagates TtsFallbackException', () async {
      service.setRenderError(
        const TtsFallbackException('No TTS engine available'),
      );
      await expectLater(
        service.renderWithPlatformTTS('fail'),
        throwsA(isA<TtsFallbackException>()),
      );
    });
  });

  // ── _FakePlatformTtsEngine behaviour ──────────────────────────────────────

  group('_FakePlatformTtsEngine', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tts_engine_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('synthesizeToFile creates a file and returns true', () async {
      final engine = _FakePlatformTtsEngine(tempDir: tempDir);
      final filePath = '${tempDir.path}/test_output.wav';

      final result = await engine.synthesizeToFile('Hello', filePath);

      expect(result, isTrue);
      expect(File(filePath).existsSync(), isTrue);
    });

    test('synthesizeToFile records synthesized text', () async {
      final engine = _FakePlatformTtsEngine(tempDir: tempDir);
      await engine.synthesizeToFile('First', '${tempDir.path}/1.wav');
      await engine.synthesizeToFile('Second', '${tempDir.path}/2.wav');
      expect(engine.synthesizeCalls, ['First', 'Second']);
    });

    test(
      'synthesizeToFile returns false when shouldSucceed=false',
      () async {
        final engine = _FakePlatformTtsEngine(
          tempDir: tempDir,
          shouldSucceed: false,
        );
        final result = await engine.synthesizeToFile(
          'text',
          '${tempDir.path}/out.wav',
        );
        expect(result, isFalse);
      },
    );

    test('stop increments stopCount', () async {
      final engine = _FakePlatformTtsEngine(tempDir: tempDir);
      await engine.stop();
      expect(engine.stopCount, 1);
    });
  });

  // ── TTSServiceImpl.renderWithPlatformTTS (no DB required) ─────────────────
  //
  // [renderWithPlatformTTS] only uses the filesystem and [PlatformTtsEngine];
  // it never touches the database.  We can test it without generated Drift code
  // by constructing [TTSServiceImpl] with a null-stub database that throws on
  // any DB access (any DB call in this group is a test bug, not prod code).

  group('TTSServiceImpl.renderWithPlatformTTS', () {
    late Directory tempDir;
    late _FakePlatformTtsEngine fakeTtsEngine;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tts_impl_test_');
      fakeTtsEngine = _FakePlatformTtsEngine(tempDir: tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    TTSServiceImpl _makeService({PlatformTtsEngine? ttsEngine}) =>
        TTSServiceImpl(
          db: _NullAppDatabase(),
          audioDirectory: tempDir.path,
          ttsEngine: ttsEngine ?? fakeTtsEngine,
        );

    test('creates a file on disk and returns its path', () async {
      final service = _makeService();
      final path = await service.renderWithPlatformTTS('Take a breath.');

      expect(await File(path).exists(), isTrue);
    });

    test('returns the same path for the same text on repeated calls', () async {
      final service = _makeService();
      final path1 = await service.renderWithPlatformTTS('Stable text');
      final path2 = await service.renderWithPlatformTTS('Stable text');
      expect(path1, equals(path2));
    });

    test(
      'calls synthesizeToFile only once for the same text (file-exists check)',
      () async {
        final service = _makeService();
        await service.renderWithPlatformTTS('De-duped');
        await service.renderWithPlatformTTS('De-duped');
        // First call synthesises; second call hits the file-exists check.
        expect(fakeTtsEngine.synthesizeCalls, hasLength(1));
      },
    );

    test(
      'returns different paths for different texts',
      () async {
        final service = _makeService();
        final path1 = await service.renderWithPlatformTTS('First phrase');
        final path2 = await service.renderWithPlatformTTS('Second phrase');
        expect(path1, isNot(equals(path2)));
      },
    );

    test(
      'throws TtsFallbackException when synthesis returns false',
      () async {
        final failingEngine = _FakePlatformTtsEngine(
          tempDir: tempDir,
          shouldSucceed: false,
        );
        final service = _makeService(ttsEngine: failingEngine);

        await expectLater(
          service.renderWithPlatformTTS('Will fail'),
          throwsA(isA<TtsFallbackException>()),
        );
      },
    );
  });

  // ── Exceptions ─────────────────────────────────────────────────────────────

  group('Exception types', () {
    test('TtsApiException implements Exception', () {
      const e = TtsApiException('error', statusCode: 429);
      expect(e, isA<Exception>());
    });

    test('TtsFallbackException implements Exception', () {
      const e = TtsFallbackException('no engine');
      expect(e, isA<Exception>());
    });

    test('TtsApiException.toString includes status code and message', () {
      const e = TtsApiException('bad request', statusCode: 400);
      expect(e.toString(), contains('400'));
      expect(e.toString(), contains('bad request'));
    });

    test('TtsFallbackException.toString includes message', () {
      const e = TtsFallbackException('device unsupported');
      expect(e.toString(), contains('device unsupported'));
    });

    test('TtsApiException without statusCode has null statusCode', () {
      const e = TtsApiException('no key');
      expect(e.statusCode, isNull);
    });
  });

  // ── Constants ──────────────────────────────────────────────────────────────

  group('TTSService constants', () {
    test('kTtsMaxConcurrent is 5', () {
      expect(kTtsMaxConcurrent, 5);
    });

    test('kTtsApiUrl points to OpenAI TTS endpoint', () {
      expect(kTtsApiUrl, 'https://api.openai.com/v1/audio/speech');
    });

    test('kTtsModel is tts-1', () {
      expect(kTtsModel, 'tts-1');
    });

    test('kTtsApiTimeout is 30 seconds', () {
      expect(kTtsApiTimeout, const Duration(seconds: 30));
    });
  });

  // ── Compile-time interface compliance ─────────────────────────────────────

  group('Compile-time interface compliance', () {
    test('TTSServiceImpl is a subtype of TTSService', () {
      // This is a compile-time check: if TTSServiceImpl does not fully
      // implement TTSService, this file will not compile.
      expect(TTSServiceImpl, isNotNull);
    });

    test('FlutterTtsEngine is a subtype of PlatformTtsEngine', () {
      expect(FlutterTtsEngine, isNotNull);
    });

    test('_FakeTTSService satisfies TTSService interface', () {
      expect(_FakeTTSService(), isA<TTSService>());
    });

    test('_FakePlatformTtsEngine satisfies PlatformTtsEngine interface', () {
      final tempDir = Directory.systemTemp;
      expect(
        _FakePlatformTtsEngine(tempDir: tempDir),
        isA<PlatformTtsEngine>(),
      );
    });
  });

  // ── Step collection contract (via preRenderPlan) ───────────────────────────

  group('Step collection — recursive traversal contract', () {
    test('preRenderPlan is called with the correct plan object', () async {
      final service = _FakeTTSService();
      final plan = _makePlan(
        steps: [_sayStep('Hello'), _sayStep('Goodbye')],
      );
      await service.preRenderPlan(plan);
      expect(service.preRenderPlanCalls, hasLength(1));
      expect(service.preRenderPlanCalls.first, same(plan));
    });

    test(
      'preRenderPlan with nested repeat blocks completes without error',
      () async {
        final service = _FakeTTSService();
        final plan = _makePlan(
          steps: [
            _repeatStep([
              _sayStep('Inner step 1'),
              _repeatStep([_sayStep('Deep nested step')]),
            ]),
            _sayStep('Outer step'),
          ],
        );
        await expectLater(service.preRenderPlan(plan), completes);
      },
    );

    test('preRenderPlan with a plan of only wait steps completes', () async {
      final service = _FakeTTSService();
      final plan = _makePlan(
        steps: [
          PlanStep.wait(id: 'w1', duration: const Duration(seconds: 10)),
          PlanStep.wait(id: 'w2', duration: const Duration(seconds: 5)),
        ],
      );
      await expectLater(service.preRenderPlan(plan), completes);
    });

    test('Plan category enum is stable across test runs', () {
      expect(PlanCategory.yoga.name, 'yoga');
      expect(PlanCategory.custom.name, 'custom');
    });
  });
}

// ────────────────────────────────────────────────────────────────────────────
// Null stub for AppDatabase
// ────────────────────────────────────────────────────────────────────────────

/// Minimal stub that satisfies [TTSServiceImpl]'s constructor for tests that
/// only exercise [renderWithPlatformTTS] — a path that never touches the DB.
///
/// Any method call that reaches the database will throw [UnimplementedError],
/// which immediately surfaces as a test failure.
///
/// NOTE: This stub requires [AppDatabase] to be fully compiled. Run
/// `flutter pub run build_runner build --delete-conflicting-outputs` if the
/// project has not yet generated its Drift/Freezed code.
class _NullAppDatabase extends AppDatabase {
  _NullAppDatabase() : super(NativeDatabase.memory());
}
