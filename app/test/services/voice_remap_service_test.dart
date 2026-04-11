/// Unit tests for [VoiceRemapService].
///
/// ## Test strategy
///
/// [VoiceRemapService] depends on [ProviderCatalogManager], [PlanRepository],
/// and [AppSettings]. Rather than full integration tests:
///
/// - [_FakeCatalogManager] overrides [ProviderCatalogManager] with a static
///   catalog — no DB or HTTP.
/// - [_FakePlanRepository] implements [PlanRepository] in-memory.
/// - [AppSettings] uses a real in-memory Drift DB so we don't need to stub
///   the entire read/write API.
///
/// ## Running
/// ```
/// flutter test test/services/voice_remap_service_test.dart
/// ```
library voice_remap_service_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/provider_catalog_manager.dart';
import 'package:instructor/services/voice_remap_service.dart';

// ── Minimal 3-provider test catalog ──────────────────────────────────────────

final _testCatalog = [
  const TtsProviderConfig(
    id: 'gemini',
    label: 'Google Gemini TTS',
    voices: [
      TtsVoiceOption(id: 'aoede', label: 'Aoede'),
      TtsVoiceOption(id: 'zephyr', label: 'Zephyr'),
      TtsVoiceOption(id: 'charon', label: 'Charon'),
    ],
    locales: [
      TtsLocaleOption(id: 'enUS', label: 'English (US)'),
      TtsLocaleOption(id: 'enGB', label: 'English (UK)'),
    ],
    voiceMap: {
      'af_heart': 'aoede',
      'af_sky': 'zephyr',
      'am_adam': 'charon',
      'EXAVITQu4vr4xnSDxMaL': 'aoede',
    },
  ),
  const TtsProviderConfig(
    id: 'kokoro',
    label: 'Kokoro TTS',
    voices: [
      TtsVoiceOption(id: 'af_heart', label: 'Heart (Female, US)'),
      TtsVoiceOption(id: 'af_sky', label: 'Sky (Female, US)'),
      TtsVoiceOption(id: 'am_adam', label: 'Adam (Male, US)'),
    ],
    locales: [
      TtsLocaleOption(id: 'en-us', label: 'English (US)'),
      TtsLocaleOption(id: 'en-gb', label: 'English (UK)'),
    ],
    voiceMap: {
      'aoede': 'af_heart',
      'zephyr': 'af_sky',
      'charon': 'am_adam',
      'EXAVITQu4vr4xnSDxMaL': 'af_heart',
    },
  ),
  const TtsProviderConfig(
    id: 'elevenlabs',
    label: 'ElevenLabs',
    voices: [
      TtsVoiceOption(id: 'EXAVITQu4vr4xnSDxMaL', label: 'Sarah (Female)'),
      TtsVoiceOption(id: 'JBFqnCBsd6RMkjVDRZzb', label: 'George (Male)'),
    ],
    locales: [
      TtsLocaleOption(id: 'en', label: 'English'),
    ],
    voiceMap: {
      'aoede': 'EXAVITQu4vr4xnSDxMaL',
      'af_heart': 'EXAVITQu4vr4xnSDxMaL',
      'am_adam': 'JBFqnCBsd6RMkjVDRZzb',
    },
  ),
];

// ── Fake implementations ──────────────────────────────────────────────────────

/// Fake [ProviderCatalogManager] using a static catalog — no DB or HTTP.
///
/// Overrides the minimal subset of methods that [VoiceRemapService] calls.
class _FakeCatalogManager extends ProviderCatalogManager {
  _FakeCatalogManager({List<TtsProviderConfig>? catalog})
      : _catalog = catalog ?? _testCatalog,
        super(db: AppDatabase.forTesting(NativeDatabase.memory()));

  final List<TtsProviderConfig> _catalog;

  @override
  Future<List<TtsProviderConfig>> getCachedCatalog() async => _catalog;

  @override
  Future<List<TtsProviderConfig>> fetchAndCacheCatalog() async => _catalog;

  @override
  Future<List<TtsVoiceOption>> getVoicesForProvider(String providerId) async {
    final p = _catalog.where((c) => c.id == providerId).firstOrNull;
    return p?.voices ?? [];
  }

