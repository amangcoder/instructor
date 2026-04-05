// TASK-006: Notification service for local notifications
// Implements flutter_local_notifications wrapping for step notifications,
// resume prompts, and the Android foreground persistent notification.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/router.dart';

part 'notification_service.g.dart';

// ── Notification channel identifiers ─────────────────────────────────────────

/// High-importance channel used for step notifications and resume prompts.
///
/// Channel id and name match the architecture spec exactly.
const String kPlanNotificationsChannelId = 'plan_notifications';
const String kPlanNotificationsChannelName = 'Plan Notifications';

/// Low-importance channel for the persistent Android foreground notification.
const String _foregroundChannelId = 'plan_foreground';
const String _foregroundChannelName = 'Plan Foreground';

// ── Notification IDs ──────────────────────────────────────────────────────────

/// Step notifications rotate through IDs 1–10 to prevent accumulation while
/// keeping at most 10 concurrent step notifications visible.
const int _stepNotificationIdMin = 1;
const int _stepNotificationIdMax = 10;

/// Fixed ID for the "resume after phone call" notification.
const int _resumePromptId = 100;

/// Fixed ID for the ongoing Android foreground service notification.
const int _foregroundNotificationId = 200;

// ── Action / category identifiers ─────────────────────────────────────────────

/// Action identifier for the "Resume" button on the resume prompt.
const String kResumeActionId = 'resume_now_playing';

/// iOS notification category for resume prompts.
const String _resumeCategoryId = 'RESUME_CATEGORY';

// ── Background notification handler ───────────────────────────────────────────

/// Handles notification responses received while the app is in the background.
///
/// Must be a **top-level** function (not a method or closure) and annotated
/// with `@pragma('vm:entry-point')` so AOT compilation retains it.
///
/// Navigation cannot happen here (no [BuildContext]). Instead, the desired
/// route is stored in [NotificationService.pendingRoute] and consumed by the
/// app when it resumes to foreground.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  final route = _resolveRouteFromResponse(response);
  if (route != null) {
    _NotificationRouteStore.pendingRoute = route;
  }
}

// ── Internal route store ──────────────────────────────────────────────────────

/// Shared state for routing intents emitted by notification taps.
///
/// Separated from [NotificationService] so the top-level background callback
/// can write to it without a service instance.
abstract class _NotificationRouteStore {
  /// Pending route from a background notification tap. Cleared by the app
  /// on resume via [NotificationService.clearPendingRoute].
  static String? pendingRoute;

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static Stream<String> get routeStream => _controller.stream;

  static void emit(String route) => _controller.add(route);
}

// ── Helper ────────────────────────────────────────────────────────────────────

String? _resolveRouteFromResponse(NotificationResponse response) {
  if (response.actionId == kResumeActionId) {
    return AppRoutes.nowPlaying;
  }
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    return payload;
  }
  return null;
}

// ── Abstract interface ────────────────────────────────────────────────────────

/// Manages local push notifications for Plan execution events.
///
/// Fires notifications **on-demand** (never pre-scheduled) to respect the iOS
/// 64-pending-notification limit.
///
/// ## Notification types
/// - **Step notifications** — fired when execution reaches a [NotifyStep].
///   IDs rotate 1–10 so old notifications are replaced as execution progresses.
/// - **Resume prompts** — shown after a phone-call interruption with a
///   "Resume" action button that deep-links to the Now Playing screen.
/// - **Android foreground notification** — persistent low-importance
///   notification updating the current step text and time remaining.
///   Required by Android API 26+ for foreground services.
///
/// ## Navigation on tap
///
/// Notification taps emit a GoRouter path on [routeStream]. Widgets should
/// react with `ref.listen` on [notificationRouteStreamProvider]:
/// ```dart
/// ref.listen(notificationRouteStreamProvider, (_, next) {
///   next.whenData((route) => context.go(route));
/// });
/// ```
///
/// When the app was backgrounded and the user tapped a notification to reopen
/// it, check [pendingRoute] on startup and call [clearPendingRoute] after
/// consuming it.
abstract class NotificationService {
  /// Requests OS notification permissions and creates Android channels.
  ///
  /// Must be called before any other method. Safe to call multiple times —
  /// subsequent calls are no-ops on already-granted permissions.
  Future<void> initialize();

  /// Fires an immediate push notification for a [NotifyStep].
  ///
  /// Uses the high-importance [kPlanNotificationsChannelId] channel. IDs
  /// rotate so notifications replace each other rather than accumulating.
  Future<void> showStepNotification(String title, String body);

  /// Shows a notification offering to resume [planName] after interruption.
  ///
  /// Includes a "Resume" action button that deep-links to `/now-playing`.
  /// On iOS, the action is surfaced via a registered notification category.
  Future<void> showResumePrompt(String planName);

  /// Cancels all displayed and pending notifications immediately.
  Future<void> cancelAll();

  /// Updates the persistent Android foreground service notification.
  ///
  /// Shows the current [stepText] and formatted [remaining] duration.
  /// Uses the low-importance [_foregroundChannelId] channel with `ongoing: true`
  /// so the user cannot swipe it away while the plan is running.
  ///
  /// **No-op on iOS** — iOS background execution is maintained via the
  /// AVAudioSession kept alive by [AudioEngine]; no foreground service needed.
  Future<void> updateForegroundNotification(
    String stepText,
    Duration remaining,
  );

  // ── Static routing surface ─────────────────────────────────────────────────

  /// Emits GoRouter route strings when the user taps a notification.
  ///
  /// Only fires while the app is in the foreground or resumes from background.
  /// For cold-start deep links use [pendingRoute] instead.
  static Stream<String> get routeStream => _NotificationRouteStore.routeStream;

