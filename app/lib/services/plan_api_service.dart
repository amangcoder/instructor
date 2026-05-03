/// PlanApiService — HTTP layer for all plan, library, and TTS API calls.
///
/// Wraps [ApiClient] to provide typed methods for plan CRUD, library browsing,
/// and TTS status/audio-URL retrieval. All responses are parsed into the
/// corresponding domain models and errors are converted to user-friendly messages.
///
/// Usage:
/// ```dart
/// final service = ref.read(planApiServiceProvider);
/// final plans = await service.fetchUserPlans();
/// ```
library plan_api_service;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:instructor/exceptions/app_exception.dart';
import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/tags_json.dart';
import 'package:instructor/models/tts_provider_config.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/utils/hash_utils.dart' show normalizeSpeechRate;

// ─────────────────────────────────────────────────────────────────────────────
// Value types
// ─────────────────────────────────────────────────────────────────────────────

/// Aggregate rating stats plus the current user's rating for a plan.
class PlanRatingResult {
  const PlanRatingResult({
    required this.averageRating,
    required this.ratingsCount,
    this.userRating,
  });

  final double? averageRating;
  final int ratingsCount;

  /// The authenticated user's own rating (1–5), or null if not yet rated.
  final int? userRating;
}

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when any [PlanApiService] call encounters an error.
///
/// Extends [PlanAppException] so callers catching [AppException] also catch
/// plan API errors via the unified exception hierarchy.
///
/// [message] is the raw technical error; [userMessage] is safe to display
/// in the UI without leaking internal details.
final class PlanApiException extends PlanAppException {
  const PlanApiException(String message, {String? userMessage})
      : userMessage = userMessage ?? message,
        super(message);

  /// User-friendly message suitable for display in the UI.
  final String userMessage;

  @override
  String toString() => 'PlanApiException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// HTTP client for all plan, library, and TTS API calls.
///
/// Each method maps 1-to-1 to a backend endpoint and parses the JSON response
/// into the appropriate domain model. [PlanApiException] is thrown on any error.
abstract class PlanApiService {
  // ── User plans ────────────────────────────────────────────────────────────

  /// GET /api/plans/list
  ///
  /// Returns summary [Plan] objects for all plans owned by the current user.
  /// Full step data is omitted from list responses; call [getPlanById] to
  /// retrieve a plan with its complete steps.
  Future<List<Plan>> fetchUserPlans();

  /// GET /api/plans/:id
  ///
  /// Returns the full [Plan] including steps, by server-assigned UUID.
  Future<Plan> getPlanById(String id);

  /// POST /api/plans/save
  ///
  /// Creates or updates a plan on the server. When [plan.id] is a valid UUID,
  /// the server updates the existing plan; otherwise a new plan is created.
  ///
  /// Returns the server-assigned UUID for the saved plan.
  Future<String> savePlan(Plan plan);

  /// DELETE /api/plans/:id
  ///
  /// Permanently deletes a plan owned by the current user.
  Future<void> deletePlan(String id);

  /// POST /api/plans/activate
  ///
  /// Activates a plan for studio-quality TTS pre-generation. The server sets
  /// `ttsStatus` to `pending` and begins background audio synthesis.
  ///
  /// [voice], [locale], and [speechRate] are sent so the server pre-generates
  /// audio with cache keys matching the client's runtime requests.
  Future<void> activatePlan(
    String planId, {
    required String voice,
    required String locale,
    required String speechRate,
  });

  // ── Library ───────────────────────────────────────────────────────────────

