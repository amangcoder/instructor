/// Authentication domain models.
///
/// These are plain Dart classes (no freezed — to keep the dependency
/// surface minimal and avoid running build_runner for trivial models).
library auth_models;

/// Represents a successfully authenticated user.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

/// Result of a successful OTP verification.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Possible auth states for the app.
sealed class AuthState {
  const AuthState();
}

/// User is not authenticated (no valid tokens).
final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// User is authenticated with a valid JWT.
final class Authenticated extends AuthState {
  const Authenticated({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;
}

/// Auth state is being determined (app startup, token validation).
final class AuthLoading extends AuthState {
  const AuthLoading();
}

// ─────────────────────────────────────────────────────────────────────────────
// Type aliases for test compatibility
// ─────────────────────────────────────────────────────────────────────────────

/// Alias for [Authenticated] — used in test fakes.
typedef AuthenticatedState = Authenticated;

/// Alias for [Unauthenticated] — used in test fakes.
typedef UnauthenticatedState = Unauthenticated;
