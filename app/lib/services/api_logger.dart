/// Logging HTTP client that wraps an inner [http.Client] and prints
/// request/response details to the debug console.
///
/// Drop-in replacement: pass [LoggingClient] anywhere an [http.Client] is
/// expected to get automatic API logging with zero changes to call sites.
library api_logger;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

/// An [http.BaseClient] decorator that logs every HTTP request and response.
///
/// Sensitive headers (`x-api-key`, `authorization`) are redacted automatically.
class LoggingClient extends http.BaseClient {
  LoggingClient([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  static const _tag = 'HTTP';

  /// Headers whose values should be masked in logs.
  static const _sensitiveHeaders = {'x-api-key', 'authorization'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    // ── Request ──────────────────────────────────────────────────────────
    final buf = StringBuffer()
      ..writeln('[$_tag] --> ${request.method} ${request.url}')
      ..writeln('[$_tag]     Headers: ${_redact(request.headers)}');

    if (request is http.Request && request.body.isNotEmpty) {
      buf.writeln('[$_tag]     Body: ${_truncate(request.body, 512)}');
    }

    debugPrint(buf.toString().trimRight());

    // ── Response ─────────────────────────────────────────────────────────
    try {
      final response = await _inner.send(request);
      stopwatch.stop();

      debugPrint(
        '[$_tag] <-- ${response.statusCode} ${request.method} '
        '${request.url} (${stopwatch.elapsedMilliseconds} ms, '
        '${response.contentLength ?? '?'} bytes)',
      );

      return response;
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        '[$_tag] <-- FAILED ${request.method} ${request.url} '
        '(${stopwatch.elapsedMilliseconds} ms): $e',
      );
      rethrow;
    }
  }

  @override
  void close() => _inner.close();

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Replaces values of sensitive headers with `***`.
  Map<String, String> _redact(Map<String, String> headers) {
    return {
      for (final entry in headers.entries)
        entry.key:
            _sensitiveHeaders.contains(entry.key.toLowerCase())
                ? '***'
                : entry.value,
    };
  }

  /// Truncates [value] to [maxLength] characters, appending `...` if trimmed.
  static String _truncate(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }
}