  /// GET /api/library/plans
  ///
  /// Returns a paginated list of [LibraryPlanSummary] from the global library.
  /// Supports optional [category] and [search] filters; [page] defaults to 1.
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  });

  /// GET /api/library/plans/:id
  ///
  /// Returns a full [Plan] from the global library, including all steps.
  Future<Plan> getLibraryPlanById(String id);

  /// POST /api/library/links
  ///
  /// Links a library plan to the current user's My Plans collection
  /// (idempotent — returns the same link id on repeated calls).
  ///
  /// Returns the link id, which becomes the plan's id in the local Drift
  /// cache and is used for all subsequent operations (delete, lastUsed, etc.).
  Future<String> addLibraryLink(String libraryPlanId);

  /// DELETE /api/library/links/:linkId
  ///
  /// Removes a library link from the user's My Plans collection.
  Future<void> removeLibraryLink(String linkId);

  // ── TTS ───────────────────────────────────────────────────────────────────

  /// GET /api/tts/status/:planId
  ///
  /// Returns the current [TtsStatusInfo] for a plan's TTS pre-generation job.
  Future<TtsStatusInfo> getTtsStatus(String planId);

  /// GET /api/tts/audio-urls/:planId
  ///
  /// Returns a list of [AudioFileUrl] with pre-signed S3 URLs for all
  /// completed TTS audio files belonging to [planId]. URLs are short-lived
  /// (~1 hour) and should be consumed promptly.
  Future<List<AudioFileUrl>> getAudioUrls(String planId);

  /// GET /api/tts/providers
  ///
  /// Returns all TTS provider configs. The active provider has [isActive] ==
  /// true and [defaultVoice] set to the recommended voice for new plans.
  Future<TtsProvidersResponse> fetchProviderCatalog();

  // ── Ratings ───────────────────────────────────────────────────────────────

  /// POST /api/ratings/:planId
  ///
  /// Upserts a 1–5 star rating for a library plan. Returns the updated
  /// aggregate stats and the user's submitted rating.
  Future<PlanRatingResult> ratePlan(String planId, int rating);

  /// DELETE /api/ratings/:planId
  ///
  /// Removes the current user's rating for a plan.
  Future<void> deleteRating(String planId);

  /// GET /api/ratings/:planId
  ///
  /// Returns aggregate rating stats and the current user's rating (null if
  /// not yet rated).
  Future<PlanRatingResult> getPlanRating(String planId);

  // ── Favorites ─────────────────────────────────────────────────────────────

  /// GET /api/favorites
  ///
  /// Returns the list of plan IDs the current user has favorited.
  Future<List<String>> fetchFavorites();

  /// POST /api/favorites/:planId/toggle
  ///
  /// Toggles the favorite status for a plan. Returns the new [isFavorite] state.
  Future<bool> toggleFavorite(String planId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Production [PlanApiService] backed by the NestJS backend via [ApiClient].
class PlanApiServiceImpl implements PlanApiService {
  const PlanApiServiceImpl({required ApiClient apiClient})
      : _client = apiClient;

  final ApiClient _client;

  // ── User plans ────────────────────────────────────────────────────────────

  @override
  Future<List<Plan>> fetchUserPlans() async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/list');
    try {
      final response = await _client.getJson(uri);
      final plansJson = response['plans'] as List<dynamic>? ?? [];
      return plansJson
          .map((p) => _parsePlanSummary(p as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw PlanApiException(
        'fetchUserPlans failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.fetchUserPlans: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to load plans. Please try again.',
      );
    }
  }

  @override
  Future<Plan> getPlanById(String id) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/$id');
    try {
      final response = await _client.getJson(uri);
      return _parsePlanResponse(response);
    } on ApiException catch (e) {
      throw PlanApiException(
        'getPlanById($id) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.getPlanById: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to load plan. Please try again.',
      );
    }
  }

  @override
  Future<String> savePlan(Plan plan) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/save');
    final body = <String, dynamic>{
      'name': plan.name,
      'planJson': jsonEncode(plan.toJson()),
    };
    // Only send planId if it is a server-assigned UUID v4.
    // New plans (empty id or non-UUID placeholder) omit planId so the server
    // creates a new record and returns the generated UUID.
    if (plan.id.isNotEmpty && _isUuidV4(plan.id)) {
      body['planId'] = plan.id;
    }
    try {
      final response = await _client.postJson(uri, body);
      final planId = response['planId'] as String?;
      if (planId == null || planId.isEmpty) {
        throw const PlanApiException(
          'Server returned no planId after save',
          userMessage: 'Failed to save plan. Please try again.',
        );
      }
      return planId;
    } on ApiException catch (e) {
      throw PlanApiException(
        'savePlan failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.savePlan: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to save plan. Please try again.',
      );
    }
  }

  @override
  Future<void> deletePlan(String id) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/$id');
    try {
      final response = await _client.send('DELETE', uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'DELETE /api/plans/$id returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on ApiException catch (e) {
      throw PlanApiException(
        'deletePlan($id) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.deletePlan: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to delete plan. Please try again.',
      );
    }
  }

  @override
  Future<void> activatePlan(
    String planId, {
    required String voice,
    required String locale,
    required String speechRate,
  }) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/activate');
    try {
      await _client.postJson(uri, {
        'planId': planId,
        // 'studio' triggers server-side TTS pre-generation (GenAI voice).
        'voiceQuality': 'studio',
        'voice': voice,
        'locale': locale,
        'speechRate': normalizeSpeechRate(speechRate),
      });
    } on ApiException catch (e) {
      throw PlanApiException(
        'activatePlan($planId) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.activatePlan: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to activate plan. Please try again.',
      );
    }
  }

  // ── Library ───────────────────────────────────────────────────────────────

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};
    if (category != null && category.isNotEmpty) {
      queryParams['category'] = category;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final uri = Uri.parse('${_client.backendBaseUrl}/api/library/plans')
        .replace(queryParameters: queryParams);
    try {
      final response = await _client.getJson(uri);
      final plansJson = response['plans'] as List<dynamic>? ?? [];
      return plansJson
          .map((p) => _parseLibraryPlanSummary(p as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      throw PlanApiException(
        'fetchLibraryPlans failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.fetchLibraryPlans: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to load library. Please try again.',
      );
    }
  }

  @override
  Future<Plan> getLibraryPlanById(String id) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/library/plans/$id');
    try {
      final response = await _client.getJson(uri);
      return _parseLibraryPlanDetail(id, response);
    } on ApiException catch (e) {
      throw PlanApiException(
        'getLibraryPlanById($id) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.getLibraryPlanById: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to load plan details. Please try again.',
      );
    }
  }

  @override
  Future<String> addLibraryLink(String libraryPlanId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/library/links');
    try {
      final response = await _client.postJson(uri, {'libraryPlanId': libraryPlanId});
      final linkId = response['linkId'] as String?;
      if (linkId == null || linkId.isEmpty) {
        throw const PlanApiException(
          'Server returned no linkId after addLibraryLink',
          userMessage: 'Failed to save plan. Please try again.',
        );
      }
      return linkId;
    } on ApiException catch (e) {
      throw PlanApiException(
        'addLibraryLink($libraryPlanId) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.addLibraryLink: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to save plan. Please try again.',
      );
    }
  }

  @override
  Future<void> removeLibraryLink(String linkId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/library/links/$linkId');
    try {
      final response = await _client.send('DELETE', uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'DELETE /api/library/links/$linkId returned ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on ApiException catch (e) {
      throw PlanApiException(
        'removeLibraryLink($linkId) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.removeLibraryLink: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to remove plan. Please try again.',
      );
    }
  }

  // ── TTS ───────────────────────────────────────────────────────────────────

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/tts/status/$planId');
    try {
      final response = await _client.getJson(uri);
      return TtsStatusInfo(
        // planId comes from the URL parameter — the server response omits it.
        planId: planId,
        status: response['status'] as String? ?? 'none',
        total: (response['total'] as num?)?.toInt() ?? 0,
        completed: (response['completed'] as num?)?.toInt() ?? 0,
      );
    } on ApiException catch (e) {
      throw PlanApiException(
        'getTtsStatus($planId) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.getTtsStatus: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to check TTS status. Please try again.',
      );
    }
  }

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async {
    final uri =
        Uri.parse('${_client.backendBaseUrl}/api/tts/audio-urls/$planId');
    try {
      final response = await _client.getJson(uri);
      // Server returns { urls: { [cacheKey]: presignedUrl } }
      final urls = response['urls'] as Map<String, dynamic>? ?? {};
      return urls.entries
          .map((e) => AudioFileUrl(cacheKey: e.key, url: e.value as String))
          .toList();
    } on ApiException catch (e) {
      throw PlanApiException(
        'getAudioUrls($planId) failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.getAudioUrls: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to fetch audio files. Please try again.',
      );
    }
  }

  @override
  Future<TtsProvidersResponse> fetchProviderCatalog() async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/tts/providers');
    try {
      final response = await _client.getJson(uri);
      return TtsProvidersResponse.fromJson(response);
    } on ApiException catch (e) {
      throw PlanApiException(
        'fetchProviderCatalog() failed: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanApiException) rethrow;
      debugPrint('PlanApiService.fetchProviderCatalog: unexpected error: $e');
      throw PlanApiException(
        e.toString(),
        userMessage: 'Failed to fetch TTS provider config.',
      );
    }
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  @override
  Future<PlanRatingResult> ratePlan(String planId, int rating) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/ratings/$planId');
    try {
      final response = await _client.postJson(uri, {'rating': rating});
      return _parseRatingResult(response);
    } on ApiException catch (e) {
      throw PlanApiException('ratePlan($planId) failed: ${e.message}', userMessage: _friendlyError(e));
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException(e.toString(), userMessage: 'Failed to submit rating. Please try again.');
    }
  }

  @override
  Future<void> deleteRating(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/ratings/$planId');
    try {
      final response = await _client.send('DELETE', uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException('DELETE /api/ratings/$planId returned ${response.statusCode}', statusCode: response.statusCode);
      }
    } on ApiException catch (e) {
      throw PlanApiException('deleteRating($planId) failed: ${e.message}', userMessage: _friendlyError(e));
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException(e.toString(), userMessage: 'Failed to remove rating. Please try again.');
    }
  }

  @override
  Future<PlanRatingResult> getPlanRating(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/ratings/$planId');
    try {
      final response = await _client.getJson(uri);
      return _parseRatingResult(response);
    } on ApiException catch (e) {
      throw PlanApiException('getPlanRating($planId) failed: ${e.message}', userMessage: _friendlyError(e));
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException(e.toString(), userMessage: 'Failed to load rating. Please try again.');
    }
  }

  // ── Favorites ─────────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchFavorites() async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/favorites');
    try {
      final response = await _client.getJson(uri);
      final planIds = response['planIds'] as List<dynamic>? ?? [];
      return planIds.cast<String>();
    } on ApiException catch (e) {
      throw PlanApiException('fetchFavorites failed: ${e.message}', userMessage: _friendlyError(e));
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException(e.toString(), userMessage: 'Failed to load favorites. Please try again.');
    }
  }

  @override
  Future<bool> toggleFavorite(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/favorites/$planId/toggle');
    try {
      final response = await _client.postJson(uri, {});
      return response['isFavorite'] as bool? ?? false;
    } on ApiException catch (e) {
      throw PlanApiException('toggleFavorite($planId) failed: ${e.message}', userMessage: _friendlyError(e));
    } catch (e) {
      if (e is PlanApiException) rethrow;
      throw PlanApiException(e.toString(), userMessage: 'Failed to update favorite. Please try again.');
    }
  }

  // ── Private parsers ───────────────────────────────────────────────────────

  Plan _parsePlanSummary(Map<String, dynamic> json) =>
      parsePlanFromServerRecord(json, overrideCreatedAt: true);

  Plan _parsePlanResponse(Map<String, dynamic> json) =>
      parsePlanFromServerRecord(json);

  /// Converts a [LibraryPlanSummaryRecord] JSON map into a [LibraryPlanSummary].
  LibraryPlanSummary _parseLibraryPlanSummary(Map<String, dynamic> json) {
    final category = _parseCategory(json['category'] as String?);
    final tags = _parseTags(json['tags'] as String?);
    return LibraryPlanSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Plan',
      description: json['description'] as String?,
      category: category,
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      locale: json['locale'] as String?,
      stepCount: (json['stepCount'] as num?)?.toInt() ?? 0,
      tags: tags,
    );
  }

  /// Builds a [Plan] from a library plan detail response.
  ///
  /// Library plans are stored with a `planJson` string blob in the same
  /// format as user plans. Library blobs commonly omit fields the [Plan]
  /// model marks as required (e.g. `createdAt`/`updatedAt` are admin-side
  /// metadata, not part of the playback payload), so a strict
  /// [Plan.fromJson] frequently throws. When that happens we fall back to
  /// a per-field merge against a minimal plan built from the top-level
  /// response so the steps still survive.
  Plan _parseLibraryPlanDetail(String id, Map<String, dynamic> json) {
    final planJsonStr = json['planJson'] as String?;
    Map<String, dynamic>? planJsonMap;

    if (planJsonStr != null && planJsonStr.isNotEmpty) {
      try {
        planJsonMap = jsonDecode(planJsonStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint(
            'PlanApiService._parseLibraryPlanDetail: failed to decode planJson — $e');
      }
    }

    final libId = json['id'] as String? ?? id;

    if (planJsonMap != null) {
      try {
        final withId = Map<String, dynamic>.from(planJsonMap)..['id'] = libId;
        return Plan.fromJson(withId);
      } catch (e) {
        debugPrint(
          'PlanApiService._parseLibraryPlanDetail: Plan.fromJson failed, '
          'falling back to partial-merge — $e',
        );
        return _mergePartialPlanJson(
          _minimalLibraryPlan(libId, json),
          planJsonMap,
        );
      }
    }

    return _minimalLibraryPlan(libId, json);
  }

  Plan _minimalLibraryPlan(String id, Map<String, dynamic> json) {
    final category = _parseCategory(json['category'] as String?);
    return Plan(
      id: id,
      name: json['name'] as String? ?? 'Untitled Plan',
      description: json['description'] as String?,
      category: category,
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ── Private utilities ─────────────────────────────────────────────────────

  PlanRatingResult _parseRatingResult(Map<String, dynamic> json) {
    final avg = json['averageRating'];
    return PlanRatingResult(
      averageRating: avg == null ? null : (avg as num).toDouble(),
      ratingsCount: (json['ratingsCount'] as num?)?.toInt() ?? 0,
      userRating: (json['userRating'] as num?)?.toInt(),
    );
  }

  String _parseCategory(String? raw) => raw ?? 'custom';

  /// Splits a comma-separated tags string into a trimmed [List<String>].
  List<String> _parseTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Returns a user-friendly error message based on the HTTP status code.
  String _friendlyError(ApiException e) {
    return switch (e.statusCode) {
      401 => 'Please log in to continue.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested plan could not be found.',
      422 => 'The request was invalid. Please try again.',
      429 =>
        'Too many requests. Please wait a moment and try again.',
      500 || 502 || 503 => 'Server error. Please try again later.',
      _ => 'An error occurred (${e.statusCode ?? 'network error'}). Please try again.',
    };
  }

  /// Returns true if [value] is a valid UUID v4 string.
  ///
  /// Used to decide whether to include a `planId` in the save request body.
  static bool _isUuidV4(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }
}

/// Builds a [Plan] from a server `PlanRecord` response.
///
/// Server responses wrap the full [Plan] payload in a `planJson` string blob
/// alongside top-level server-managed fields (`planId`, `isActive`, `ttsStatus`,
/// timestamps, …). We decode the blob, then overlay the authoritative
/// server-managed fields on top.
///
/// When [overrideCreatedAt] is true the server's `createdAt` also wins; the
/// single-plan endpoint omits a server `createdAt` so callers leave it false.
///
/// Resilience: some `planJson` payloads (e.g. seeded library plans, partial
/// drafts) omit fields the [Plan] model marks as required. Rather than
/// silently dropping the body, we fall back to a per-field best-effort merge
/// onto a minimal plan built from the top-level record.
Plan parsePlanFromServerRecord(
  Map<String, dynamic> json, {
  bool overrideCreatedAt = false,
}) {
  final planJsonStr = json['planJson'] as String?;
  Map<String, dynamic>? planJsonMap;

  if (planJsonStr != null && planJsonStr.isNotEmpty) {
    try {
      planJsonMap = jsonDecode(planJsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('parsePlanFromServerRecord: failed to decode planJson — $e');
    }
  }

  Plan base;
  if (planJsonMap != null) {
    try {
      base = Plan.fromJson(planJsonMap);
    } catch (e) {
      debugPrint(
        'parsePlanFromServerRecord: Plan.fromJson failed, '
        'falling back to partial-merge — $e',
      );
      base = _mergePartialPlanJson(
        _minimalPlanFromServerRecord(json),
        planJsonMap,
      );
    }
  } else {
    base = _minimalPlanFromServerRecord(json);
  }

  return base.copyWith(
    id: json['planId'] as String? ?? base.id,
    isActive: json['isActive'] as bool? ?? base.isActive,
    ttsStatus: json['ttsStatus'] as String? ?? base.ttsStatus,
    ttsTotal: (json['ttsTotal'] as num?)?.toInt() ?? base.ttsTotal,
    ttsCompleted: (json['ttsCompleted'] as num?)?.toInt() ?? base.ttsCompleted,
    seriesId: (json['seriesId'] as String?) ?? base.seriesId,
    // sourceLibraryPlanId from the server maps to libraryId on the client.
    // Present for plans synthesised from user_library_links; null otherwise.
    libraryId: (json['sourceLibraryPlanId'] as String?) ?? base.libraryId,
    createdAt: overrideCreatedAt
        ? (_safeParseDateTime(json['createdAt']) ?? base.createdAt)
        : base.createdAt,
    updatedAt: _safeParseDateTime(json['updatedAt']) ?? base.updatedAt,
  );
}

Plan _minimalPlanFromServerRecord(Map<String, dynamic> json) {
  return Plan(
    id: json['planId'] as String? ?? '',
    name: json['name'] as String? ?? 'Untitled Plan',
    createdAt: _safeParseDateTime(json['createdAt']) ?? DateTime.now(),
    updatedAt: _safeParseDateTime(json['updatedAt']) ?? DateTime.now(),
  );
}

/// Layers individually-typed fields from a partial `planJson` map onto a
/// [minimal] plan. Each field is parsed in isolation so a malformed entry
/// (e.g. an unknown step `runtimeType`) doesn't discard the rest of the body.
Plan _mergePartialPlanJson(Plan minimal, Map<String, dynamic> planJson) {
  List<PlanStep>? steps;
  final rawSteps = planJson['steps'];
  if (rawSteps is List) {
    final parsed = <PlanStep>[];
    for (final entry in rawSteps) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        parsed.add(PlanStep.fromJson(entry));
      } catch (e) {
        debugPrint(
          'parsePlanFromServerRecord: skipping unparseable step — $e',
        );
      }
    }
    steps = parsed;
  }

  final tags = planJson.containsKey('tags')
      ? tagsFromJson(planJson['tags'])
      : null;

  return minimal.copyWith(
    name: planJson['name'] as String? ?? minimal.name,
    description: planJson['description'] as String? ?? minimal.description,
    category: planJson['category'] as String? ?? minimal.category,
    defaultVoice: planJson['defaultVoice'] as String? ?? minimal.defaultVoice,
    tags: tags ?? minimal.tags,
    steps: steps ?? minimal.steps,
  );
}

DateTime? _safeParseDateTime(dynamic value) {
  if (value == null) return null;
  try {
    return DateTime.parse(value as String);
  } catch (_) {
    return null;
  }
}
