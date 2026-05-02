// SeriesApiService — HTTP layer for series + subscription endpoints.
//
// Wraps ApiClient for all /api/series/* calls. Mirrors PlanApiService's
// abstract + Impl structure so tests can substitute a fake.

import 'dart:convert';

import 'package:instructor/exceptions/app_exception.dart';
import 'package:instructor/models/series.dart';
import 'package:instructor/models/series_subscription.dart';
import 'package:instructor/services/api_client.dart';
import 'package:instructor/services/plan_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Exception
// ─────────────────────────────────────────────────────────────────────────────

final class SeriesApiException extends PlanAppException {
  const SeriesApiException(super.message, {String? userMessage})
      : userMessage = userMessage ?? message;

  final String userMessage;

  @override
  String toString() => 'SeriesApiException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class SeriesApiService {
  /// `GET /api/series` — list published series (no sessions).
  Future<List<Series>> listPublished();

  /// `GET /api/series/:id` — series detail including ordered sessions.
  Future<Series> getById(String id);

  /// `GET /api/series/me/subscriptions` — current user's subscriptions.
  Future<List<SeriesSubscription>> mySubscriptions({bool activeOnly = false});

  /// `POST /api/series/:id/subscribe` — idempotent opt-in.
  Future<SeriesSubscription> subscribe(String seriesId);

  /// `POST /api/series/:id/pause`
  Future<SeriesSubscription> pause(String seriesId);

  /// `POST /api/series/:id/resume`
  Future<SeriesSubscription> resume(String seriesId);

  /// `POST /api/series/:id/unsubscribe`
  Future<SeriesSubscription> unsubscribe(String seriesId);

  /// `POST /api/series/:id/progress` — record completion of [sessionIndex].
  Future<SeriesSubscription> recordProgress(String seriesId, int sessionIndex);
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementation
// ─────────────────────────────────────────────────────────────────────────────

class SeriesApiServiceImpl implements SeriesApiService {
  const SeriesApiServiceImpl({required ApiClient apiClient})
      : _client = apiClient;

  final ApiClient _client;

  String _base() => '${_client.backendBaseUrl}/api/series';

  @override
  Future<List<Series>> listPublished() async {
    final uri = Uri.parse(_base());
    try {
      final response = await _client.send('GET', uri);
      _ensureOk(response.statusCode, response.body);
      final list = _decodeJsonList(response.body);
      return list.map(Series.fromJson).toList();
    } catch (e) {
      throw _wrap(e, 'Failed to load programs.');
    }
  }

  @override
  Future<Series> getById(String id) async {
    final uri = Uri.parse('${_base()}/$id');
    try {
      final response = await _client.getJson(uri);
      // Server returns sessions as `PlanRecord` rows (planId/planJson/etc.).
      // Decode them into Plan-shape via parsePlanFromServerRecord before
      // handing the payload to Series.fromJson.
      final sessionsRaw = response['sessions'] as List<dynamic>? ?? const [];
      final parsedSessions = sessionsRaw
          .whereType<Map<String, dynamic>>()
          .map(parsePlanFromServerRecord)
          .toList(growable: false);
      final shaped = Map<String, dynamic>.from(response)..remove('sessions');
      final series = Series.fromJson(shaped);
      return series.copyWith(sessions: parsedSessions);
    } catch (e) {
      throw _wrap(e, 'Failed to load this program.');
    }
  }

  @override
  Future<List<SeriesSubscription>> mySubscriptions({bool activeOnly = false}) async {
    final uri = Uri.parse('${_base()}/me/subscriptions')
        .replace(queryParameters: activeOnly ? {'activeOnly': 'true'} : null);
    try {
      final response = await _client.send('GET', uri);
      _ensureOk(response.statusCode, response.body);
      final list = _decodeJsonList(response.body);
      return list.map(SeriesSubscription.fromJson).toList();
    } catch (e) {
      throw _wrap(e, 'Failed to load your programs.');
    }
  }

  @override
  Future<SeriesSubscription> subscribe(String seriesId) =>
      _postSubscriptionAction(seriesId, 'subscribe', 'Failed to start program.');

  @override
  Future<SeriesSubscription> pause(String seriesId) =>
      _postSubscriptionAction(seriesId, 'pause', 'Failed to pause program.');

  @override
  Future<SeriesSubscription> resume(String seriesId) =>
      _postSubscriptionAction(seriesId, 'resume', 'Failed to resume program.');

  @override
  Future<SeriesSubscription> unsubscribe(String seriesId) =>
      _postSubscriptionAction(seriesId, 'unsubscribe', 'Failed to cancel program.');

  @override
  Future<SeriesSubscription> recordProgress(
    String seriesId,
    int sessionIndex,
  ) async {
    final uri = Uri.parse('${_base()}/$seriesId/progress');
    try {
      final response = await _client.postJson(uri, {'sessionIndex': sessionIndex});
      return SeriesSubscription.fromJson(response);
    } catch (e) {
      throw _wrap(e, 'Failed to update progress.');
    }
  }

  Future<SeriesSubscription> _postSubscriptionAction(
    String seriesId,
    String action,
    String userMessage,
  ) async {
    final uri = Uri.parse('${_base()}/$seriesId/$action');
    try {
      final response = await _client.postJson(uri, const {});
      return SeriesSubscription.fromJson(response);
    } catch (e) {
      throw _wrap(e, userMessage);
    }
  }

  void _ensureOk(int statusCode, String body) {
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException('API error: $body', statusCode: statusCode);
    }
  }

  List<Map<String, dynamic>> _decodeJsonList(String body) {
    if (body.isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded.cast<Map<String, dynamic>>();
    return const [];
  }

  SeriesApiException _wrap(Object e, String userMessage) {
    if (e is SeriesApiException) return e;
    if (e is ApiException) {
      return SeriesApiException(e.message, userMessage: userMessage);
    }
    return SeriesApiException(e.toString(), userMessage: userMessage);
  }
}
