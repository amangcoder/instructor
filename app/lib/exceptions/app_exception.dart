/// Sealed base exception for all application-level errors.
///
/// This unified exception hierarchy allows UI error handlers to branch on a
/// single type (using exhaustive pattern matching on sealed subclasses) rather
/// than catching multiple disjoint exception classes.
///
/// Each domain (auth, plans, TTS, sync, audio) has a corresponding final
/// subclass that can be thrown by services in that domain.
///
/// Example:
/// ```dart
/// try {
///   await authService.requestOtp(email);
/// } on AppException catch (e) {
///   switch (e) {
///     case AuthAppException(:final message) =>
///       _showError('Auth failed: $message'),
///     case PlanAppException(:final message) =>
///       _showError('Plan error: $message'),
///     case TtsAppException(:final message) =>
///       _showError('TTS error: $message'),
///     case SyncAppException(:final message) =>
///       _showError('Sync error: $message'),
///     case AudioAppException(:final message) =>
///       _showError('Audio error: $message'),
///   }
/// }
/// ```
sealed class AppException implements Exception {
  /// Creates an [AppException] with a message and optional cause.
  ///
  /// [message] is the human-readable error description.
  /// [cause] is the underlying exception that triggered this error (e.g., a
  /// SocketException from a failed HTTP request), useful for debugging.
  const AppException(
    this.message, {
    this.cause,
  });

  /// Human-readable error message describing what went wrong.
  final String message;

  /// The underlying exception that caused this error, if any.
  ///
  /// For example, a [SocketException] for network errors or a [FormatException]
  /// for JSON parsing failures.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Exception thrown by auth service operations (OTP request, token refresh, etc).
final class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.cause});
}

/// Exception thrown by plan API/local operations (create, update, delete, fetch).
///
/// Not declared `final` so that service-layer exceptions (e.g.
/// [PlanApiException]) can extend it and add domain-specific fields (such as a
/// user-friendly message) while still being catchable as [AppException].
class PlanAppException extends AppException {
  const PlanAppException(super.message, {super.cause});
}

/// Exception thrown by TTS service operations (synthesis, voice fetch, etc).
///
/// Not declared `final` so that service-layer exceptions (e.g.
/// [TtsApiException]) can extend it and add domain-specific fields (such as
/// the HTTP status code) while still being catchable as [AppException].
class TtsAppException extends AppException {
  const TtsAppException(super.message, {super.cause});
}

/// Exception thrown by sync service operations (cloud sync, restore, etc).
final class SyncAppException extends AppException {
  const SyncAppException(super.message, {super.cause});
}

/// Exception thrown by audio download/caching operations.
///
/// Not declared `final` so that service-layer exceptions can extend it
/// while still being catchable as [AppException].
class AudioAppException extends AppException {
  const AudioAppException(super.message, {super.cause});
}
