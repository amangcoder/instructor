/// PlanSharingService — HTTP client for plan sharing operations.
///
/// Wraps [ApiClient] to provide authenticated share/revoke calls and an
/// unauthenticated fetch for public shared-plan previews.
///
/// Usage:
/// ```dart
/// final service = ref.read(planSharingServiceProvider);
/// final url = await service.sharePlan(planId);
/// ```
library plan_sharing_service;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/shared_plan_preview.dart';
import 'package:instructor/services/api_client.dart';

part 'plan_sharing_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when any [PlanSharingService] call encounters an error.
///
/// [message] is the raw technical error; [userMessage] is safe to display
/// in the UI without leaking internal details.
final class PlanSharingException implements Exception {
  const PlanSharingException(this.message, {String? userMessage, this.statusCode})
      : userMessage = userMessage ?? message;

  final String message;

  /// User-friendly message suitable for display in the UI.
  final String userMessage;

  /// HTTP status code from the server response, if available.
  final int? statusCode;

  @override
  String toString() => 'PlanSharingException(${statusCode ?? '?'}): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// HTTP client for plan sharing operations.
abstract class PlanSharingService {
  /// POST /api/plans/:id/share
  ///
  /// Generates a share token for [planId] and returns the full share URL
  /// (e.g. `https://instructor.app/s/abc123`).
  ///
  /// Idempotent: calling again returns the existing token/URL.
  ///
  /// Throws [PlanSharingException] on error:
  /// - `statusCode == 404`: plan not found.
  /// - `statusCode == 429`: rate limited.
  Future<String> sharePlan(String planId);

  /// DELETE /api/plans/:id/share
  ///
  /// Revokes the share token for [planId], invalidating the short URL.
  ///
  /// Throws [PlanSharingException] on error:
  /// - `statusCode == 404`: plan not found or was never shared.
  Future<void> revokePlanSharing(String planId);

  /// GET /api/plans/shared/:shareToken  (unauthenticated)
  ///
  /// Fetches a public [SharedPlanPreview] for the given [shareToken].
  /// No authorization header is sent, so this works for any viewer.
  ///
  /// Throws [PlanSharingException] on error:
  /// - `statusCode == 404`: plan not found or link was revoked.
  /// - `statusCode == 429`: rate limited.
  Future<SharedPlanPreview> fetchSharedPlan(String shareToken);

  /// POST /api/plans/shared/save  (authenticated)
  ///
  /// Creates a copy of [plan] in the current user's library.
  ///
  /// Throws [PlanSharingException] on error:
  /// - `statusCode == 401`: user is not authenticated.
  /// - `statusCode == 429`: rate limited.
  Future<void> saveSharedPlanToLibrary(SharedPlanPreview plan);
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Production [PlanSharingService] backed by the NestJS backend.
///
/// Uses [ApiClient] for authenticated calls ([sharePlan], [revokePlanSharing])
/// and a plain [http.Client] for the unauthenticated [fetchSharedPlan] endpoint.
class PlanSharingServiceImpl implements PlanSharingService {
  PlanSharingServiceImpl({
    required ApiClient apiClient,
    http.Client? httpClient,
  })  : _client = apiClient,
        _http = httpClient ?? http.Client();

  final ApiClient _client;

  /// Plain HTTP client for unauthenticated public endpoint calls.
  final http.Client _http;

  // ── sharePlan ─────────────────────────────────────────────────────────────

