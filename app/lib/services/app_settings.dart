import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/database/app_database.dart';

part 'app_settings.g.dart';

/// Backend base URL, set at build time via `--dart-define=BACKEND_URL=<url>`.
///
/// Defaults to `http://localhost:3071` for local development.
/// Override at build time:
///   flutter run --dart-define=BACKEND_URL=https://api.example.com
const String kBackendUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://cpsximh8w4.execute-api.ap-south-1.amazonaws.com/default',
);

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
  /// Defaults to `'aoede'` when absent.
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

  /// Speech playback speed as a decimal string in [0.5, 2.0].
  ///
  /// Defaults to `'1.0'` (normal speed) when absent.
  static const String speechRate = 'speech_rate';

  /// The TTS locale / accent (a [TtsLocale] enum `.name` string).
  ///
  /// Defaults to `'enIN'` (English India) when absent.
  static const String ttsLocale = 'tts_locale';

  /// Set to `'true'` once the battery-optimisation prompt has been dismissed.
  ///
  /// Prevents the per-OEM instructions card from appearing again.
  static const String batteryPromptDismissed = 'battery_prompt_dismissed';

  /// Backend x-api-key for authenticating TTS synthesis requests.
  ///
  /// Sent as the `x-api-key` header in POST /api/tts/synthesize requests.
  /// When absent the header is omitted (useful for dev servers without auth).
  static const String backendApiKey = 'backend_api_key';

  /// App colour-scheme preference: `'system'`, `'light'`, or `'dark'`.
  ///
  /// Defaults to `'system'` when absent.
  static const String themeMode = 'theme_mode';

  // ── Profile Personalization ────────────────────────────────────────────

  /// User's activity level for personalized recommendations.
  ///
  /// Valid values: `'beginner'`, `'intermediate'`, or `'advanced'`.
  /// Empty string when unset (default).
  static const String profileActivityLevel = 'profile_activity_level';

  /// Comma-separated list of user goal tags for personalized content.
  ///
  /// Example: `'yoga,meditation,workout'`.
  /// Empty string when unset (default).
  static const String profileGoals = 'profile_goals';

  // ── TTS Provider Settings ───────────────────────────────────────────────

  /// The selected TTS provider identifier (always 'kokoro').
  static const String ttsProvider = 'tts_provider';

  // ── Migration Flags ─────────────────────────────────────────────────────

  /// Set to `'true'` once the v2 plan migration (int id → String UUID) has
  /// been applied to the local SQLite database.
  ///
  /// Defaults to `'false'` when absent.
  static const String plansMigratedV2 = 'plans_migrated_v2';

  /// Temporary storage for pre-v6 user plans captured during the schema
  /// migration before the plans table is dropped.
  ///
  /// Contains a JSON-encoded `List<Map<String, dynamic>>` where each entry
  /// is a raw SQLite row from the old plans table. Populated by the Drift
  /// [onUpgrade] callback and consumed (then cleared) by the
  /// [_migratePlansToServer] helper in `main.dart`.
  ///
  /// The key is cleared (set to empty string) after a successful upload.
  /// If the key is absent or empty, there are no plans pending migration.
  static const String pendingMigrationPlans = '_pending_migration_plans';

  // ── Sync Metadata ───────────────────────────────────────────────────────

  /// ISO-8601 timestamp string of the last successful database sync to S3.
  ///
  /// Null / absent when the database has never been synced.
  static const String lastSyncAt = 'last_sync_at';

  /// Size in bytes of the last uploaded database file, stored as a string.
  ///
  /// Null / absent when the database has never been synced.
  static const String lastSyncSizeBytes = 'last_sync_size_bytes';

  /// SHA-256 hex digest of the last uploaded database file.
  ///
  /// Used to avoid redundant uploads when the file hasn't changed since the
  /// last sync.
  static const String lastSyncHash = 'last_sync_hash';
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

  /// Keys whose values must be non-empty when written.
  static const _nonEmptyKeys = {
    AppSettingsKeys.defaultVoice,
    AppSettingsKeys.ttsLocale,
    AppSettingsKeys.ttsProvider,
  };

  /// Writes (upserts) [value] for [key].
  ///
  /// Throws [ArgumentError] if [key] is a voice, locale, or provider setting
  /// and [value] is empty, preventing silent data corruption.
  Future<void> write(String key, String value) async {
    if (_nonEmptyKeys.contains(key) && value.trim().isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'Setting "$key" must not be empty',
      );
    }
    await _db.into(_db.appSettingsTable).insert(
          AppSettingsTableCompanion(
            key: Value(key),
            value: Value(value),
            updatedAt: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (old) => AppSettingsTableCompanion(
              value: Value(value),
              updatedAt: Value(DateTime.now()),
            ),
            target: [_db.appSettingsTable.key],
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

  /// Returns `true` when the v2 plan migration (int id → String UUID) has
  /// already been applied to the local SQLite database.
  ///
  /// Defaults to `false` when the key is absent.
  Future<bool> plansMigratedV2() async {
    final val = await read(AppSettingsKeys.plansMigratedV2);
    return val == 'true';
  }

  /// Marks the v2 plan migration as completed.
  Future<void> setPlansMigratedV2() =>
      write(AppSettingsKeys.plansMigratedV2, 'true');
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