  @override
  Future<bool> isVoiceValidForProvider(
      String voiceId, String providerId) async {
    final voices = await getVoicesForProvider(providerId);
    return voices.any((v) => v.id == voiceId);
  }
}

/// Fake [PlanRepository] that records [remapPlanVoices] calls.
class _FakePlanRepository implements PlanRepository {
  final List<Map<String, String>> remapCalls = [];

  @override
  Future<void> remapPlanVoices(Map<String, String> voiceMap) async {
    remapCalls.add(Map.from(voiceMap));
  }

  @override
  Future<int> createPlan(Plan plan) async => 1;
  @override
  Future<void> updatePlan(int id, Plan plan) async {}
  @override
  Future<void> deletePlan(int id) async {}
  @override
  Future<Plan?> getPlanById(int id) async => null;
  @override
  Stream<List<Plan>> watchAllPlans({
    String? searchQuery,
    PlanCategory? category,
  }) =>
      Stream.value([]);
  @override
  Future<void> updateLastUsed(int id) async {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Opens a fresh in-memory [AppDatabase] for each test.
AppDatabase _openDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Writes a key/value setting using [AppSettings] (the public API).
Future<void> _setKey(AppDatabase db, String key, String value) =>
    AppSettings(db).write(key, value);

/// Returns the stored value for [key] using [AppSettings].
Future<String?> _getKey(AppDatabase db, String key) =>
    AppSettings(db).read(key);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('VoiceRemapService — remapVoicesForProvider', () {
    late AppDatabase db;

    setUp(() => db = _openDb());
    tearDown(() async => db.close());

    test('remaps Kokoro default voice (af_heart) to Gemini equivalent (aoede)',
        () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      expect(result.newDefaultVoice, 'aoede');
      expect(result.newDefaultVoiceLabel, 'Aoede');
    });

    test('remaps Gemini default voice (aoede) to Kokoro equivalent (af_heart)',
        () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'aoede');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'gemini');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'gemini',
        newProvider: 'kokoro',
      );

