// PlanRequestClient — calls the backend "Request a Plan" endpoint.
//
// Submits a user-authored description of a plan/schedule that isn't yet in
// the Discover library. The backend persists the request to the admin queue
// and emails the team.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/app_settings.dart';

final class PlanRequestException implements Exception {
  const PlanRequestException(this.message, {String? userMessage})
      : userMessage = userMessage ?? message;

  final String message;
  final String userMessage;

  @override
  String toString() => 'PlanRequestException: $message';
}

class PlanRequestClient {
  PlanRequestClient({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// Submits a plan request. Throws [PlanRequestException] on any non-201
  /// response. Returns the new request id on success.
  Future<String> submit({
    required String email,
    required String title,
    required String description,
    String? category,
  }) async {
    final uri = Uri.parse('$kBackendUrl/api/plans/requests');
    try {
      final body = <String, dynamic>{
        'email': email,
        'title': title,
        'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
      };
      final response = await _apiClient.postJson(uri, body);
      final id = response['id'];
      if (id is! String || id.isEmpty) {
        throw const PlanRequestException(
          'Server returned an unexpected response.',
          userMessage: 'Something went wrong. Please try again.',
        );
      }
      return id;
    } on PlanRequestException {
      rethrow;
    } catch (e) {
      throw PlanRequestException(
        e.toString(),
        userMessage: 'Could not submit your request. Please try again.',
      );
    }
  }
}

final planRequestClientProvider = Provider<PlanRequestClient>((ref) {
  return PlanRequestClient(apiClient: ref.watch(apiClientProvider));
});
