import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/app.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/audio_engine.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/services/background_service.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/notification_tap_channel.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/services/plans_migration.dart';
import 'package:instructor/services/tts_service.dart';
import 'package:instructor/services/widget_state_channel.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// Entry point for the Instructor app.
///
/// Performs three async initialisation steps before [runApp]:
///
/// 1. [initDatabase] — resolves the SQLite file path using
///    [getApplicationDocumentsDirectory] (requires platform channels, so it
///    must be called after [WidgetsFlutterBinding.ensureInitialized]).
///
/// 2. [initializeBackgroundService] — registers the [audio_service]
///    foreground handler so iOS / Android allow background audio execution.
///    This must run before [runApp] so the MediaSession is ready the moment
///    the first Plan starts.
///
/// 3. [runApp] with a [ProviderScope] whose [parent] is the pre-created
///    [ProviderContainer]. This ensures all Riverpod providers share the same
///    container instance, so the [PlanExecutionEngine] wired into the
///    background handler is the exact same object used by the UI.
void main() async {
  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      options
        ..dsn = _sentryDsn
        ..tracesSampleRate = 0.2;
    },
    appRunner: _bootstrap,
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 0: Register platform-channel handlers (must be after binding). ───
  //
  // Sets up the "com.instructor.app/notification" MethodChannel so that
  // MainActivity.onNewIntent() can notify Flutter when the user taps the
  // Android foreground notification body (REQ-004).
  initNotificationTapChannel();

  // ── Step 1: Resolve the SQLite file path and TTS audio directory. ──────────
  await initDatabase();
  await initTtsAudioDirectory();
  await initAudioDownloadDirectory();

  // ── Step 2: Create the Riverpod container early so we can read services ───
  //           that are needed by the background handler.
  //
  // Using ProviderContainer before runApp is a documented Riverpod pattern for
  // bootstrap scenarios. The same container is reused by ProviderScope via the
  // [parent] parameter so only one instance of each provider is created.
  final container = ProviderContainer();

  // ── Step 2a: Pre-load auth state from secure storage (TASK-063). ─────────
  //
  // AuthServiceImpl.isAuthenticated is an in-memory cache that starts as
  // false on every cold launch. isLoggedIn() reads tokens from
  // FlutterSecureStorage (Keychain / EncryptedSharedPrefs) and populates
  // that cache. It does NOT make any database query, so calling it here is
  // safe — the SQLite file has not been opened yet.
  //
  // Critical ordering guarantee (REQ-003 / TASK-063):
  //
  //   1. auth  → isLoggedIn() reads secure storage; in-memory cache set.
  //   2. db    → NativeDatabase.createInBackground is still idle (lazy).
  //   3. migration → migratePlansToServer() calls settings.plansMigratedV2(),
  //                  which issues the first SQL query, triggering Drift's
  //                  onUpgrade callback (v5 → v6):
  //                    a. Capture user-created plans into app_settings BEFORE
  //                       the plans table is dropped.
  //                    b. DROP TABLE tts_cache / plans.
  //                    c. CREATE TABLE plans (TEXT pk, v6 columns).
  //                    d. CREATE TABLE tts_cache (TEXT FK).
  //   4. schema v6  → DB is now fully migrated; app continues with v6 schema.
  //
  // Without this pre-load, isAuthenticated is false on every startup because
  // the in-memory cache is never populated. migratePlansToServer() would then
  // defer the upload to the next launch — but by that point the plans table
  // has already been dropped (step 3b), so the data would be lost forever.
  final auth = container.read(authServiceProvider);
  await auth.isLoggedIn();

  // ── Step 2b: Upload pre-v6 plans to the server (TASK-059). ───────────────
  //
  // Reads user-created plans captured by the v5→v6 schema migration and
  // uploads them to the backend API before the rest of the app starts.
  // Accessing [appSettingsProvider] here triggers the database open (and
  // the v5→v6 schema migration) for the first time.
  //
  // Must run BEFORE any provider that observes the plans table so that the
  // local SQLite cache can be refreshed from the server after upload.
  await migratePlansToServer(
    container,
    onProgress: (current, total) =>
        debugPrint('Syncing your plans... $current/$total'),
  );

  // ── Step 2c: Schedule deferred migration to resume on next login (TASK-061).
  //
  // If the user was not authenticated when migratePlansToServer ran, it set
  // migrationPendingProvider = true and returned without uploading. Register
  // a one-shot authStateStream listener that re-runs migratePlansToServer the
  // first time the user authenticates within this app session. This handles
  // the common case where a user upgrades from pre-v6 while logged out and
  // logs in without restarting the app.
  if (container.read(migrationPendingProvider)) {
    schedulePostLoginMigration(
      container,
      onProgress: (current, total) =>
          debugPrint('Syncing your plans... $current/$total'),
    );
  }

  final engine = container.read(planExecutionEngineProvider);
  // Read audioEngine early so the Riverpod singleton is created before
  // PlanExecutionEngine first references it. The handler no longer holds a
  // direct reference — engine.stop() calls audioEngine.stopAll() internally.
  container.read(audioEngineProvider);
  final notificationService = container.read(notificationServiceProvider);

  // ── Step 3: Initialise audio_service and the iOS AVAudioSession. ──────────
  //
  // This call:
  //   • Registers the Android foreground service with a persistent notification.
  //   • Sets the iOS AVAudioSession category to "playback" so the app keeps
  //     playing when the screen is locked.
  //   • Starts listening for phone-call interruptions via audio_session.
  try {
    await initializeBackgroundService(
      engine: engine,
      notificationService: notificationService,
    );
  } catch (e) {
    debugPrint('Background service init failed: $e');
  }

  // ── Step 4b: Initialise iOS widget state bridge (TASK-017). ─────────────
  //
  // Reads widgetStateChannelProvider to create the singleton, which wires up
  // the PlanExecutionEngine → UserDefaults → WidgetKit pipeline.
  // No-op on non-iOS platforms.
  container.read(widgetStateChannelProvider);

  // ── Step 5: Run the Flutter app. ──────────────────────────────────────────
  runApp(
    ProviderScope(
      parent: container,
      child: const InstructorApp(),
    ),
  );
}

