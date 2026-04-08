/// AuthService — email + OTP authentication with secure token storage.
///
/// ## Flow
/// 1. [requestOtp] → POST /api/auth/request-otp — server emails a 6-digit OTP.
/// 2. [verifyOtp]  → POST /api/auth/verify-otp  — exchange OTP for JWT tokens.
/// 3. Tokens stored in [flutter_secure_storage] (Keychain / EncryptedSharedPrefs).
/// 4. [refreshToken] → POST /api/auth/refresh   — renew access token (called
///    automatically by [ApiClient] on 401 responses).
/// 5. [logout] clears stored tokens and resets state.
///
/// ## Sync state
/// [isAuthenticated] and [getUser] are synchronous (in-memory cache) so that
/// screens can check auth state without awaiting. The cache is populated on
/// startup via [isLoggedIn] and updated after every [verifyOtp]/[logout].
library auth_service;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/services/app_settings.dart';

part 'auth_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Storage keys
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _StorageKeys {
  static const String accessToken = 'auth_access_token';
  static const String refreshToken = 'auth_refresh_token';
  static const String userId = 'auth_user_id';
  static const String userEmail = 'auth_user_email';
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when an auth API call returns an unexpected response.
final class AuthException implements Exception {
  const AuthException(this.message, {this.statusCode, String? userMessage})
      : userMessage = userMessage ?? message;

  final String message;
  final int? statusCode;

  /// User-facing message (may differ from raw [message]).
  final String userMessage;

  @override
  String toString() => 'AuthException(${statusCode ?? '?'}): $message';

  /// Converts a raw status code + body into a user-friendly message.
  static AuthException fromResponse(int statusCode, String body) {
    // Try to extract a server-provided message.
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final serverMsg = json['message']?.toString();
      if (serverMsg != null && serverMsg.isNotEmpty) {
        final humanized = _humanize(serverMsg);
        return AuthException(humanized, statusCode: statusCode, userMessage: humanized);
      }
    } catch (_) {}

    final fallback = _httpFallback(statusCode);
    return AuthException(fallback, statusCode: statusCode, userMessage: fallback);
  }

  static String _humanize(String raw) {
    // Convert common server error strings to user-friendly text.
    final lower = raw.toLowerCase();
    if (lower.contains('otp expired') || lower.contains('otp') && lower.contains('expired')) {
      return 'OTP expired. Please request a new one.';
    }
    if (lower.contains('refresh token') || lower.contains('session expired')) {
      return 'Session expired. Please log in again.';
    }
    if (lower.contains('invalid otp') ||
        lower.contains('invalid code')) return 'Invalid OTP. Please try again.';
    if (lower.contains('too many') ||
        lower.contains('rate limit')) {
      return 'Too many attempts. Please wait before trying again.';
    }
    if (lower.contains('locked')) {
      return 'Too many failed attempts. Please request a new OTP.';
    }
    return raw;
  }

  static String _httpFallback(int code) {
    switch (code) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Session expired. Please log in again.';
      case 422:
        return 'Invalid OTP. Please try again.';
      case 429:
        return 'Too many requests. Please wait and try again.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return 'Unexpected error (HTTP $code).';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network exception
// ─────────────────────────────────────────────────────────────────────────────

/// Thrown when a network-level error occurs (e.g. no connectivity).
final class NetworkException implements Exception {
  const NetworkException(this.message);

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class AuthService {
  // ── Sync state (in-memory cache) ──────────────────────────────────────────

  /// Whether a valid JWT is present (from in-memory cache).
  bool get isAuthenticated;

  /// Currently logged-in user from in-memory cache, or null.
  ///
  /// Returns synchronously. Populated after [verifyOtp] and persisted across
  /// restarts via [isLoggedIn].
  AuthUser? getUser();

  /// Stream of [AuthState] changes (login, logout, token refresh).
  Stream<AuthState> get authStateStream;

  // ── Async operations ───────────────────────────────────────────────────────

  /// Requests a 6-digit OTP to be sent to [email].
  Future<void> requestOtp(String email);

  /// Alias for [requestOtp] — provided for consistency with earlier API shapes.
  Future<void> requestOtpWithAuth(String email);

  /// Verifies [otp] for [email], stores tokens, and updates the in-memory cache.
  Future<AuthResult> verifyOtp(String email, String otp);

  /// Exchanges the stored refresh token for a new access token.
  ///
  /// Updates the cached access token. Throws [AuthException] if expired.
  Future<void> refreshToken();

  /// Clears all stored tokens and resets the in-memory cache.
  Future<void> logout();

  // ── Optional async operations (default implementations) ───────────────────

  /// Returns the stored access token. Returns null for test stubs that don't
  /// override this method.
  Future<String?> getAccessToken() async => null;

  /// Returns true if a valid session exists in secure storage.
  ///
  /// Also populates the in-memory cache so that subsequent calls to [getUser]
  /// and [isAuthenticated] are synchronous.
  ///
  /// Defaults to [isAuthenticated] for test stubs.
  Future<bool> isLoggedIn() async => isAuthenticated;
}

// ─────────────────────────────────────────────────────────────────────────────
// Production implementation
// ─────────────────────────────────────────────────────────────────────────────

/// Production [AuthService] backed by [FlutterSecureStorage].
class AuthServiceImpl implements AuthService {
  AuthServiceImpl({
    required AppSettings settings,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _settings = settings,
        _storage = storage ?? const FlutterSecureStorage(),
        _httpClient = httpClient ?? http.Client();

  final AppSettings _settings;
  final FlutterSecureStorage _storage;
  final http.Client _httpClient;

  // ── In-memory cache ─────────────────────────────────────────────────────

  AuthUser? _cachedUser;
  bool _isAuthenticated = false;
  final _authStateController = StreamController<AuthState>.broadcast();

  /// Guards concurrent [refreshToken] calls so only one HTTP request is
  /// in-flight at a time. Subsequent callers await the same future.
  Completer<void>? _refreshInFlight;

  /// Maximum number of retries for transient network errors.
  static const int _kMaxRetries = 3;
  static const Duration _kRetryBase = Duration(seconds: 1);

  // ── Sync getters ────────────────────────────────────────────────────────

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  AuthUser? getUser() => _cachedUser;

  @override
  Stream<AuthState> get authStateStream => _authStateController.stream;

  // ── Public API ─────────────────────────────────────────────────────────

  @override
  Future<void> requestOtp(String email) async {
    final url = await _buildUrl('/api/auth/request-otp');
    await _post(url, {'email': email});
    debugPrint('AuthService: OTP requested for $email');
  }

  @override
  Future<void> requestOtpWithAuth(String email) => requestOtp(email);

  @override
  Future<AuthResult> verifyOtp(String email, String otp) async {
    final url = await _buildUrl('/api/auth/verify-otp');
    final data = await _post(url, {'email': email, 'otp': otp});
    final result = AuthResult.fromJson(data);

    // Store tokens securely.
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: result.accessToken),
      _storage.write(
          key: _StorageKeys.refreshToken, value: result.refreshToken),
      _storage.write(key: _StorageKeys.userId, value: result.user.id),
      _storage.write(key: _StorageKeys.userEmail, value: result.user.email),
    ]);

    // Update in-memory cache.
    _cachedUser = result.user;
    _isAuthenticated = true;
    _authStateController.add(
        Authenticated(user: result.user, accessToken: result.accessToken));

    debugPrint('AuthService: OTP verified, tokens stored for ${result.user.email}');
    return result;
  }

  @override
  Future<void> refreshToken() async {
    // If a refresh is already in-flight, piggyback on it instead of
    // firing a second HTTP request (prevents race conditions when
    // multiple concurrent 401s trigger simultaneous refreshes).
    if (_refreshInFlight != null) {
      return _refreshInFlight!.future;
    }

    _refreshInFlight = Completer<void>();
    try {
      await _doRefreshToken();
      _refreshInFlight!.complete();
    } catch (e) {
      _refreshInFlight!.completeError(e);
      rethrow;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// The actual refresh logic, called under the [_refreshInFlight] mutex.
  Future<void> _doRefreshToken() async {
    final storedRefresh =
        await _storage.read(key: _StorageKeys.refreshToken);
    if (storedRefresh == null || storedRefresh.isEmpty) {
      throw const AuthException('No refresh token found. Please log in again.');
    }

    final url = await _buildUrl('/api/auth/refresh');
    final data = await _post(url, {'refreshToken': storedRefresh});
    final newAccessToken = data['accessToken']?.toString() ?? '';
    final newRefreshToken = data['refreshToken']?.toString() ?? '';

    if (newAccessToken.isEmpty) {
      throw const AuthException('Server returned an empty access token.');
    }

    // Store both tokens — the server uses refresh-token rotation, so the
    // old refresh token is revoked on every use. If we don't persist the
    // new one, the next refresh attempt will fail with 401.
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: newAccessToken),
      if (newRefreshToken.isNotEmpty)
        _storage.write(key: _StorageKeys.refreshToken, value: newRefreshToken),
    ]);

    // Update cache (user stays the same, only access token changes).
    if (_cachedUser != null) {
      _authStateController.add(
          Authenticated(user: _cachedUser!, accessToken: newAccessToken));
    }

    debugPrint('AuthService: access token refreshed');
  }

  @override
  Future<String?> getAccessToken() =>
      _storage.read(key: _StorageKeys.accessToken);

  @override
  Future<void> logout() async {
    // Best-effort server-side token revocation before clearing local state.
    try {
      final accessToken = await _storage.read(key: _StorageKeys.accessToken);
      final refreshToken = await _storage.read(key: _StorageKeys.refreshToken);
      final url = await _buildUrl('/api/auth/logout');

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      await _httpClient
          .post(
            url,
            headers: headers,
            body: jsonEncode({
              if (refreshToken != null && refreshToken.isNotEmpty)
                'refreshToken': refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Server revocation is best-effort — always clear local state.
      debugPrint('AuthService: server logout failed ($e), clearing locally');
    }

    await Future.wait([
      _storage.delete(key: _StorageKeys.accessToken),
      _storage.delete(key: _StorageKeys.refreshToken),
      _storage.delete(key: _StorageKeys.userId),
      _storage.delete(key: _StorageKeys.userEmail),
    ]);

    // Clear in-memory cache.
    _cachedUser = null;
    _isAuthenticated = false;
    _authStateController.add(const Unauthenticated());

    debugPrint('AuthService: logged out, tokens cleared');
  }

  @override
  Future<bool> isLoggedIn() async {
    final id = await _storage.read(key: _StorageKeys.userId);
    final email = await _storage.read(key: _StorageKeys.userEmail);
    final token = await _storage.read(key: _StorageKeys.accessToken);

    if (token != null && token.isNotEmpty &&
        id != null && id.isNotEmpty &&
        email != null && email.isNotEmpty) {
      // Populate in-memory cache.
      _cachedUser = AuthUser(id: id, email: email);
      _isAuthenticated = true;
      return true;
    }

    _cachedUser = null;
    _isAuthenticated = false;
    return false;
  }

  // ── Private helpers ────────────────────────────────────────────────────

  Uri _buildUrl(String path) => Uri.parse('$kBackendUrl$path');

  /// POST to [url] with [body] and return the decoded JSON map.
  ///
  /// Retries on transient errors (network, 5xx) with exponential backoff.
  /// Throws [AuthException] for 4xx responses or after exhausting retries.
  Future<Map<String, dynamic>> _post(
    Uri url,
    Map<String, dynamic> body,
  ) async {
    Exception? lastError;
    for (var attempt = 0; attempt < _kMaxRetries; attempt++) {
      try {
        final response = await _httpClient
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          // Successful response with no body (e.g. 204) — return empty map.
          return {};
        }

        // 4xx errors are not retried.
        if (response.statusCode < 500) {
          throw AuthException.fromResponse(
              response.statusCode, response.body);
        }

        // 5xx — retry.
        lastError = AuthException.fromResponse(
            response.statusCode, response.body);
        debugPrint(
            'AuthService: attempt ${attempt + 1} failed with ${response.statusCode}, retrying…');
      } catch (e) {
        if (e is AuthException) rethrow;
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint(
            'AuthService: attempt ${attempt + 1} failed ($e), retrying…');
      }

      if (attempt < _kMaxRetries - 1) {
        await Future<void>.delayed(_kRetryBase * (attempt + 1));
      }
    }
    throw lastError ??
        const AuthException(
            'Request failed after retries. Check your network connection.');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riverpod provider
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final settings = ref.watch(appSettingsProvider);
  return AuthServiceImpl(settings: settings);
}
