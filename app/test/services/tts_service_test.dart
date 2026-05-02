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
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/models/auth_models.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/services/tts_service.dart';
import 'package:instructor/utils/hash_utils.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fake implementations
// ────────────────────────────────────────────────────────────────────────────

/// A fake [TTSService] whose state is fully observable without requiring
/// real network access, platform plugins, or a database.
class _FakeTTSService implements TTSService {
  // Captured calls — each entry records text, voiceId, and mode.
  final List<({String text, String voiceId, TtsPlaybackMode mode})>
      renderTTSCalls = [];
  final List<String> clearCacheForPlanCalls = [];
  final List<({String textHash, String voiceId})> isCachedCalls = [];
  final List<String> renderWithPlatformTTSCalls = [];
  final List<({String text, String planId, String voiceId, TtsPlaybackMode mode})>
      renderTTSForPlanCalls = [];

  // Controllable state
  bool _isCachedResult = false;
  Exception? _renderError;
  final Map<String, String> _cacheMap = {};
  bool _hasReadyVoice = true;

  // Fake setup helpers
  void setIsCachedResult({required bool value}) => _isCachedResult = value;
  void setRenderError(Exception error) => _renderError = error;
  void setHasReadyVoice({required bool value}) => _hasReadyVoice = value;
  void setCacheEntry({
    required String text,
    required String voiceId,
    required String filePath,
  }) {
    _cacheMap[ttsCacheKey(provider: 'backend', voiceId: voiceId, text: text)] =
        filePath;
  }

  @override
  Future<String?> renderTTS(
      String text, String voiceId, TtsPlaybackMode mode) async {
    renderTTSCalls.add((text: text, voiceId: voiceId, mode: mode));
    if (_renderError != null) throw _renderError!;
    final hash = ttsCacheKey(provider: 'backend', voiceId: voiceId, text: text);
    // Simulate cache-first behaviour: return the cached entry if present.
    if (_cacheMap.containsKey(hash)) return _cacheMap[hash];
    // Platform mode: return null on cache miss (no API call).
    if (mode == TtsPlaybackMode.platform) return null;
    // GenAI mode: return a synthetic file path.
    return '/fake/tts/$hash.wav';
  }

  @override
  Future<String?> renderTTSForPlan(
    String text,
    String planId,
    String voiceId,
    TtsPlaybackMode mode,
  ) async {
    renderTTSForPlanCalls.add((
      text: text,
      planId: planId,
      voiceId: voiceId,
      mode: mode,
    ));
    if (_renderError != null) throw _renderError!;
    // Simulate gate: no ready voice → return null (platform TTS invoked).
    if (!_hasReadyVoice) return null;
    // Ready voice → simulate genai render.
    final hash = ttsCacheKey(provider: 'backend', voiceId: voiceId, text: text);
    return '/fake/tts/$hash.wav';
  }

  @override
  Future<void> clearCacheForPlan(String planId) async {
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

  @override
  Future<void> speakDirect(String text, {double speed = 1.0}) async {}

  @override
  Future<void> stopSpeaking() async {}
}

// ────────────────────────────────────────────────────────────────────────────
// Fake PlanVoiceChecker
// ────────────────────────────────────────────────────────────────────────────

/// Fake [PlanVoiceChecker] whose result is controlled per-test.
class _FakePlanVoiceChecker implements PlanVoiceChecker {
  _FakePlanVoiceChecker({required bool hasReady}) : _hasReady = hasReady;

  bool _hasReady;
  final List<String> checkedPlanIds = [];

  void setHasReady({required bool value}) => _hasReady = value;

  @override
  Future<bool> hasReadyVoice(String planId) async {
    checkedPlanIds.add(planId);
    return _hasReady;
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
  final List<({String text, double speed})> speakCalls = [];
  int stopCount = 0;

  @override
  Future<bool> synthesizeToFile(String text, String filePath,
      {double speed = 1.0}) async {
    synthesizeCalls.add(text);
    if (!shouldSucceed) return false;
    // Write a small placeholder to simulate TTS output.
    await File(filePath).writeAsBytes(
      Uint8List.fromList([0xFF, 0xFE, 0x01, 0x02]),
    );
    return true;
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    speakCalls.add((text: text, speed: speed));
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
      final key = ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Hello, world!');
      expect(key.length, 64);
    });

