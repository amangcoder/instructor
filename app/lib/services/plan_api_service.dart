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

import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when any [PlanApiService] call encounters an error.
///
/// [message] is the raw technical error; [userMessage] is safe to display
/// in the UI without leaking internal details.
final class PlanApiException implements Exception {
  const PlanApiException(this.message, {String? userMessage})
      : userMessage = userMessage ?? message;

  final String message;

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
  Future<void> activatePlan(String planId);

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
  Future<void> activatePlan(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/activate');
    try {
      await _client.postJson(uri, {
        'planId': planId,
        // 'studio' triggers server-side TTS pre-generation (GenAI voice).
        'voiceQuality': 'studio',
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

  // ── Private parsers ───────────────────────────────────────────────────────

  /// Builds a [Plan] from a list-endpoint summary (no steps / planJson).
  ///
  /// The server list endpoint (`GET /api/plans/list`) omits `planJson` to
  /// reduce response size. Missing fields default per the [Plan] model.
  Plan _parsePlanSummary(Map<String, dynamic> json) {
    return Plan(
      id: json['planId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Plan',
      isActive: json['isActive'] as bool? ?? false,
      ttsStatus: json['ttsStatus'] as String? ?? 'none',
      ttsTotal: (json['ttsTotal'] as num?)?.toInt() ?? 0,
      ttsCompleted: (json['ttsCompleted'] as num?)?.toInt() ?? 0,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Builds a full [Plan] from a single-plan response (`GET /api/plans/:id`).
  ///
  /// The response includes a `planJson` field containing the serialised
  /// [Plan] object. Server-managed fields (id, isActive, ttsStatus, etc.) are
  /// overlaid on top of the parsed plan to ensure they reflect server state.
  Plan _parsePlanResponse(Map<String, dynamic> json) {
    final planJsonStr = json['planJson'] as String?;
    Plan base;

    if (planJsonStr != null && planJsonStr.isNotEmpty) {
      try {
        final planJson = jsonDecode(planJsonStr) as Map<String, dynamic>;
        base = Plan.fromJson(planJson);
      } catch (e) {
        debugPrint(
            'PlanApiService._parsePlanResponse: failed to parse planJson — $e');
        base = _minimalPlan(json);
      }
    } else {
      base = _minimalPlan(json);
    }

    // Server-managed fields always override what the planJson blob contains.
    return base.copyWith(
      id: json['planId'] as String? ?? base.id,
      isActive: json['isActive'] as bool? ?? base.isActive,
      ttsStatus: json['ttsStatus'] as String? ?? base.ttsStatus,
      ttsTotal: (json['ttsTotal'] as num?)?.toInt() ?? base.ttsTotal,
      ttsCompleted:
          (json['ttsCompleted'] as num?)?.toInt() ?? base.ttsCompleted,
      updatedAt:
          _parseDateTime(json['updatedAt']) ?? base.updatedAt,
    );
  }

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
  /// format as user plans. If parsing fails, falls back to top-level fields.
  Plan _parseLibraryPlanDetail(String id, Map<String, dynamic> json) {
    final planJsonStr = json['planJson'] as String?;

    if (planJsonStr != null && planJsonStr.isNotEmpty) {
      try {
        final planJson = jsonDecode(planJsonStr) as Map<String, dynamic>;
        // Use the library plan's own id as the plan id.
        final withId = Map<String, dynamic>.from(planJson)
          ..['id'] = json['id'] as String? ?? id;
        return Plan.fromJson(withId);
      } catch (e) {
        debugPrint(
            'PlanApiService._parseLibraryPlanDetail: failed to parse planJson — $e');
      }
    }

    // Fallback: build a minimal Plan from top-level response fields.
    final category = _parseCategory(json['category'] as String?);
    return Plan(
      id: json['id'] as String? ?? id,
      name: json['name'] as String? ?? 'Untitled Plan',
      description: json['description'] as String?,
      category: category,
      defaultVoice: json['defaultVoice'] as String? ?? 'aoede',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // ── Private utilities ─────────────────────────────────────────────────────

  /// Creates a bare-minimum [Plan] from top-level response fields only.
  Plan _minimalPlan(Map<String, dynamic> json) {
    return Plan(
      id: json['planId'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Plan',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  /// Converts a [PlanCategory] string from the server to the enum value.
  PlanCategory _parseCategory(String? raw) {
    if (raw == null) return PlanCategory.custom;
    return PlanCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => PlanCategory.custom,
    );
  }

  /// Splits a comma-separated tags string into a trimmed [List<String>].
  List<String> _parseTags(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Safely parses an ISO-8601 date-time string, returning null on failure.
  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value as String);
    } catch (_) {
      return null;
    }
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

