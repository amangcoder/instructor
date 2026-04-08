/// ApiClient — authenticated HTTP client with automatic JWT refresh.
///
/// Wraps [http.Client] to inject the Authorization header and transparently
/// handle 401 responses by refreshing the access token once and retrying.
///
/// Usage:
/// ```dart
/// final client = ref.read(apiClientProvider);
/// final response = await client.get(Uri.parse('...'));
/// ```
library api_client;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/services/app_settings.dart';
import 'package:instructor/services/auth_service.dart';

part 'api_client.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoggingClient (re-export alias so tts_service.dart can keep importing it)
// ─────────────────────────────────────────────────────────────────────────────

/// HTTP client that logs every request/response pair.
///
/// Used by [TTSServiceImpl] and exposed via [loggingClientProvider].
class LoggingClient extends http.BaseClient {
  LoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    debugPrint('→ ${request.method} ${request.url}');
    final response = await _inner.send(request);
    debugPrint('← ${response.statusCode} ${request.url}');
    return response;
  }

  @override
  void close() => _inner.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// ApiClient
// ─────────────────────────────────────────────────────────────────────────────

/// Authenticated HTTP client that:
/// 1. Adds `Authorization: Bearer <token>` to every request.
/// 2. Falls back to `x-api-key` header for backward compatibility if no JWT.
/// 3. Retries once after token refresh on 401 responses.
/// 4. Exposes convenience [getJson] / [postJson] helpers.
class ApiClient {
  ApiClient({
    required AuthService authService,
    required AppSettings settings,
    http.Client? httpClient,
  })  : _auth = authService,
        _settings = settings,
        _inner = httpClient ?? LoggingClient();

  final AuthService _auth;
  final AppSettings _settings;
  final http.Client _inner;

  // ── Low-level request ──────────────────────────────────────────────────

  /// Sends [request], injecting auth headers.
  ///
  /// On 401, refreshes the token once and retries. If the retry also returns
  /// 401, calls [_auth.logout] and rethrows.
  Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final req = await _buildRequest(method, uri, headers, body);
    var response = await _inner.send(req).then(http.Response.fromStream);

    if (response.statusCode == 401) {
      debugPrint('ApiClient: 401 received, attempting token refresh…');
      try {
        await _auth.refreshToken();
        // Retry with fresh token.
        final retryReq = await _buildRequest(method, uri, headers, body);
        response = await _inner.send(retryReq).then(http.Response.fromStream);
        if (response.statusCode == 401) {
          // Refresh didn't help — clear tokens.
          await _auth.logout();
        }
      } catch (e) {
        debugPrint('ApiClient: token refresh failed ($e), logging out.');
        await _auth.logout();
        rethrow;
      }
    }

    return response;
  }

  // ── Convenience helpers ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final response = await send('GET', uri);
    return _parseJson(response);
  }

  Future<Map<String, dynamic>> postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await send(
      'POST',
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _parseJson(response);
  }

  String get backendBaseUrl => kBackendUrl;

  // ── Private helpers ────────────────────────────────────────────────────

  Future<http.Request> _buildRequest(
    String method,
    Uri uri,
    Map<String, String>? extraHeaders,
    Object? body,
  ) async {
    final req = http.Request(method, uri);

    // Auth headers — prefer JWT over API key.
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    } else {
      final apiKey =
          await _settings.read(AppSettingsKeys.backendApiKey) ?? '';
      if (apiKey.isNotEmpty) {
        req.headers['x-api-key'] = apiKey;
      }
    }

    if (extraHeaders != null) req.headers.addAll(extraHeaders);
    if (body != null) {
      if (body is String) {
        req.body = body;
      } else if (body is List<int>) {
        req.bodyBytes = body;
      }
    }
    return req;
  }

  Map<String, dynamic> _parseJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'API error: ${response.body}',
        statusCode: response.statusCode,
      );
    }
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  }
}

/// Thrown when an API call returns a non-2xx status code.
final class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${statusCode ?? '?'}): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final auth = ref.watch(authServiceProvider);
  final settings = ref.watch(appSettingsProvider);
  return ApiClient(authService: auth, settings: settings);
}