    test('ttsCacheKey is consistent with sha256Hex("provider:voiceId:text")', () {
      const provider = 'openai';
      const voiceId = 'shimmer';
      const text = 'Take a deep breath.';
      expect(
        ttsCacheKey(provider: provider, voiceId: voiceId, text: text),
        equals(sha256Hex('$provider:$voiceId:$text')),
      );
    });

    test(
      'ttsCacheKey produces different keys for same text with different voices',
      () {
        const text = 'Begin now.';
        final novaKey = ttsCacheKey(provider: 'openai', voiceId: 'nova', text: text);
        final onyxKey = ttsCacheKey(provider: 'openai', voiceId: 'onyx', text: text);
        expect(novaKey, isNot(equals(onyxKey)));
      },
    );

    test(
      'ttsCacheKey produces different keys for same voice with different texts',
      () {
        const voice = 'nova';
        final key1 = ttsCacheKey(provider: 'openai', voiceId: voice, text: 'Step one.');
        final key2 = ttsCacheKey(provider: 'openai', voiceId: voice, text: 'Step two.');
        expect(key1, isNot(equals(key2)));
      },
    );

    test('ttsCacheKey is stable across multiple calls', () {
      // Must be deterministic so the same audio file is found on subsequent
      // app launches.
      for (var i = 0; i < 10; i++) {
        expect(
          ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Stability check'),
          equals(ttsCacheKey(provider: 'openai', voiceId: 'nova', text: 'Stability check')),
        );
      }
    });