      expect(result.newDefaultVoice, 'af_heart');
      expect(result.newDefaultVoiceLabel, 'Heart (Female, US)');
    });

    test('shows human-readable label for ElevenLabs — not raw opaque ID',
        () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'aoede');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'en');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'gemini');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'gemini',
        newProvider: 'elevenlabs',
      );

      expect(result.newDefaultVoice, 'EXAVITQu4vr4xnSDxMaL');
      expect(result.newDefaultVoiceLabel, 'Sarah (Female)',
          reason: 'Must use human-readable label, not raw ElevenLabs voice ID');
    });

    test('calls planRepository.remapPlanVoices with the target voice map',
        () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');

      final repo = _FakePlanRepository();
      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: repo,
        settings: AppSettings(db),
      );

      await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      expect(repo.remapCalls, hasLength(1));
      expect(repo.remapCalls.first, containsPair('af_heart', 'aoede'));
    });

    test('persists new provider setting to DB', () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      final storedProvider = await _getKey(db, AppSettingsKeys.ttsProvider);
      expect(storedProvider, 'gemini');
    });

    test('persists new voice to DB', () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      final storedVoice = await _getKey(db, AppSettingsKeys.defaultVoice);
      expect(storedVoice, 'aoede');
    });

    test('locale remains unchanged when new provider supports current locale',
        () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini', // Gemini has 'enUS'
      );

      expect(result.localeChanged, isFalse);
      expect(result.newLocale, 'enUS');
    });

    test('snackbar message includes the human-readable voice name', () async {
      await _setKey(db, AppSettingsKeys.defaultVoice, 'af_heart');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      expect(result.snackbarMessage, contains('Aoede'));
    });

    test('falls back to first provider voice when voiceMap lacks mapping',
        () async {
      // Catalog where Gemini has no voiceMap entries.
      final catalog = [
        const TtsProviderConfig(
          id: 'gemini',
          label: 'Gemini',
          voices: [
            TtsVoiceOption(id: 'aoede', label: 'Aoede'),
          ],
          locales: [TtsLocaleOption(id: 'enUS', label: 'English (US)')],
          voiceMap: <String, String>{}, // empty — no mappings
        ),
      ];

      await _setKey(db, AppSettingsKeys.defaultVoice, 'am_echo');
      await _setKey(db, AppSettingsKeys.ttsLocale, 'enUS');
      await _setKey(db, AppSettingsKeys.ttsProvider, 'kokoro');

      final service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(catalog: catalog),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );

      final result = await service.remapVoicesForProvider(
        oldProvider: 'kokoro',
        newProvider: 'gemini',
      );

      // Falls back to first available voice in provider.
      expect(result.newDefaultVoice, 'aoede');
    });
  });

  group('VoiceRemapService — findClosestLocale', () {
    // findClosestLocale is a pure function — no DB needed.
    late VoiceRemapService service;

    setUp(() {
      final db = _openDb();
      service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(db),
      );
    });

    const geminiConfig = TtsProviderConfig(
      id: 'gemini',
      label: 'Gemini',
      voices: [],
      locales: [
        TtsLocaleOption(id: 'enUS', label: 'English (US)'),
        TtsLocaleOption(id: 'enGB', label: 'English (UK)'),
        TtsLocaleOption(id: 'enIN', label: 'English (India)'),
      ],
      voiceMap: {},
    );

    test('returns exact match when locale is supported', () {
      expect(service.findClosestLocale('enUS', geminiConfig), 'enUS');
      expect(service.findClosestLocale('enGB', geminiConfig), 'enGB');
      expect(service.findClosestLocale('enIN', geminiConfig), 'enIN');
    });

    test('normalises hyphenated locale (en-US → enUS)', () {
      expect(service.findClosestLocale('en-US', geminiConfig), 'enUS');
      expect(service.findClosestLocale('en-GB', geminiConfig), 'enGB');
    });

    test('falls back to same language prefix when exact locale absent', () {
      // 'enCA' is not in the list — should return an 'en*' locale.
      final result = service.findClosestLocale('enCA', geminiConfig);
      expect(result.toLowerCase().startsWith('en'), isTrue,
          reason: 'Language prefix fallback should return an English locale');
    });

    test('falls back to first locale when language prefix has no match', () {
      const frOnlyConfig = TtsProviderConfig(
        id: 'test',
        label: 'Test',
        voices: [],
        locales: [
          TtsLocaleOption(id: 'frFR', label: 'French (France)'),
        ],
        voiceMap: {},
      );
      final result = service.findClosestLocale('enUS', frOnlyConfig);
      expect(result, 'frFR');
    });

    test('returns currentLocale unchanged when provider has no locales', () {
      const emptyConfig = TtsProviderConfig(
        id: 'empty',
        label: 'Empty',
        voices: [],
        locales: [],
        voiceMap: {},
      );
      expect(service.findClosestLocale('enUS', emptyConfig), 'enUS');
    });
  });

  group('VoiceRemapService — validateVoiceForProvider', () {
    late VoiceRemapService service;

    setUp(() {
      service = VoiceRemapService(
        catalogManager: _FakeCatalogManager(),
        planRepository: _FakePlanRepository(),
        settings: AppSettings(_openDb()),
      );
    });

    const kokoroConfig = TtsProviderConfig(
      id: 'kokoro',
      label: 'Kokoro',
      voices: [
        TtsVoiceOption(id: 'af_heart', label: 'Heart'),
        TtsVoiceOption(id: 'am_adam', label: 'Adam'),
      ],
      locales: [],
      voiceMap: {},
    );

    test('returns true for voice present in provider list', () {
      expect(service.validateVoiceForProvider('af_heart', kokoroConfig), isTrue);
      expect(service.validateVoiceForProvider('am_adam', kokoroConfig), isTrue);
    });

    test('returns false for voice absent from provider list', () {
      expect(
          service.validateVoiceForProvider('aoede', kokoroConfig), isFalse);
      expect(
          service.validateVoiceForProvider('unknown_voice', kokoroConfig), isFalse);
    });
  });
}