  /// The route from a notification tapped while the app was backgrounded.
  ///
  /// Non-null only once per background → foreground transition. Cleared after
  /// the app consumes it via [clearPendingRoute].
  static String? get pendingRoute => _NotificationRouteStore.pendingRoute;

  /// Clears [pendingRoute] once the deep-link has been consumed.
  static void clearPendingRoute() =>
      _NotificationRouteStore.pendingRoute = null;

  // ── Test helpers ───────────────────────────────────────────────────────────

  /// For testing only — emits [route] on [routeStream] without a real tap.
  @visibleForTesting
  static void emitRouteForTesting(String route) =>
      _NotificationRouteStore.emit(route);

  /// For testing only — sets [pendingRoute] without a real notification.
  @visibleForTesting
  static void setPendingRouteForTesting(String? route) =>
      _NotificationRouteStore.pendingRoute = route;
}

// ── Concrete implementation ───────────────────────────────────────────────────

/// Production [NotificationService] backed by [FlutterLocalNotificationsPlugin].
///
/// Inject a custom [plugin] in tests to avoid real platform-channel calls.
class FlutterNotificationService extends NotificationService {
  FlutterNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Next step notification ID. Rotates from [_stepNotificationIdMin] to
  /// [_stepNotificationIdMax] to replace old notifications rather than pile up.
  int _stepNotificationCounter = _stepNotificationIdMin;

  // ── Initialization ────────────────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register the iOS "RESUME_CATEGORY" with a "Resume" foreground action so
    // the action button appears on the lock screen and in notification centre.
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _resumeCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              kResumeActionId,
              'Resume',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Android API 33+ requires explicit POST_NOTIFICATIONS permission.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    }

    await _createAndroidChannels();
  }

  Future<void> _createAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // High-importance channel: step notifications and resume prompts.
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        kPlanNotificationsChannelId,
        kPlanNotificationsChannelName,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Low-importance channel: the persistent foreground service notification.
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _foregroundChannelId,
        _foregroundChannelName,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      ),
    );
  }

  // ── Notification tap handling ─────────────────────────────────────────────

  /// Called by the plugin when the user taps a notification while the app is
  /// in the foreground or immediately resumes to foreground.
  void _onForegroundResponse(NotificationResponse response) {
    final route = _resolveRouteFromResponse(response);
    if (route != null) {
      _NotificationRouteStore.emit(route);
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  @override
  Future<void> showStepNotification(String title, String body) async {
    final id = _nextStepNotificationId();

    const androidDetails = AndroidNotificationDetails(
      kPlanNotificationsChannelId,
      kPlanNotificationsChannelName,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Plan step',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  @override
  Future<void> showResumePrompt(String planName) async {
    const androidDetails = AndroidNotificationDetails(
      kPlanNotificationsChannelId,
      kPlanNotificationsChannelName,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Resume plan',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          kResumeActionId,
          'Resume',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
      categoryIdentifier: _resumeCategoryId,
    );

    await _plugin.show(
      _resumePromptId,
      'Resume "$planName"?',
      'Your plan was paused for an incoming call. Tap to continue.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: AppRoutes.nowPlaying,
    );
  }

  @override
  Future<void> updateForegroundNotification(
    String stepText,
    Duration remaining,
  ) async {
    // This notification is only needed on Android for the foreground service
    // requirement (API 26+). iOS background execution is managed by AudioEngine
    // keeping the AVAudioSession active via a silent audio loop.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final timeLabel = _formatDuration(remaining);
    final body = stepText.isNotEmpty
        ? '$stepText · $timeLabel remaining'
        : '$timeLabel remaining';

    const androidDetails = AndroidNotificationDetails(
      _foregroundChannelId,
      _foregroundChannelName,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
    );

    await _plugin.show(
      _foregroundNotificationId,
      'Instructor',
      body,
      const NotificationDetails(android: androidDetails),
      payload: AppRoutes.nowPlaying,
    );
  }

  @override
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Returns the next step notification ID, rotating in [_stepNotificationIdMin..
  /// _stepNotificationIdMax] to replace stale notifications.
  int _nextStepNotificationId() {
    final id = _stepNotificationCounter;
    _stepNotificationCounter++;
    if (_stepNotificationCounter > _stepNotificationIdMax) {
      _stepNotificationCounter = _stepNotificationIdMin;
    }
    return id;
  }

  /// Formats [d] as `MM:SS` (or `H:MM:SS` when hours > 0).
  @visibleForTesting
  String formatDurationForDisplay(Duration d) => _formatDuration(d);

  /// For testing only — returns the next step notification ID as
  /// [_nextStepNotificationId] would produce it, advancing the counter.
  @visibleForTesting
  int nextStepIdForTesting() => _nextStepNotificationId();

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

/// Provides a long-lived singleton [NotificationService].
///
/// `keepAlive: true` ensures the service persists for the app lifetime and
/// is not disposed between navigations.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return FlutterNotificationService();
}

/// A stream of GoRouter paths emitted when the user taps a notification.
///
/// Connect to this provider with `ref.listen` in a widget or shell route
/// to handle notification-driven navigation:
///
/// ```dart
/// @override
/// Widget build(BuildContext context, WidgetRef ref) {
///   ref.listen<AsyncValue<String>>(
///     notificationRouteStreamProvider,
///     (_, next) => next.whenData((route) => context.go(route)),
///   );
///   ...
/// }
/// ```
@Riverpod(keepAlive: true)
Stream<String> notificationRouteStream(Ref ref) {
  return NotificationService.routeStream;
}
