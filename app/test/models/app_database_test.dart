import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/assets/static_voice_catalog.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/database/tables/provider_catalog_table.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tts_provider_config.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase schema (REQ-020)', () {
    test('database opens and creates all tables', () async {
      // All tables should be accessible without throwing
      await db.select(db.plansTable).get();
      await db.select(db.ttsCacheTable).get();
      await db.select(db.executionStateTable).get();
      await db.select(db.appSettingsTable).get();
      await db.select(db.providerCatalogTable).get();
    });

    test('schema version is 4', () {
      expect(db.schemaVersion, equals(4));
    });
  });

  group('PlansTable', () {
    test('inserts and retrieves a Plan row', () async {
      final now = DateTime.now();
      final id = await db.into(db.plansTable).insert(
            PlansTableCompanion.insert(
              name: 'Morning Yoga',
              category: Value(PlanCategory.yoga.name),
              defaultVoice: const Value('nova'),
              steps: const Value([]),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final rows = await db.select(db.plansTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, equals(id));
      expect(rows.first.name, equals('Morning Yoga'));
      expect(rows.first.category, equals('yoga'));
      expect(rows.first.defaultVoice, equals('nova'));
      expect(rows.first.steps, isEmpty);
      expect(rows.first.description, isNull);
      expect(rows.first.lastUsedAt, isNull);
    });

    test('stores steps as JSON via StepListConverter', () async {
      const steps = [
        PlanStep.say(id: 's1', text: 'Begin'),
        PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
        PlanStep.repeat(
          id: 'r1',
          count: 3,
          children: [PlanStep.say(id: 's2', text: 'Breathe')],
        ),
      ];
      final now = DateTime.now();
      await db.into(db.plansTable).insert(
            PlansTableCompanion.insert(
              name: 'Breathing Plan',
              category: Value(PlanCategory.meditation.name),
              defaultVoice: const Value('shimmer'),
              steps: Value(steps),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final row = (await db.select(db.plansTable).get()).first;
      expect(row.steps, hasLength(3));
      expect(row.steps[0], isA<SayStep>());
      expect(row.steps[1], isA<WaitStep>());
      expect(row.steps[2], isA<RepeatStep>());
    });

    test('stores tags as JSON via StringListConverter', () async {
      final now = DateTime.now();
      final tags = ['morning', 'yoga', 'beginner'];
      await db.into(db.plansTable).insert(
            PlansTableCompanion.insert(
              name: 'Tag Test Plan',
              category: Value(PlanCategory.yoga.name),
              defaultVoice: const Value('nova'),
              steps: const Value([]),
              tags: Value(tags),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final row = (await db.select(db.plansTable).get()).first;
      expect(row.tags, equals(tags));
    });

    test('nullable description and lastUsedAt persist as null', () async {
      final now = DateTime.now();
      await db.into(db.plansTable).insert(
            PlansTableCompanion.insert(
              name: 'Minimal Plan',
              category: Value(PlanCategory.custom.name),
              defaultVoice: const Value('nova'),
              steps: const Value([]),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final row = (await db.select(db.plansTable).get()).first;
      expect(row.description, isNull);
      expect(row.lastUsedAt, isNull);
    });

    test('id auto-increments across inserts', () async {
      final now = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await db.into(db.plansTable).insert(
              PlansTableCompanion.insert(
                name: 'Plan $i',
                category: Value(PlanCategory.custom.name),
                defaultVoice: const Value('nova'),
                steps: const Value([]),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      final rows = await db.select(db.plansTable).get();
      final ids = rows.map((r) => r.id).toList();
      expect(ids, equals([1, 2, 3]));
    });

    test('deletes a plan row', () async {
      final now = DateTime.now();
      final id = await db.into(db.plansTable).insert(
            PlansTableCompanion.insert(
              name: 'To Delete',
              category: Value(PlanCategory.custom.name),
              defaultVoice: const Value('nova'),
              steps: const Value([]),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      expect((await db.select(db.plansTable).get()), hasLength(1));

      await (db.delete(db.plansTable)
            ..where((t) => t.id.equals(id)))
          .go();
      expect((await db.select(db.plansTable).get()), isEmpty);
    });
  });

  group('TtsCacheTable', () {
    test('inserts and retrieves a cache row', () async {
      final now = DateTime.now();
      await db.into(db.ttsCacheTable).insert(
            TtsCacheTableCompanion.insert(
              textHash: 'abc123',
              voiceId: 'nova',
              filePath: '/data/tts/abc123.m4a',
              createdAt: Value(now),
            ),
          );

      final rows = await db.select(db.ttsCacheTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.textHash, equals('abc123'));
      expect(rows.first.voiceId, equals('nova'));
      expect(rows.first.filePath, equals('/data/tts/abc123.m4a'));
    });

    test('textHash has unique constraint', () async {
      final now = DateTime.now();
      await db.into(db.ttsCacheTable).insert(
            TtsCacheTableCompanion.insert(
              textHash: 'uniqueHash',
              voiceId: 'nova',
              filePath: '/data/tts/1.m4a',
              createdAt: Value(now),
            ),
          );

      // Inserting the same hash should throw
      expect(
        () async => db.into(db.ttsCacheTable).insert(
              TtsCacheTableCompanion.insert(
                textHash: 'uniqueHash',
                voiceId: 'shimmer',
                filePath: '/data/tts/2.m4a',
                createdAt: Value(now),
              ),
            ),
        throwsException,
      );
    });
  });

  group('ExecutionStateTable (REQ-018)', () {
    Future<int> insertPlan(DateTime now) => db.into(db.plansTable).insert(
          PlansTableCompanion.insert(
            name: 'Test Plan',
            category: Value(PlanCategory.custom.name),
            defaultVoice: const Value('nova'),
            steps: const Value([]),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    test('inserts and retrieves execution state', () async {
      final now = DateTime.now();
      final planId = await insertPlan(now);

      await db.into(db.executionStateTable).insert(
            ExecutionStateTableCompanion.insert(
              planId: planId,
              status: const Value('running'),
              savedAt: Value(now),
            ),
          );

      final rows = await db.select(db.executionStateTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.planId, equals(planId));
      expect(rows.first.status, equals('running'));
      expect(rows.first.currentStepIndex, equals(0));
      expect(rows.first.elapsedMs, equals(0));
    });

    test('stores currentStepIndex, elapsedMs, ambientPositionMs', () async {
      final now = DateTime.now();
      final planId = await insertPlan(now);

      await db.into(db.executionStateTable).insert(
            ExecutionStateTableCompanion.insert(
              planId: planId,
              currentStepIndex: Value(5),
              elapsedMs: Value(12500),
              ambientPositionMs: Value(8000),
              status: const Value('paused'),
              savedAt: Value(now),
            ),
          );

      final row = (await db.select(db.executionStateTable).get()).first;
      expect(row.currentStepIndex, equals(5));
      expect(row.elapsedMs, equals(12500));
      expect(row.ambientPositionMs, equals(8000));
    });

    test('stores repeatCounters as JSON map string', () async {
      final now = DateTime.now();
      final planId = await insertPlan(now);

      await db.into(db.executionStateTable).insert(
            ExecutionStateTableCompanion.insert(
              planId: planId,
              repeatCounters: Value('{"r1": 2, "r2": 0}'),
              status: const Value('running'),
              savedAt: Value(now),
            ),
          );

      final row = (await db.select(db.executionStateTable).get()).first;
      expect(row.repeatCounters, equals('{"r1": 2, "r2": 0}'));
    });

    test('cascade deletes execution state when plan is deleted', () async {
      final now = DateTime.now();
      final planId = await insertPlan(now);

      await db.into(db.executionStateTable).insert(
            ExecutionStateTableCompanion.insert(
              planId: planId,
              status: const Value('running'),
              savedAt: Value(now),
            ),
          );
      expect(
        (await db.select(db.executionStateTable).get()),
        hasLength(1),
      );

      await (db.delete(db.plansTable)
            ..where((t) => t.id.equals(planId)))
          .go();

      expect(
        (await db.select(db.executionStateTable).get()),
        isEmpty,
      );
    });

    test('status can be running, paused, or completed', () async {
      final now = DateTime.now();

      for (final status in ['running', 'paused', 'completed']) {
        final planId = await insertPlan(now);
        await db.into(db.executionStateTable).insert(
              ExecutionStateTableCompanion.insert(
                planId: planId,
                status: Value(status),
                savedAt: Value(now),
              ),
            );
      }

      final rows = await db.select(db.executionStateTable).get();
      final statuses = rows.map((r) => r.status).toList();
      expect(statuses, containsAll(['running', 'paused', 'completed']));
    });
  });

  group('AppSettingsTable', () {
    test('inserts and retrieves a setting', () async {
      final now = DateTime.now();
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(
              key: 'onboarding_complete',
              value: 'true',
              updatedAt: Value(now),
            ),
          );

      final rows = await db.select(db.appSettingsTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.key, equals('onboarding_complete'));
      expect(rows.first.value, equals('true'));
    });

    test('key has unique constraint', () async {
      final now = DateTime.now();
      await db.into(db.appSettingsTable).insert(
            AppSettingsTableCompanion.insert(
              key: 'theme',
              value: 'dark',
              updatedAt: Value(now),
            ),
          );

      expect(
        () async => db.into(db.appSettingsTable).insert(
              AppSettingsTableCompanion.insert(
                key: 'theme',
                value: 'light',
                updatedAt: Value(now),
              ),
            ),
        throwsException,
      );
    });
  });

  // ── ProviderCatalogTable (TASK-020) ────────────────────────────────────────

  /// Minimal valid catalog JSON matching the /api/tts/providers response shape.
  String _minimalCatalogJson() => jsonEncode({
        'providers': [
          {
            'id': 'gemini',
            'label': 'Gemini TTS',
            'voices': [
              {'id': 'aoede', 'label': 'Aoede'},
              {'id': 'zephyr', 'label': 'Zephyr'},
            ],
            'locales': [
              {'id': 'enUS', 'label': 'English (US)'},
            ],
            'voiceMap': <String, String>{},
          },
          {
            'id': 'kokoro',
            'label': 'Kokoro TTS',
            'voices': [
              {'id': 'af_heart', 'label': 'Heart (Female, US)'},
              {'id': 'am_adam', 'label': 'Adam (Male, US)'},
            ],
            'locales': [
              {'id': 'en-us', 'label': 'English (US)'},
            ],
            'voiceMap': <String, String>{'aoede': 'af_heart'},
          },
        ],
      });

  group('ProviderCatalogTable (TASK-020)', () {
    test('table is accessible on a fresh database', () async {
      final rows = await db.select(db.providerCatalogTable).get();
      expect(rows, isEmpty, reason: 'catalog table should start empty');
    });

    test('inserts and retrieves a catalog row with id=1', () async {
      final now = DateTime.now().toUtc();
      final json = _minimalCatalogJson();

      await db.into(db.providerCatalogTable).insert(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: json,
              fetchedAt: now,
            ),
          );

      final rows = await db.select(db.providerCatalogTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, equals(1));
      expect(rows.first.catalogJson, equals(json));
      expect(rows.first.fetchedAt.millisecondsSinceEpoch,
          closeTo(now.millisecondsSinceEpoch, 1000));
    });

    test('INSERT OR REPLACE replaces the row when inserting id=1 again',
        () async {
      final now = DateTime.now().toUtc();
      final json1 = _minimalCatalogJson();
      final json2 = jsonEncode({'providers': []});

      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: json1,
              fetchedAt: now,
            ),
          );
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: json2,
              fetchedAt: now,
            ),
          );

      final rows = await db.select(db.providerCatalogTable).get();
      expect(rows, hasLength(1),
          reason: 'INSERT OR REPLACE should keep only one row');
      expect(rows.first.catalogJson, equals(json2),
          reason: 'second insert should replace the first');
    });

    test(
        'JSON round-trip: save catalog → load from DB → verify structure matches',
        () async {
      final now = DateTime.now().toUtc();
      final originalJson = _minimalCatalogJson();

      // Persist to DB.
      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: originalJson,
              fetchedAt: now,
            ),
          );

      // Load from DB.
      final row = await (db.select(db.providerCatalogTable)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();
      expect(row, isNotNull);

      // Deserialise and verify structure.
      final decoded =
          TtsProvidersResponse.fromJson(jsonDecode(row!.catalogJson) as Map<String, dynamic>);
      expect(decoded.providers, hasLength(2));
      expect(decoded.providers.map((p) => p.id),
          containsAll(['gemini', 'kokoro']));

      final gemini = decoded.providers.firstWhere((p) => p.id == 'gemini');
      expect(gemini.voices.map((v) => v.id), containsAll(['aoede', 'zephyr']));
      expect(gemini.locales.map((l) => l.id), contains('enUS'));

      final kokoro = decoded.providers.firstWhere((p) => p.id == 'kokoro');
      expect(
          kokoro.voices.map((v) => v.id), containsAll(['af_heart', 'am_adam']));
      expect(kokoro.voiceMap['aoede'], equals('af_heart'));
    });

    test(
        'static fallback catalog is non-empty and contains gemini and kokoro',
        () {
      // Verify the bundled kStaticVoiceCatalog used when the DB is empty and
      // the network is unavailable.
      expect(kStaticVoiceCatalog, isNotEmpty);
      final ids = kStaticVoiceCatalog.map((p) => p.id).toList();
      expect(ids, containsAll(['gemini', 'kokoro']));
    });

    test(
        'static fallback catalog can be serialised and round-tripped through JSON',
        () {
      // Serialise the static catalog the same way ProviderCatalogManager does.
      final encoded = jsonEncode({
        'providers': kStaticVoiceCatalog
            .map((p) => {
                  'id': p.id,
                  'label': p.label,
                  'voices': p.voices
                      .map((v) => {
                            'id': v.id,
                            'label': v.label,
                            if (v.gender != null) 'gender': v.gender,
                          })
                      .toList(),
                  'locales': p.locales
                      .map((l) => {'id': l.id, 'label': l.label})
                      .toList(),
                  'voiceMap': p.voiceMap,
                })
            .toList(),
      });

      final decoded =
          TtsProvidersResponse.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

      expect(decoded.providers.length, equals(kStaticVoiceCatalog.length));
      for (var i = 0; i < kStaticVoiceCatalog.length; i++) {
        expect(decoded.providers[i].id, equals(kStaticVoiceCatalog[i].id));
        expect(decoded.providers[i].voices.length,
            equals(kStaticVoiceCatalog[i].voices.length));
      }
    });

    test('fetchedAt is stored and retrieved as UTC', () async {
      final utcNow = DateTime.now().toUtc();

      await db.into(db.providerCatalogTable).insertOnConflictUpdate(
            ProviderCatalogTableCompanion.insert(
              id: const Value(1),
              catalogJson: '{"providers":[]}',
              fetchedAt: utcNow,
            ),
          );

      final row = await (db.select(db.providerCatalogTable)
            ..where((t) => t.id.equals(1)))
          .getSingleOrNull();

      expect(row, isNotNull);
      // Drift stores DateTime as UTC epoch ms — verify round-trip precision.
      expect(row!.fetchedAt.millisecondsSinceEpoch,
          closeTo(utcNow.millisecondsSinceEpoch, 1000));
    });

    test('default id value is 1 when omitted from insert', () async {
      final now = DateTime.now().toUtc();

      // Insert without specifying id — should default to 1.
      await db.into(db.providerCatalogTable).insert(
            ProviderCatalogTableCompanion.insert(
              catalogJson: '{"providers":[]}',
              fetchedAt: now,
            ),
          );

      final rows = await db.select(db.providerCatalogTable).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, equals(1));
    });
  });
}
