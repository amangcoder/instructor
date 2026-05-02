// CreatePlanClient — calls backend endpoints to author and publish user plans.
//
// Supports two operations:
//   • createPlan — POST /api/plans with visibility=private, owner_user_id from JWT.
//   • requestPublish — POST /api/plans/:id/request-publish to transition
//     a private plan to pending_review for admin approval.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/app_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

final class CreatePlanException implements Exception {
  const CreatePlanException(this.message, {String? userMessage})
      : userMessage = userMessage ?? message;

  final String message;
  final String userMessage;

  @override
  String toString() => 'CreatePlanException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract interface for creating and publishing user-authored plans.
///
/// Separated from the concrete implementation so tests can supply fakes.
abstract class CreatePlanClient {
  /// Creates a new private plan on the server.
  ///
  /// The server sets `visibility='private'` and `owner_user_id` from the
  /// Authorization JWT — the client does not need to pass those explicitly.
  ///
  /// [steps] is an ordered list of user-authored instruction texts. Each entry
  /// is sent as a `{ type: 'say', text: '...' }` step payload.
  ///
  /// Returns the server-assigned plan UUID on success.
  /// Throws [CreatePlanException] on any failure.
  Future<String> createPlan({
    required String title,
    required List<String> steps,
    required String description,
  });

  /// Requests publication of a private plan.
  ///
  /// Calls POST /api/plans/:id/request-publish which transitions the plan's
  /// visibility from `private` → `pending_review`. Admins review it before
  /// it becomes publicly discoverable.
  ///
  /// Throws [CreatePlanException] on any failure.
  Future<void> requestPublish(String planId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Concrete implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal "say" step payload sent to POST /api/plans.
///
/// Maps one user-supplied text entry to a server-side SayStep record.
Map<String, dynamic> _sayStepPayload(String id, String text) => {
      'id': id,
      'type': 'say',
      'text': text,
    };

class CreatePlanClientImpl implements CreatePlanClient {
  CreatePlanClientImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> createPlan({
    required String title,
    required List<String> steps,
    required String description,
  }) async {
    final uri = Uri.parse('$kBackendUrl/api/plans');
    final stepPayloads = steps
        .asMap()
        .entries
        .map((e) => _sayStepPayload('step-${e.key}', e.value.trim()))
        .toList();

    try {
      final body = <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'steps': stepPayloads,
        'visibility': 'private',
      };
      final response = await _apiClient.postJson(uri, body);
      final id = response['id'];
      if (id is! String || id.isEmpty) {
        throw const CreatePlanException(
          'Server returned an unexpected response.',
          userMessage: 'Could not create your plan. Please try again.',
        );
      }
      return id;
    } on CreatePlanException {
      rethrow;
    } catch (e) {
      throw CreatePlanException(
        e.toString(),
        userMessage: 'Could not create your plan. Please try again.',
      );
    }
  }

  @override
  Future<void> requestPublish(String planId) async {
    final uri = Uri.parse('$kBackendUrl/api/plans/$planId/request-publish');
    try {
      await _apiClient.postJson(uri, <String, dynamic>{});
    } on CreatePlanException {
      rethrow;
    } catch (e) {
      throw CreatePlanException(
        e.toString(),
        userMessage: 'Could not submit your publish request. Please try again.',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

final createPlanClientProvider = Provider<CreatePlanClient>((ref) {
  return CreatePlanClientImpl(apiClient: ref.watch(apiClientProvider));
});