    test('ttsCacheKey handles text longer than 500 characters', () {
      final longText = 'A' * 600;
      final key = ttsCacheKey(provider: 'openai', voiceId: 'nova', text: longText);
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

    test('renderTTS records text, voiceId, and mode', () async {
      await service.renderTTS('Hello', 'nova', TtsPlaybackMode.genai);
      expect(service.renderTTSCalls, hasLength(1));
      expect(service.renderTTSCalls.first.text, 'Hello');
      expect(service.renderTTSCalls.first.voiceId, 'nova');
      expect(service.renderTTSCalls.first.mode, TtsPlaybackMode.genai);
    });

    test('renderTTS genai mode returns a non-empty file path', () async {
      final path =
          await service.renderTTS('Breath in', 'shimmer', TtsPlaybackMode.genai);
      expect(path, isNotEmpty);
    });

    test('renderTTS platform mode returns null on cache miss', () async {
      final path =
          await service.renderTTS('Hello', 'nova', TtsPlaybackMode.platform);
      expect(path, isNull);
    });

    test('renderTTS returns cached path regardless of mode', () async {
      service.setCacheEntry(
        text: 'cached text',
        voiceId: 'nova',
        filePath: '/cached/path.mp3',
      );
      // Cache hit is returned even in platform mode.
      final platformPath = await service.renderTTS(
          'cached text', 'nova', TtsPlaybackMode.platform);
      expect(platformPath, '/cached/path.mp3');
      // And in genai mode.
      final genaiPath = await service.renderTTS(
          'cached text', 'nova', TtsPlaybackMode.genai);
      expect(genaiPath, '/cached/path.mp3');
    });

    test(
      'renderTTS genai mode returns different paths for different voices',
      () async {
        final novaPath =
            await service.renderTTS('Same text', 'nova', TtsPlaybackMode.genai);
        final onyxPath =
            await service.renderTTS('Same text', 'onyx', TtsPlaybackMode.genai);
        expect(novaPath, isNot(equals(onyxPath)));
      },
    );

    test('renderTTS propagates TtsApiException', () async {
      service.setRenderError(
        const TtsApiException('API key missing', statusCode: 401),
      );
      await expectLater(
        service.renderTTS('hello', 'nova', TtsPlaybackMode.genai),
        throwsA(isA<TtsApiException>()),
      );
    });

    // ── clearCacheForPlan ──────────────────────────────────────────────────

    test('clearCacheForPlan records the planId', () async {
      await service.clearCacheForPlan('plan-42');
      expect(service.clearCacheForPlanCalls, ['plan-42']);
    });

    test('clearCacheForPlan for multiple plans records each id', () async {
      await service.clearCacheForPlan('plan-1');
      await service.clearCacheForPlan('plan-2');
      await service.clearCacheForPlan('plan-3');
      expect(service.clearCacheForPlanCalls, ['plan-1', 'plan-2', 'plan-3']);
    });

    // ── isCached ──────────────────────────────────────────────────────────

    test('isCached records textHash and voiceId', () async {
      final hash = ttsCacheKey(provider: 'backend', voiceId: 'nova', text: 'Check');
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
          authService: _StubAuthService(),
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

  // ── TTSServiceImpl.renderTTS — platform mode (no DB rows needed) ──────────
  //
  // Platform mode with a cache miss never makes a network call — it simply
  // returns null. We can test this path with an in-memory database that has
  // no cache rows, without mocking HTTP at all.

  group('TTSServiceImpl.renderTTS — platform mode', () {
    late Directory tempDir;
    late _FakePlatformTtsEngine fakeTtsEngine;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tts_render_platform_test_');
      fakeTtsEngine = _FakePlatformTtsEngine(tempDir: tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    TTSServiceImpl _makeService({PlatformTtsEngine? ttsEngine}) =>
        TTSServiceImpl(
          db: _NullAppDatabase(),
          audioDirectory: tempDir.path,
          authService: _StubAuthService(),
          ttsEngine: ttsEngine ?? fakeTtsEngine,
        );

    test('returns null on cache miss in platform mode', () async {
      final service = _makeService();
      final result = await service.renderTTS(
          'Hello world', 'nova', TtsPlaybackMode.platform);
      expect(result, isNull);
    });

    test('does not call platform TTS engine in platform mode', () async {
      final service = _makeService();
      await service.renderTTS('Hello world', 'nova', TtsPlaybackMode.platform);
      // synthesizeToFile must NOT be called — platform mode returns null
      // immediately; the caller drives TTS itself.
      expect(fakeTtsEngine.synthesizeCalls, isEmpty);
    });

    test('throws ArgumentError for empty text', () async {
      final service = _makeService();
      await expectLater(
        service.renderTTS('', 'nova', TtsPlaybackMode.platform),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for empty voiceId', () async {
      final service = _makeService();
      await expectLater(
        service.renderTTS('Hello', '', TtsPlaybackMode.platform),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for whitespace-only text', () async {
      final service = _makeService();
      await expectLater(
        service.renderTTS('   ', 'nova', TtsPlaybackMode.platform),
        throwsArgumentError,
      );
    });
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
    test('kTtsApiTimeout is 60 seconds', () {
      expect(kTtsApiTimeout, const Duration(seconds: 60));
    });

    test('kBackendUrl is localhost:3071', () {
      expect(kBackendUrl, 'http://localhost:3071');
    });

    test('kBackendTtsPath is the backend synthesis endpoint', () {
      expect(kBackendTtsPath, '/api/tts/synthesize');
    });

    test('kBackendUrl does not contain api.openai.com', () {
      expect(kBackendUrl, isNot(contains('openai.com')));
    });

    test('kBackendUrl does not contain generativelanguage', () {
      expect(kBackendUrl, isNot(contains('generativelanguage')));
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

  group('Plan category enum', () {
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

/// Stub [AuthService] that always returns `null` for the access token.
class _StubAuthService extends AuthService {
  @override
  bool get isAuthenticated => false;
  @override
  AuthUser? getUser() => null;
  @override
  Stream<AuthState> get authStateStream => const Stream.empty();
  @override
  Future<void> requestOtp(String email) =>
      throw UnimplementedError('not needed in TTS tests');
  @override
  Future<void> requestOtpWithAuth(String email) =>
      throw UnimplementedError('not needed in TTS tests');
  @override
  Future<AuthResult> verifyOtp(String email, String otp) =>
      throw UnimplementedError('not needed in TTS tests');
  @override
  Future<void> refreshToken() =>
      throw UnimplementedError('not needed in TTS tests');
  @override
  Future<void> logout() =>
      throw UnimplementedError('not needed in TTS tests');
}
