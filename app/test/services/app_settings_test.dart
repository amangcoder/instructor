/// Unit tests for AppSettings (TASK-060).
///
/// Tests cover:
/// 1. plansMigratedV2 key constant value
/// 2. plansMigratedV2() returns false by default (absent key)
/// 3. setPlansMigratedV2() writes 'true'
/// 4. plansMigratedV2() returns true after setPlansMigratedV2()
/// 5. Generic read/write round-trip for the key
///
/// ## Running
/// ```
/// flutter test test/services/app_settings_test.dart
/// ```
library app_settings_test;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/database/app_database.dart';
import 'package:instructor/services/app_settings.dart';

void main() {
  late AppDatabase db;
  late AppSettings settings;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = AppSettings(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── AppSettingsKeys.plansMigratedV2 ────────────────────────────────────────

  group('AppSettingsKeys.plansMigratedV2 (TASK-060)', () {
    test('key constant has expected string value', () {
      expect(
        AppSettingsKeys.plansMigratedV2,
        equals('plans_migrated_v2'),
      );
    });
  });

  // ── AppSettings.plansMigratedV2() ──────────────────────────────────────────

  group('AppSettings.plansMigratedV2() (TASK-060)', () {
    test('returns false when key is absent (default)', () async {
      final result = await settings.plansMigratedV2();
      expect(result, isFalse,
          reason: 'plansMigratedV2 should default to false when not set');
    });

    test('returns false when key is explicitly set to "false"', () async {
      await settings.write(AppSettingsKeys.plansMigratedV2, 'false');
      final result = await settings.plansMigratedV2();
      expect(result, isFalse);
    });

    test('returns true after setPlansMigratedV2()', () async {
      await settings.setPlansMigratedV2();
      final result = await settings.plansMigratedV2();
      expect(result, isTrue);
    });

    test('read() returns "true" after setPlansMigratedV2()', () async {
      await settings.setPlansMigratedV2();
      final raw = await settings.read(AppSettingsKeys.plansMigratedV2);
      expect(raw, equals('true'));
    });

    test('setting is idempotent — calling setPlansMigratedV2 twice is safe',
        () async {
      await settings.setPlansMigratedV2();
      await settings.setPlansMigratedV2(); // second call should not throw
      final result = await settings.plansMigratedV2();
      expect(result, isTrue);
    });

    test('generic write("plans_migrated_v2", "true") is readable via plansMigratedV2()',
        () async {
      await settings.write(AppSettingsKeys.plansMigratedV2, 'true');
      final result = await settings.plansMigratedV2();
      expect(result, isTrue);
    });
  });
}
