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

import 'dart:async' show Completer, StreamController, unawaited;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart' show NetworkImage, PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/exceptions/app_exception.dart';
import 'package:instructor/models/auth_models.dart';
import 'package:instructor/services/app_settings.dart';

part 'auth_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthException — backward-compatible alias for AuthAppException
// ─────────────────────────────────────────────────────────────────────────────

/// Backward-compatible alias kept so existing catch clauses continue to work.
///
/// New code should throw and catch [AuthAppException] directly.
typedef AuthException = AuthAppException;

// ─────────────────────────────────────────────────────────────────────────────
// Storage keys
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _StorageKeys {
  static const String accessToken = 'auth_access_token';
  static const String refreshToken = 'auth_refresh_token';
  static const String userId = 'auth_user_id';
  static const String userEmail = 'auth_user_email';
  static const String userName = 'auth_user_name';
  static const String userUsername = 'auth_user_username';
  static const String userPhotoUrl = 'auth_user_photo_url';
}

// ─────────────────────────────────────────────────────────────────────────────
// Exceptions
// ─────────────────────────────────────────────────────────────────────────────

/// Helper to convert HTTP responses to user-friendly error messages.
abstract final class _AuthErrorMessages {
  static String humanize(String raw) {
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

  static String httpFallback(int code) {
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
// Helper — parse an HTTP response into an AuthAppException
// ─────────────────────────────────────────────────────────────────────────────

/// Converts an HTTP [statusCode] + raw response [body] into a user-friendly
/// [AuthAppException].
///
/// Attempts to extract a `message` or `error` string from a JSON body and
/// runs it through [_AuthErrorMessages.humanize]. Falls back to
/// [_AuthErrorMessages.httpFallback] when the body is not parseable.
///
/// Replaces the former `AuthException.fromResponse` factory.
AuthAppException _authExceptionFromResponse(int statusCode, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          '';
      if (raw.isNotEmpty) {
        return AuthAppException(_AuthErrorMessages.humanize(raw));
      }
    }
  } catch (_) {
    // Body is not JSON — fall through to status-code-based message.
  }
  return AuthAppException(_AuthErrorMessages.httpFallback(statusCode));
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

  /// Fetches the latest profile from the server and updates the cache.
  ///
  /// Returns the updated [AuthUser] or null on failure.
  Future<AuthUser?> fetchProfile() async => null;

  /// Updates the user's profile (name, username) on the server and cache.
  /// All parameters are optional.
  ///
  /// Throws [AuthException] on API error (e.g. 409 username taken).
  Future<AuthUser> updateProfile({
    String? name,
    String? username,
  }) async {
    throw const AuthException('Not implemented');
  }

  /// Uploads a profile photo to the server and updates the cached [photoUrl].
  ///
  /// [bytes] is the raw image data; [mimeType] should be 'image/jpeg', etc.
  /// Throws [AuthException] on failure.
  Future<void> uploadProfilePhoto({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    throw const AuthException('Not implemented');
  }
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

    // Store tokens and profile securely.
    await Future.wait([
      _storage.write(key: _StorageKeys.accessToken, value: result.accessToken),
      _storage.write(
          key: _StorageKeys.refreshToken, value: result.refreshToken),
      _storage.write(key: _StorageKeys.userId, value: result.user.id),
      _storage.write(key: _StorageKeys.userEmail, value: result.user.email),
      if (result.user.name != null)
        _storage.write(key: _StorageKeys.userName, value: result.user.name),
      if (result.user.username != null)
        _storage.write(key: _StorageKeys.userUsername, value: result.user.username),
      if (result.user.photoUrl != null)
        _storage.write(key: _StorageKeys.userPhotoUrl, value: result.user.photoUrl),
    ]);

    // Update in-memory cache.
    _cachedUser = result.user;
    _isAuthenticated = true;
    _authStateController.add(
        Authenticated(user: result.user, accessToken: result.accessToken));

    debugPrint('AuthService: OTP verified, tokens stored for ${result.user.email}');

    // The verify-otp endpoint returns basic user fields but does not generate
    // a signed photo URL from S3. Kick off a background profile fetch so the
    // photo (and any other enriched fields) appear immediately after login
    // without blocking the OTP response. fetchProfile() will emit an updated
    // Authenticated event to the stream on completion.
    unawaited(fetchProfile());

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
      _storage.delete(key: _StorageKeys.userName),
      _storage.delete(key: _StorageKeys.userUsername),
      _storage.delete(key: _StorageKeys.userPhotoUrl),
    ]);

