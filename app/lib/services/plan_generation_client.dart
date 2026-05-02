/// PlanGenerationClient — calls the backend AI plan generation endpoint.
///
/// Abstracts the POST /api/plans/generate call so that the
/// PlanGenerationScreen can be tested without a live backend.
library plan_generation_client;

import 'dart:developer' show debugger;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/api_client.dart';

part 'plan_generation_client.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when the plan generation API returns an error.
final class PlanGenerationException implements Exception {
  const PlanGenerationException(
    this.message, {
    String? userMessage,
  }) : userMessage = userMessage ?? message;

  final String message;

  /// User-friendly message suitable for display in the UI.
  final String userMessage;

  @override
  String toString() => 'PlanGenerationException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract interface for generating plans via an AI backend.
abstract class PlanGenerationClient {
  /// Generates a structured [Plan] from a natural-language [prompt].
  ///
  /// [fallbackVoice] is used when the server response is missing a voice field.
  /// It should be the active provider's default voice so the generated plan is
  /// immediately compatible with TTS activation.
  ///
  /// Throws [PlanGenerationException] on API errors (4xx, 5xx, network failure).
  Future<Plan> generatePlan(
    String prompt, {
    String? category,
    String? language,
    String fallbackVoice = 'af_heart',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Production [PlanGenerationClient] backed by the NestJS backend.
class PlanGenerationClientImpl implements PlanGenerationClient {
  const PlanGenerationClientImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<Plan> generatePlan(
    String prompt, {
    String? category,
    String? language,
    String fallbackVoice = 'af_heart',
  }) async {
    final baseUrl = await _apiClient.backendBaseUrl;
    final uri = Uri.parse('$baseUrl/api/plans/generate');

    final body = <String, dynamic>{'prompt': prompt};
    if (category != null && category.isNotEmpty) {
      body['category'] = category;
    }
    if (language != null && language.isNotEmpty) {
      body['language'] = language;
    }

    // Breakpoint: inspect `uri` and `body` before the request fires.
    // debugger(message: 'PlanGen: about to POST');

    try {
      final response = await _apiClient.postJson(uri, body);

      // Breakpoint: inspect raw `response` from the server.
      // debugger(message: 'PlanGen: received response');

      final planJson = response['plan'] as Map<String, dynamic>?;

      if (planJson == null) {
        // Breakpoint: response unexpectedly missing the "plan" key.
        // debugger(message: 'PlanGen: missing plan key in response');
        throw const PlanGenerationException(
          'Server returned an invalid response (missing plan).',
          userMessage: 'Plan generation failed. Please try again.',
        );
      }

      final plan = _parsePlan(planJson, fallbackVoice: fallbackVoice);

      // Breakpoint: inspect parsed `plan` before navigating away.
      // debugger(message: 'PlanGen: plan parsed successfully');

      return plan;
    } on ApiException catch (e) {
      // Breakpoint: inspect `e.statusCode` and `e.message` on API errors.
      // debugger(message: 'PlanGen: ApiException');
      throw PlanGenerationException(
        'API error: ${e.message}',
        userMessage: _friendlyError(e),
      );
    } catch (e) {
      if (e is PlanGenerationException) rethrow;
      debugPrint('PlanGenerationClient: unexpected error: $e');
      throw PlanGenerationException(
        e.toString(),
        userMessage: 'Plan generation failed. Please try again.',
      );
    }
  }

  String _friendlyError(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return 'Please log in to use AI plan generation.';
      case 422:
        return 'The AI could not generate a valid plan. Try rephrasing your description.';
      case 429:
        return 'Your plan generation request was rate-limited. Try again in 30 minutes.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return 'Plan generation failed (${e.statusCode ?? 'network error'}). Please try again.';
    }
  }

  Plan _parsePlan(Map<String, dynamic> json, {String fallbackVoice = 'af_heart'}) {
    final stepsRaw = json['steps'] as List<dynamic>? ?? [];
    final steps = stepsRaw
        .map((s) => PlanStep.fromJson(_normalizeStep(s as Map<String, dynamic>)))
        .toList();

    return Plan(
      id: '', // temporary — assigned on save
      name: json['name']?.toString() ?? 'Untitled Plan',
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? 'custom',
      defaultVoice: json['defaultVoice']?.toString() ?? fallbackVoice,
      steps: steps,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Converts a server-format step (uses `type`, field names from Gemini schema)
  /// into the freezed-compatible format (uses `runtimeType`, Flutter field names).
  Map<String, dynamic> _normalizeStep(Map<String, dynamic> step) {
    final type = step['type'] as String?;
    final id = const Uuid().v4();
    return switch (type) {
      'say' => {
          'runtimeType': 'say',
          'id': id,
          'text': step['text'] as String,
          if (step['voice'] != null) 'voiceId': step['voice'] as String,
        },
      'wait' => {
          'runtimeType': 'wait',
          'id': id,
          'duration': Duration(seconds: (step['durationSeconds'] as num).toInt()).inMicroseconds,
        },
      'notify' => {
          'runtimeType': 'notify',
          'id': id,
          'title': step['message'] as String,
          'body': step['message'] as String,
        },
      'play' => {
          'runtimeType': 'play',
          'id': id,
          'audioAssetKey': step['assetKey'] as String,
        },
      'stopAudio' => {
          'runtimeType': 'stopAudio',
          'id': id,
        },
      'count' => {
          'runtimeType': 'count',
          'id': id,
          'from': (step['from'] as num).toInt(),
          'to': (step['to'] as num).toInt(),
          if (step['intervalSeconds'] != null)
            'intervalSeconds': (step['intervalSeconds'] as num).toInt(),
        },
      'repeat' => {
          'runtimeType': 'repeat',
          'id': id,
          'count': (step['count'] as num).toInt(),
          'children': (step['steps'] as List<dynamic>)
              .map((s) => _normalizeStep(s as Map<String, dynamic>))
              .toList(),
        },
      _ => throw PlanGenerationException('Unknown step type: $type'),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
PlanGenerationClient planGenerationClient(Ref ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlanGenerationClientImpl(apiClient: apiClient);
}
