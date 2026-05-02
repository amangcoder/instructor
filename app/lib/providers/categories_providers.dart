/// Riverpod providers for the content-hierarchy feature:
/// categories → series (by category) → plans (with sub-plan tree).
///
/// ### Provider map
/// | Provider | Type | Endpoint |
/// |---|---|---|
/// | [categoriesProvider] | `FutureProvider<List<Category>>` | `GET /api/categories` |
/// | [seriesByCategoryProvider] | `FutureProvider.family<List<Series>, String>` | `GET /api/series?categorySlug=…` |
/// | [planTreeProvider] | `FutureProvider.family<Plan, String>` | `GET /api/plans/:id/tree` |
/// | [selectedVoiceProvider] | `Notifier.family<Voice?, String>` | n/a (local state) |
///
/// All data-fetching providers use [apiClientProvider] for authenticated HTTP.
/// Error states bubble up as [AsyncError] via the standard Riverpod `.when()`
/// pattern — callers are not expected to catch exceptions.
library categories_providers;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/category.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/models/voice.dart';
import 'package:instructor/services/api_client.dart';

part 'categories_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Decodes a JSON array from a raw HTTP response body.
///
/// Returns an empty list when [body] is blank or the root element is not a
/// JSON array.  Keeps the providers free of explicit null checks.
List<Map<String, dynamic>> _decodeJsonList(String body) {
  if (body.isEmpty) return const [];
  final decoded = jsonDecode(body);
  if (decoded is List) return decoded.cast<Map<String, dynamic>>();
  return const [];
}

/// Asserts that [statusCode] is in the 2xx range.
///
/// Throws [ApiException] with the HTTP status and raw [body] when the check
/// fails, which Riverpod surfaces as an [AsyncError] to the UI.
void _ensureOk(int statusCode, String body, String context) {
  if (statusCode < 200 || statusCode >= 300) {
    throw ApiException(
      '$context returned $statusCode: $body',
      statusCode: statusCode,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// categoriesProvider — GET /api/categories
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all published categories from the server.
///
/// Calls `GET /api/categories` which returns only `is_published=true`
/// categories ordered by their `sort_order`.  Returns an empty list when no
/// categories have been published yet.
///
/// ### Error handling
/// Any non-2xx HTTP response or network failure is wrapped in [ApiException]
/// and surfaced as `AsyncError` — the UI should handle both the loading and
/// error states via `.when()`.
///
/// Usage:
/// ```dart
/// final cats = ref.watch(categoriesProvider);
/// cats.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
@riverpod
Future<List<Category>> categories(Ref ref) async {
  final client = ref.watch(apiClientProvider);
  final uri = Uri.parse('${client.backendBaseUrl}/api/categories');
  final response = await client.getJson(uri);
  final list = (response['categories'] as List?) ?? const [];
  return list
      .cast<Map<String, dynamic>>()
      .map(Category.fromJson)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// seriesByCategoryProvider — GET /api/series?categorySlug=<slug>
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches all published series that belong to a given category [slug].
///
/// Calls `GET /api/series?categorySlug=<slug>`.  Returns an ordered list of
/// [Series] in the server-defined sort order.  An empty list is returned when
/// the category exists but has no published series.
///
/// ### Error handling
/// Non-2xx responses are surfaced as `AsyncError`.
/// The category [slug] is URL-encoded automatically by [Uri.replace].
///
/// Usage:
/// ```dart
/// final series = ref.watch(seriesByCategoryProvider('meditation'));
/// series.when(
///   data:    (list) => ...,
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
@riverpod
Future<List<Series>> seriesByCategory(Ref ref, String slug) async {
  final client = ref.watch(apiClientProvider);
  final uri = Uri.parse('${client.backendBaseUrl}/api/series')
      .replace(queryParameters: {'categorySlug': slug});
  final response = await client.send('GET', uri);
  _ensureOk(
    response.statusCode,
    response.body,
    'GET /api/series?categorySlug=$slug',
  );
  return _decodeJsonList(response.body).map(Series.fromJson).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// planTreeProvider — GET /api/plans/:planId/tree
// ─────────────────────────────────────────────────────────────────────────────

/// Fetches a [Plan] with its complete sub-plan tree up to depth 3.
///
/// Calls `GET /api/plans/:planId/tree`.  The root [Plan] is returned with its
/// [Plan.children] list populated to at most 3 levels deep:
///
/// ```
/// Root Plan                 (depth 0)
///   └─ Sub-plan A           (depth 1)
///        └─ Sub-plan A.1    (depth 2)
///             └─ Sub-plan A.1.a  (depth 3, leaf)
/// ```
///
/// Each child plan also carries its [Plan.voices] list so callers can check
/// TTS readiness without additional fetches.
///
/// ### Error handling
/// - `404` → plan not found; surfaced as `AsyncError`.
/// - `422` → depth constraint violated; surfaced as `AsyncError`.
/// - Network failures → surfaced as `AsyncError`.
///
/// Usage:
/// ```dart
/// final tree = ref.watch(planTreeProvider('plan-uuid-1234'));
/// tree.when(
///   data:    (plan) => PlanTreeWidget(plan: plan),
///   loading: () => const CircularProgressIndicator(),
///   error:   (e, _) => Text('Error: $e'),
/// );
/// ```
@riverpod
Future<Plan> planTree(Ref ref, String planId) async {
  final client = ref.watch(apiClientProvider);
  final uri =
      Uri.parse('${client.backendBaseUrl}/api/plans/$planId/tree');
  final response = await client.getJson(uri);
  return Plan.fromJson(response);
}

// ─────────────────────────────────────────────────────────────────────────────
// selectedVoiceProvider — per-plan voice selection (local state)
// ─────────────────────────────────────────────────────────────────────────────

/// Per-plan in-memory voice preference.
///
/// Tracks which [Voice] the user has selected for a specific [planId].
/// Defaults to `null`, which signals callers to fall back to the platform
/// TTS voice (see `FlutterTtsFallback` in the architecture).
///
/// This state is **session-scoped** — it is never persisted to disk or the
/// backend, and resets to `null` every app launch.
///
/// ### Selecting a voice
/// ```dart
/// // Read the current selection (null = no preference):
/// final voice = ref.watch(selectedVoiceProvider('plan-uuid'));
///
/// // Update the selection:
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(myVoice);
///
/// // Clear the selection (fall back to platform TTS):
/// ref.read(selectedVoiceProvider('plan-uuid').notifier).select(null);
/// ```
@riverpod
class SelectedVoice extends _$SelectedVoice {
  /// Initial state: no voice selected for this plan.
  @override
  Voice? build(String planId) => null;

  /// Sets the preferred voice for this plan.
  ///
  /// Pass `null` to clear the preference and fall back to platform TTS.
  void select(Voice? voice) => state = voice;
}
