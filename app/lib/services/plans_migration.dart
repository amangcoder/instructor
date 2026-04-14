/// Utility helpers for the pre-v6 → server plan migration (TASK-059).
///
/// Separated from `main.dart` so the logic can be unit-tested independently.
/// [main.dart] calls [migratePlansToServer] as part of `_bootstrap()`.
library plans_migration;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/database/type_converters.dart';
import 'package:instructor/models/auth_models.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Whether a plan migration was deferred because the user was not authenticated
/// at app startup.
///
/// Set to `true` by [migratePlansToServer] when [AuthService.isAuthenticated]
/// is `false` and there are plans pending upload; cleared back to `false` once
/// [schedulePostLoginMigration] successfully runs [migratePlansToServer] after
/// the user logs in within the same session.
///
/// The app shell (e.g. [BottomNavShell]) watches this provider to display a
/// one-time warning dialog informing the user that plan sync is pending.
final migrationPendingProvider = StateProvider<bool>((_) => false);

/// Number of plans that failed to upload during the most recent migration run.
///
/// Remains `0` when all uploads succeed or when no migration was attempted.
/// Set to a positive integer by [migratePlansToServer] when one or more
/// individual [PlanApiService.savePlan] calls throw.
///
/// The app shell (e.g. [BottomNavShell]) watches this provider to display a
/// non-blocking warning (e.g. a SnackBar) so the user knows that some of
/// their plans were not synced. The partial failure is non-fatal — the
/// migration is still marked complete to avoid infinite retry loops.
final migrationPartialFailureProvider = StateProvider<int>((_) => 0);

/// Uploads user-created plans from the pre-v6 schema to the backend API.
///
/// Must be called after [ProviderContainer] is created. Accessing
/// [appSettingsProvider] triggers the lazy database open, which runs the
/// v5→v6 schema migration; that migration captures user-created plans as a
/// JSON blob in `app_settings` under [AppSettingsKeys.pendingMigrationPlans]
/// before dropping the old `plans` table.
///
/// ### Decision flow
///
/// 1. Read [AppSettingsKeys.plansMigratedV2] — return early if already `'true'`.
/// 2. Read [AppSettingsKeys.pendingMigrationPlans] — return early (and mark
///    done) if absent or empty (fresh install or no user-created plans).
/// 3. Check [AuthService.isAuthenticated] — if not authenticated, print a
///    warning and return without setting the flag so the next launch retries.
/// 4. Upload each captured plan via [PlanApiService.savePlan], emitting
///    [onProgress] calls and logging `"Syncing your plans... N/M"`.
/// 5. Mark [AppSettingsKeys.plansMigratedV2] as `'true'` and clear the blob.
///
/// Individual upload failures are non-fatal: they are logged and skipped so
/// one bad plan does not block the rest. The flag is set on completion even
/// when some uploads failed — partial success avoids infinite retry loops.
Future<void> migratePlansToServer(
  ProviderContainer container, {
  void Function(int current, int total)? onProgress,
}) async {
  final settings = container.read(appSettingsProvider);

  // Reading settings triggers the lazy database open and, if the schema
  // is at version 5, the v5→v6 migration that captures plans into the blob.
  final alreadyMigrated = await settings.plansMigratedV2();
  if (alreadyMigrated) {
    return; // Migration already completed in a previous launch.
  }

  final plansJsonStr =
      await settings.read(AppSettingsKeys.pendingMigrationPlans);

  if (plansJsonStr == null || plansJsonStr.isEmpty) {
    // Fresh install or all plans were starter plans (is_user_created = 0).
    // Nothing to upload — mark as complete so we skip this on every future
    // launch.
    await settings.setPlansMigratedV2();
    return;
  }

  // Only upload if the user is already authenticated. If not, leave the
  // flag unset so the pending blob persists and the next launch retries,
  // and signal the app shell to show a warning dialog.
  final auth = container.read(authServiceProvider);
  if (!auth.isAuthenticated) {
    debugPrint(
      '[PlansMigration] Not authenticated — '
      'plan sync deferred to next login.',
    );
    // Raise the pending flag so the app shell can show a warning dialog
    // and so [schedulePostLoginMigration] knows to retry after login.
    container.read(migrationPendingProvider.notifier).state = true;
    return;
  }

  // Parse the JSON blob written by the v5→v6 migration callback.
  List<Map<String, dynamic>> rawPlans;
  try {
    final decoded = jsonDecode(plansJsonStr) as List<dynamic>;
    rawPlans = decoded.cast<Map<String, dynamic>>();
  } catch (e) {
    // Corrupted blob — clear and mark done to prevent infinite retries.
    debugPrint('[PlansMigration] Failed to parse pending plans blob: $e');
    await settings.write(AppSettingsKeys.pendingMigrationPlans, '');
    await settings.setPlansMigratedV2();
    return;
  }

  final apiService = container.read(planApiServiceProvider);
  final total = rawPlans.length;
  int uploaded = 0;
  int failed = 0;

  for (int i = 0; i < rawPlans.length; i++) {
    // Fire progress callback (and log) before each attempt so callers can
    // surface "Syncing your plans... N/M" in tests and on the device console.
    onProgress?.call(i + 1, total);
    debugPrint('Syncing your plans... ${i + 1}/$total');

    try {
      final plan = parseLegacyPlan(rawPlans[i]);
      await apiService.savePlan(plan);
      uploaded++;
    } catch (e) {
      debugPrint('[PlansMigration] Failed to upload plan at index $i: $e');
      failed++;
    }
  }

  debugPrint(
    '[PlansMigration] Done — uploaded: $uploaded, failed: $failed.',
  );

  // Surface partial-failure count to the UI via a provider so the app shell
  // can show a non-blocking warning (e.g. a SnackBar).
  if (failed > 0) {
    container.read(migrationPartialFailureProvider.notifier).state = failed;
  }

  // Mark migration complete and clear the temporary blob. We do this even
  // on partial failure — users can recreate any lost plans manually.
  await settings.write(AppSettingsKeys.pendingMigrationPlans, '');
  await settings.setPlansMigratedV2();
}

