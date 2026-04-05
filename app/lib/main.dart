import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/app.dart';
import 'package:instructor/database/app_database.dart';
import 'package:instructor/services/background_service.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/plan_execution_engine.dart';

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
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Resolve the SQLite file path. ─────────────────────────────────
  await initDatabase();

  // ── Step 2: Create the Riverpod container early so we can read services ───
  //           that are needed by the background handler.
  //
  // Using ProviderContainer before runApp is a documented Riverpod pattern for
  // bootstrap scenarios. The same container is reused by ProviderScope via the
  // [parent] parameter so only one instance of each provider is created.
  final container = ProviderContainer();

  final engine = container.read(planExecutionEngineProvider);
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

  // ── Step 4: Run the Flutter app. ──────────────────────────────────────────
  runApp(
    ProviderScope(
      parent: container,
      child: const InstructorApp(),
    ),
  );
}