  @override
  Future<String> sharePlan(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/$planId/share');
    try {
      final response = await _client.send('POST', uri,
          headers: {'Content-Type': 'application/json'});
      _ensureSuccess(response.statusCode, 'POST /api/plans/$planId/share');

      final json = _decodeJson(response.body);
      final shareUrl = json['shareUrl'] as String?;
      if (shareUrl == null || shareUrl.isEmpty) {
        throw const PlanSharingException(
          'Server returned no shareUrl',
          userMessage: 'Failed to generate share link. Please try again.',
        );
      }
      return shareUrl;
    } on PlanSharingException {
      rethrow;
    } on ApiException catch (e) {
      throw PlanSharingException(
        'sharePlan($planId) failed: ${e.message}',
        userMessage: _friendlyError(e.statusCode),
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('PlanSharingService.sharePlan: unexpected error: $e');
      throw PlanSharingException(
        e.toString(),
        userMessage: 'Failed to generate share link. Please try again.',
      );
    }
  }

  // ── revokePlanSharing ─────────────────────────────────────────────────────

  @override
  Future<void> revokePlanSharing(String planId) async {
    final uri = Uri.parse('${_client.backendBaseUrl}/api/plans/$planId/share');
    try {
      final response = await _client.send('DELETE', uri);
      _ensureSuccess(response.statusCode, 'DELETE /api/plans/$planId/share');
    } on PlanSharingException {
      rethrow;
    } on ApiException catch (e) {
      throw PlanSharingException(
        'revokePlanSharing($planId) failed: ${e.message}',
        userMessage: _friendlyError(e.statusCode),
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('PlanSharingService.revokePlanSharing: unexpected error: $e');
      throw PlanSharingException(
        e.toString(),
        userMessage: 'Failed to revoke share link. Please try again.',
      );
    }
  }

  // ── fetchSharedPlan ───────────────────────────────────────────────────────

  @override
  Future<SharedPlanPreview> fetchSharedPlan(String shareToken) async {
    final uri = Uri.parse(
        '${_client.backendBaseUrl}/api/plans/shared/$shareToken');
    try {
      // Use plain HTTP client — this endpoint requires no authentication.
      final response = await _http.get(uri);
      if (response.statusCode == 404) {
        throw const PlanSharingException(
          'Shared plan not found',
          userMessage: 'This plan link has expired or been revoked.',
          statusCode: 404,
        );
      }
      if (response.statusCode == 429) {
        throw const PlanSharingException(
          'Rate limited',
          userMessage: 'Too many requests. Please wait a moment and try again.',
          statusCode: 429,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PlanSharingException(
          'fetchSharedPlan($shareToken) returned ${response.statusCode}',
          userMessage: 'Failed to load shared plan. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final json = _decodeJson(response.body);
      return _parseSharedPlanPreview(json);
    } on PlanSharingException {
      rethrow;
    } catch (e) {
      debugPrint('PlanSharingService.fetchSharedPlan: unexpected error: $e');
      throw PlanSharingException(
        e.toString(),
        userMessage: 'Failed to load shared plan. Please try again.',
      );
    }
  }

  // ── saveSharedPlanToLibrary ───────────────────────────────────────────────

  @override
  Future<void> saveSharedPlanToLibrary(SharedPlanPreview plan) async {
    final uri =
        Uri.parse('${_client.backendBaseUrl}/api/plans/shared/save');
    try {
      final response = await _client.send(
        'POST',
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': plan.name,
          if (plan.description != null) 'description': plan.description,
          'steps': plan.steps,
          'stepCount': plan.stepCount,
          'estimatedDurationMs': plan.estimatedDurationMs,
        }),
      );
      _ensureSuccess(
          response.statusCode, 'POST /api/plans/shared/save');
    } on PlanSharingException {
      rethrow;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw const PlanSharingException(
          'Not authenticated',
          userMessage: 'Please log in to save plans.',
          statusCode: 401,
        );
      }
      throw PlanSharingException(
        'saveSharedPlanToLibrary failed: ${e.message}',
        userMessage: _friendlyError(e.statusCode),
        statusCode: e.statusCode,
      );
    } catch (e) {
      debugPrint('PlanSharingService.saveSharedPlanToLibrary: unexpected error: $e');
      throw PlanSharingException(
        e.toString(),
        userMessage: 'Failed to save plan. Please try again.',
      );
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Throws [PlanSharingException] when [statusCode] indicates failure.
  void _ensureSuccess(int statusCode, String endpoint) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw PlanSharingException(
      '$endpoint returned $statusCode',
      userMessage: _friendlyError(statusCode),
      statusCode: statusCode,
    );
  }

  /// Parses the raw JSON [body] into a map; returns `{}` on empty body.
  Map<String, dynamic> _decodeJson(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Builds a [SharedPlanPreview] from the server response JSON.
  SharedPlanPreview _parseSharedPlanPreview(Map<String, dynamic> json) {
    final steps = json['steps'] as List<dynamic>? ?? const [];
    return SharedPlanPreview(
      name: json['name'] as String? ?? 'Untitled Plan',
      description: json['description'] as String?,
      steps: steps,
      stepCount: (json['stepCount'] as num?)?.toInt() ?? steps.length,
      estimatedDurationMs:
          (json['estimatedDurationMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Returns a user-friendly error message for common HTTP status codes.
  String _friendlyError(int? statusCode) {
    return switch (statusCode) {
      401 => 'Please log in to continue.',
      403 => 'You do not have permission to perform this action.',
      404 => 'Plan not found or link has been revoked.',
      429 => 'Too many requests. Please wait a moment and try again.',
      500 || 502 || 503 => 'Server error. Please try again later.',
      _ =>
        'An error occurred (${statusCode ?? 'network error'}). Please try again.',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
PlanSharingService planSharingService(Ref ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlanSharingServiceImpl(apiClient: apiClient);
}