    // Clear in-memory cache.
    _cachedUser = null;
    _isAuthenticated = false;
    _authStateController.add(const Unauthenticated());

    debugPrint('AuthService: logged out, tokens cleared');
  }

  @override
  Future<bool> isLoggedIn() async {
    final String? id;
    final String? email;
    final String? token;
    try {
      id = await _storage.read(key: _StorageKeys.userId);
      email = await _storage.read(key: _StorageKeys.userEmail);
      token = await _storage.read(key: _StorageKeys.accessToken);
    } catch (e) {
      // Secure storage cipher mismatch (BadPaddingException) — typically caused
      // by Keystore key loss after app reinstall or device backup restore.
      // Wipe the corrupted blob so subsequent launches don't repeatedly throw.
      debugPrint('AuthService.isLoggedIn: secure storage read failed ($e); wiping');
      try {
        await _storage.deleteAll();
      } catch (_) {}
      _cachedUser = null;
      _isAuthenticated = false;
      return false;
    }

    if (token == null || token.isEmpty ||
        id == null || id.isEmpty ||
        email == null || email.isEmpty) {
      _cachedUser = null;
      _isAuthenticated = false;
      return false;
    }

    // Check whether the stored access token is already expired.
    // If it is, attempt a silent refresh before deciding the auth state.
    // This ensures that the in-memory cache is initialised with a valid token
    // on every app launch, not just after the first API call returns 401.
    if (_isTokenExpired(token)) {
      debugPrint('AuthService.isLoggedIn: access token expired, attempting silent refresh…');
      try {
        await refreshToken().timeout(const Duration(seconds: 5));
        // Ensure in-memory cache is populated — refreshToken() only updates
        // the stream if _cachedUser is already non-null, so set it explicitly.
        final name = await _storage.read(key: _StorageKeys.userName);
        final username = await _storage.read(key: _StorageKeys.userUsername);
        final photoUrl = await _storage.read(key: _StorageKeys.userPhotoUrl);
        _cachedUser = AuthUser(
          id: id,
          email: email,
          name: name,
          username: username,
          photoUrl: photoUrl,
        );
        _isAuthenticated = true;
        return true;
      } catch (e) {
        debugPrint('AuthService.isLoggedIn: silent refresh failed ($e), clearing state');
        _cachedUser = null;
        _isAuthenticated = false;
        return false;
      }
    }

    // Token is present and not yet expired — populate in-memory cache.
    final name = await _storage.read(key: _StorageKeys.userName);
    final username = await _storage.read(key: _StorageKeys.userUsername);
    final photoUrl = await _storage.read(key: _StorageKeys.userPhotoUrl);
    _cachedUser = AuthUser(
      id: id,
      email: email,
      name: name,
      username: username,
      photoUrl: photoUrl,
    );
    _isAuthenticated = true;
    return true;
  }

  /// Returns `true` when the JWT [token]'s `exp` claim is in the past.
  ///
  /// Returns `false` (i.e. "not expired") when the token cannot be decoded,
  /// to avoid accidentally locking out users with unusual JWT formats — the
  /// first API call will return a 401 and trigger the normal refresh path.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // JWT payload is base64url-encoded — pad to a multiple of 4 chars.
      final payload = parts[1];
      final padded = payload.padRight(
        (payload.length + 3) ~/ 4 * 4,
        '=',
      );
      final decoded = utf8.decode(base64Url.decode(padded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = json['exp'];
      if (exp == null) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (e) {
      debugPrint('AuthService._isTokenExpired: could not decode token ($e)');
      return false;
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────

  @override
  Future<AuthUser?> fetchProfile() async {
    final accessToken = await _storage.read(key: _StorageKeys.accessToken);
    if (accessToken == null || accessToken.isEmpty) return null;

    try {
      final url = _buildUrl('/api/auth/me');
      final response = await _httpClient
          .get(url, headers: {
            'Authorization': 'Bearer $accessToken',
          })
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final user = AuthUser.fromJson(json);
        final newPhoto = user.photoUrl;
        if (newPhoto != null && newPhoto.isNotEmpty) {
          PaintingBinding.instance.imageCache.evict(NetworkImage(newPhoto));
        }
        await _persistProfileFields(user);
        _cachedUser = user;
        // Broadcast the refreshed profile so any listener (e.g.
        // AuthStateNotifier) updates UI with the latest data, including
        // the freshly signed photo URL from /api/auth/me.
        if (_isAuthenticated) {
          _authStateController.add(
              Authenticated(user: user, accessToken: accessToken));
        }
        return user;
      }
    } catch (e) {
      debugPrint('AuthService.fetchProfile: failed ($e)');
    }
    return null;
  }

  @override
  Future<AuthUser> updateProfile({
    String? name,
    String? username,
  }) async {
    final accessToken = await _storage.read(key: _StorageKeys.accessToken);
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Not authenticated');
    }

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (username != null) body['username'] = username;

    final url = _buildUrl('/api/auth/profile');
    final response = await _httpClient
        .patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _authExceptionFromResponse(response.statusCode, response.body);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final serverUser = AuthUser.fromJson(json);

    // Prefer the presigned URL already cached locally over any new one the server
    // generates.  Updating name/username doesn't change the photo, but the server
    // calls getProfile() which re-signs the S3 URL with a new signature — giving
    // Flutter a cache-miss on an image it already had loaded.  If the server fails
    // to resolve the photo URL (returns null), we also keep the local copy.
    final resolvedPhotoUrl = _cachedUser?.photoUrl ?? serverUser.photoUrl;
    final updatedUser = resolvedPhotoUrl != serverUser.photoUrl
        ? serverUser.copyWith(photoUrl: resolvedPhotoUrl)
        : serverUser;

    await _persistProfileFields(updatedUser);
    _cachedUser = updatedUser;
    if (updatedUser.id.isNotEmpty) {
      final token = await _storage.read(key: _StorageKeys.accessToken) ?? '';
      _authStateController.add(Authenticated(user: updatedUser, accessToken: token));
    }
    return updatedUser;
  }

  @override
  Future<void> uploadProfilePhoto({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final accessToken = await _storage.read(key: _StorageKeys.accessToken);
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('Not authenticated');
    }

    final uri = _buildUrl('/api/auth/profile/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: 'photo.${mimeType.split('/').last}',
        contentType: MediaType.parse(mimeType),
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _authExceptionFromResponse(response.statusCode, response.body);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final photoUrl = json['photoUrl']?.toString();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      // The S3 URL is stable per user, so Flutter's ImageCache may still hold a
      // failed load from an earlier upload attempt. Evict both the plain URL and
      // any prior cached entry before broadcasting the new photo.
      PaintingBinding.instance.imageCache.evict(NetworkImage(photoUrl));
      final previous = _cachedUser?.photoUrl;
      if (previous != null && previous.isNotEmpty && previous != photoUrl) {
        PaintingBinding.instance.imageCache.evict(NetworkImage(previous));
      }
      await _storage.write(key: _StorageKeys.userPhotoUrl, value: photoUrl);
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(photoUrl: photoUrl);
        final token = await _storage.read(key: _StorageKeys.accessToken) ?? '';
        _authStateController.add(Authenticated(user: _cachedUser!, accessToken: token));
      }
    }
  }

  Future<void> _persistProfileFields(AuthUser user) async {
    await Future.wait([
      if (user.name != null)
        _storage.write(key: _StorageKeys.userName, value: user.name)
      else
        _storage.delete(key: _StorageKeys.userName),
      if (user.username != null)
        _storage.write(key: _StorageKeys.userUsername, value: user.username)
      else
        _storage.delete(key: _StorageKeys.userUsername),
      if (user.photoUrl != null)
        _storage.write(key: _StorageKeys.userPhotoUrl, value: user.photoUrl)
      else
        _storage.delete(key: _StorageKeys.userPhotoUrl),
    ]);
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
          throw _authExceptionFromResponse(
              response.statusCode, response.body);
        }

        // 5xx — retry.
        lastError = _authExceptionFromResponse(
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
