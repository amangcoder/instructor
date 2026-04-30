// AppVersionService — asks the backend whether a force-update is required.
// Calls GET /api/app-version/check?platform=<ios|android>&version=<x.y.z>.
// Public endpoint (no auth) so it works even when logged out. When
// forceUpdate is true, the root widget renders a blocking screen and the
// rest of the app is unreachable until the user updates.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:instructor/services/app_settings.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_service.g.dart';

/// Result returned by the backend's `/api/app-version/check` endpoint.
class AppVersionCheck {
  const AppVersionCheck({
    required this.forceUpdate,
    required this.enabled,
    required this.minVersion,
    required this.latestVersion,
    required this.storeUrl,
    required this.message,
    required this.currentVersion,
  });

  /// Safe fallback used when the backend is unreachable — never blocks the
  /// user, so a temporary network failure can never lock them out.
  const AppVersionCheck.unavailable(this.currentVersion)
      : forceUpdate = false,
        enabled = false,
        minVersion = null,
        latestVersion = null,
        storeUrl = null,
        message = '';

  factory AppVersionCheck.fromJson(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    return AppVersionCheck(
      forceUpdate: json['forceUpdate'] == true,
      enabled: json['enabled'] == true,
      minVersion: json['minVersion'] as String?,
      latestVersion: json['latestVersion'] as String?,
      storeUrl: json['storeUrl'] as String?,
      message: (json['message'] as String?) ??
          'A new version is required. Please update to continue.',
      currentVersion: currentVersion,
    );
  }

  /// True when the current build must be updated before the app can be used.
  final bool forceUpdate;

  /// Whether the backend's gate is enabled at all.
  final bool enabled;

  final String? minVersion;
  final String? latestVersion;
  final String? storeUrl;
  final String message;
  final String currentVersion;
}

/// Thin wrapper around the check endpoint. Uses a plain [http.Client] (no
/// auth) because the endpoint is public — this deliberately does not depend
/// on [ApiClient] so that even unauthenticated startups can reach it.
class AppVersionService {
  AppVersionService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Fetches the force-update status. Never throws — falls back to
  /// [AppVersionCheck.unavailable] on any error.
  Future<AppVersionCheck> check() async {
    final currentVersion = await _readCurrentVersion();
    final platform = _platformName();
    if (platform == null) {
      // Web / desktop: no app-store update flow — never block.
      return AppVersionCheck.unavailable(currentVersion);
    }

    final uri = Uri.parse(
      '$kBackendUrl/api/app-version/check'
      '?platform=$platform&version=${Uri.encodeQueryComponent(currentVersion)}',
    );

    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('AppVersionService: HTTP ${response.statusCode}');
        return AppVersionCheck.unavailable(currentVersion);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return AppVersionCheck.unavailable(currentVersion);
      }
      return AppVersionCheck.fromJson(decoded, currentVersion);
    } catch (e) {
      debugPrint('AppVersionService: check failed ($e)');
      return AppVersionCheck.unavailable(currentVersion);
    }
  }

  Future<String> _readCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return '0.0.0';
    }
  }

  String? _platformName() {
    if (kIsWeb) return null;
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return null;
  }
}

@Riverpod(keepAlive: true)
AppVersionService appVersionService(Ref ref) => AppVersionService();

/// Periodically re-checks the force-update status. The root widget watches
/// this to decide whether to render the force-update screen — when the
/// backend flips the gate on mid-session, the next emission rebuilds the
/// app into the blocker without a relaunch.
const Duration _kAppVersionCheckInterval = Duration(minutes: 5);

@Riverpod(keepAlive: true)
Stream<AppVersionCheck> appVersionCheck(Ref ref) async* {
  final service = ref.watch(appVersionServiceProvider);
  yield await service.check();
  while (true) {
    await Future<void>.delayed(_kAppVersionCheckInterval);
    yield await service.check();
  }
}