/// Registers a one-shot listener on [AuthService.authStateStream] that
/// re-runs [migratePlansToServer] the first time the user authenticates in
/// this session.
///
/// ### When to call
/// Call from bootstrap immediately after [migratePlansToServer] when
/// [migrationPendingProvider] is `true`, i.e.:
/// ```dart
/// await migratePlansToServer(container);
/// if (container.read(migrationPendingProvider)) {
///   schedulePostLoginMigration(container);
/// }
/// ```
///
/// ### Lifecycle
/// The returned [StreamSubscription] cancels itself automatically after the
/// first [Authenticated] event; callers do not need to store or cancel it
/// manually unless they want to abort before login occurs.
///
/// ### Post-migration state
/// On completion [migrationPendingProvider] is set back to `false` so the
/// app shell can dismiss any pending-migration warning UI.
StreamSubscription<AuthState> schedulePostLoginMigration(
  ProviderContainer container, {
  void Function(int current, int total)? onProgress,
}) {
  final auth = container.read(authServiceProvider);

  // Use `late` here; the stream callback is always invoked asynchronously
  // (after the current microtask completes), so `sub` is always assigned
  // before the listener body can run.
  late StreamSubscription<AuthState> sub;
  sub = auth.authStateStream.listen(
    (authState) async {
      if (authState is! Authenticated) return;

      // One-shot: cancel before running migration to ignore any subsequent
      // auth events (e.g. token-refresh broadcasts).
      sub.cancel();

      debugPrint(
        '[PlansMigration] User logged in — resuming deferred migration.',
      );

      try {
        await migratePlansToServer(container, onProgress: onProgress);
      } catch (e) {
        // migratePlansToServer already catches individual upload failures;
        // this guard handles any unexpected top-level errors.
        debugPrint('[PlansMigration] Post-login migration error: $e');
      }

      // Clear the pending flag whether migration succeeded or failed to
      // ensure the warning dialog is not shown again in this session.
      container.read(migrationPendingProvider.notifier).state = false;
    },
    onError: (Object e, StackTrace st) {
      debugPrint('[PlansMigration] authStateStream error: $e');
    },
  );

  return sub;
}

/// Converts a raw SQLite row from the pre-v6 `plans` table into a [Plan].
///
/// The pre-v6 schema used an `INTEGER` auto-increment primary key. An empty
/// [Plan.id] is used here so [PlanApiService.savePlan] treats the upload as a
/// *create* request, causing the server to assign a fresh UUID.
///
/// DateTime columns in Drift are stored as milliseconds since epoch (`int`).
/// [parseLegacyDateTime] handles both that form and ISO-8601 strings for older
/// schema variants that may have stored dates differently.
Plan parseLegacyPlan(Map<String, dynamic> raw) {
  const stepConverter = StepListConverter();
  const tagConverter = StringListConverter();

  List<PlanStep> steps;
  try {
    steps = stepConverter.fromSql(raw['steps'] as String? ?? '[]');
  } catch (_) {
    steps = const [];
  }

  List<String> tags;
  try {
    tags = tagConverter.fromSql(raw['tags'] as String? ?? '[]');
  } catch (_) {
    tags = const [];
  }

  final categoryStr = raw['category'] as String? ?? 'custom';
  final category = PlanCategory.values.firstWhere(
    (c) => c.name == categoryStr,
    orElse: () => PlanCategory.custom,
  );

  final voice = raw['default_voice'] as String?;

  return Plan(
    // Empty id → server creates a new UUID. PlanApiService.savePlan omits
    // planId from the request body when the id is empty or not a UUID v4.
    id: '',
    name: raw['name'] as String? ?? 'Untitled Plan',
    description: raw['description'] as String?,
    category: category,
    tags: tags,
    defaultVoice: (voice != null && voice.isNotEmpty) ? voice : 'aoede',
    steps: steps,
    createdAt: parseLegacyDateTime(raw['created_at']) ?? DateTime.now(),
    updatedAt: parseLegacyDateTime(raw['updated_at']) ?? DateTime.now(),
    lastUsedAt: parseLegacyDateTime(raw['last_used_at']),
  );
}

/// Parses a raw SQLite datetime value into a [DateTime].
///
/// Drift's [DateTimeColumn] stores values as milliseconds since epoch (`int`).
/// Older on-disk databases may store ISO-8601 strings — both forms are handled.
/// Returns null when [value] is null, zero, or unparseable.
DateTime? parseLegacyDateTime(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    if (value == 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String && value.isNotEmpty) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}
