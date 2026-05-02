/// Remote config providers — runtime feature flags fetched from the backend.
///
/// Feature flags are resolved at runtime from `GET /api/app-config` so they
/// can be toggled without shipping a new app build.  The compile-time
/// `--dart-define` constants have been replaced by these providers to enable
/// phased rollouts and A/B experiments.
///
/// ### Providers
/// | Provider                 | Type                   | Flag               |
/// |--------------------------|------------------------|--------------------|
/// | [discoverEnabledProvider]| `FutureProvider<bool>` | discover_enabled   |
///
/// ### Fallback strategy
/// Any network or parse error silently returns `false` (disabled).  This is
/// the safe default: the existing plan-library screen stays active and the
/// Discover tab is not surfaced until the flag is explicitly enabled.
library remote_config_providers;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:instructor/services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// discoverEnabledProvider — GET /api/app-config → { discoverEnabled: bool }
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` if the Discover tab should be shown to the user.
///
/// Fetches the `discoverEnabled` flag from the backend app-config endpoint
/// at runtime so it can be toggled without a new app build.
///
/// Defaults to `false` on any network or parse error — the existing
/// plan_library screen remains the primary navigation destination until the
/// flag is explicitly enabled server-side.
///
/// Usage:
/// ```dart
/// final enabledAsync = ref.watch(discoverEnabledProvider);
/// enabledAsync.when(
///   data:    (enabled) => enabled ? DiscoverScreen() : LibraryScreen(),
///   loading: () => const CircularProgressIndicator(),
///   error:   (_, __) => LibraryScreen(), // safe fallback
/// );
/// ```
final discoverEnabledProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(apiClientProvider);
  try {
    final uri = Uri.parse('${client.backendBaseUrl}/api/app-config');
    final response = await client.send('GET', uri);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic flag = decoded['discoverEnabled'];
        if (flag is bool) return flag;
        // Accept string "true" for flexibility
        if (flag is String) return flag.toLowerCase() == 'true';
      }
    }
  } catch (_) {
    // Network failure, parse error, or missing endpoint — fall back to disabled.
  }
  return false;
});
