import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';

part 'app_settings.g.dart';

/// String keys for the [AppSettingsTable].
abstract final class AppSettingsKeys {
  /// Set to `'true'` once the user completes the onboarding flow.
  static const String hasCompletedOnboarding = 'has_completed_onboarding';

  /// Set to `'true'` once the starter plan library has been seeded into the
  /// database for the first time.
  static const String hasSeededStarterPlans = 'has_seeded_starter_plans';

  // ── User-facing Settings ────────────────────────────────────────────────

  /// The default TTS voice name (a [PlanVoice] enum `.name` string).
  ///
  /// Defaults to `'nova'` when absent.
  static const String defaultVoice = 'default_voice';

  /// Ambient audio master volume as a decimal string in [0.0, 1.0].
  ///
  /// Defaults to `'0.7'` when absent.
  static const String ambientVolume = 'ambient_volume';

  /// Voice/TTS master volume as a decimal string in [0.0, 1.0].
  ///
  /// Defaults to `'1.0'` when absent.
  static const String voiceVolume = 'voice_volume';

  /// Whether to play a notification sound on `notify` steps. `'true'` or `'false'`.
  ///
  /// Defaults to `'true'` when absent.
  static const String notificationSound = 'notification_sound';

  /// Whether to vibrate on `notify` steps. `'true'` or `'false'`.
  ///
  /// Defaults to `'true'` when absent.
  static const String vibration = 'vibration';

  /// Set to `'true'` once the battery-optimisation prompt has been dismissed.
  ///
  /// Prevents the per-OEM instructions card from appearing again.
  static const String batteryPromptDismissed = 'battery_prompt_dismissed';
}

/// High-level interface for reading and writing app-wide settings stored in
/// the [AppSettingsTable] (a key/value SQLite table).
///
/// All reads and writes are asynchronous (dispatched to the background Drift
/// isolate). Consumers can call [AppSettings.read] for one-off checks or
/// watch the Drift table directly for reactive updates.
class AppSettings {
  const AppSettings(this._db);

  final AppDatabase _db;

  // ────────────────────────────────────────────────────────────────────────────
  // Generic read/write/watch
  // ────────────────────────────────────────────────────────────────────────────

  /// Returns the stored string value for [key], or null if absent.
  Future<String?> read(String key) async {
    final row = await (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Returns a reactive [Stream] that emits the value for [key] whenever it
  /// changes in the database, or `null` when the key has not been set.
  ///
  /// The stream emits the current value immediately upon subscription, then
  /// emits again whenever a write to the [AppSettingsTable] is committed.
  Stream<String?> watch(String key) {
    return (_db.select(_db.appSettingsTable)
          ..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  /// Writes (upserts) [value] for [key].
  Future<void> write(String key, String value) async {
    await _db.into(_db.appSettingsTable).insertOnConflictUpdate(
          AppSettingsTableCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Convenience helpers
  // ────────────────────────────────────────────────────────────────────────────

  /// Returns `true` when the user has completed the onboarding flow.
  Future<bool> hasCompletedOnboarding() async {
    final val = await read(AppSettingsKeys.hasCompletedOnboarding);
    return val == 'true';
  }

  /// Marks onboarding as completed.
  Future<void> setHasCompletedOnboarding() =>
      write(AppSettingsKeys.hasCompletedOnboarding, 'true');

  /// Returns `true` when the starter plans have already been seeded.
  Future<bool> hasSeededStarterPlans() async {
    final val = await read(AppSettingsKeys.hasSeededStarterPlans);
    return val == 'true';
  }

  /// Marks starter plans as seeded.
  Future<void> setHasSeededStarterPlans() =>
      write(AppSettingsKeys.hasSeededStarterPlans, 'true');
}

// ────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ────────────────────────────────────────────────────────────────────────────

/// Singleton [AppSettings] provider.
///
/// [keepAlive: true] ensures the settings object is never garbage-collected
/// for the lifetime of the [ProviderScope].
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return AppSettings(db);
}
