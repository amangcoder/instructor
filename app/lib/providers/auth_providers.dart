/// Riverpod providers for authentication state.
///
/// [authStateNotifierProvider] — the main auth state (loading → authenticated
/// or unauthenticated). Watched by the router redirect guard and any widget
/// that needs to conditionally show auth-gated UI.
///
/// [isAuthenticatedProvider] — convenience bool derived from [authStateNotifierProvider].
///
/// [currentUserProvider] — the currently logged-in [AuthUser] or null.
library auth_providers;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/services/provider_catalog_manager.dart';

part 'auth_providers.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Auth state notifier
// ─────────────────────────────────────────────────────────────────────────────

/// Async notifier that manages the global [AuthState].
///
/// Initialises by reading tokens from secure storage via [AuthService.isLoggedIn],
/// which also populates the in-memory cache so subsequent sync reads work.
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Future<AuthState> build() async {
    final service = ref.watch(authServiceProvider);

    // Subscribe to auth state changes broadcast by AuthService (e.g.
    // auto-logout triggered by ApiClient when token refresh fails on 401).
    // Without this, the notifier stays Authenticated after an auto-logout
    // and the UI keeps making failed API calls.
    final sub = service.authStateStream.listen((authState) {
      state = AsyncData(authState);
    });
    ref.onDispose(sub.cancel);

    // isLoggedIn() populates the in-memory cache (getUser / isAuthenticated).
    final loggedIn = await service.isLoggedIn();
    if (loggedIn) {
      final user = service.getUser(); // sync after isLoggedIn() call
      final token = await service.getAccessToken();
      if (user != null && token != null && token.isNotEmpty) {
        // Non-blocking: warm up the provider catalog in the background so
        // voice pickers have fresh data without delaying the auth redirect.
        _scheduleCatalogFetch();
        return Authenticated(user: user, accessToken: token);
      }
    }
    return const Unauthenticated();
  }

  /// Triggers a non-blocking TTS provider catalog warm-up.
  ///
  /// Called after auth completes (on launch and after OTP login). Uses
  /// [ProviderCatalogManager.getCachedCatalog] so that a network request is
  /// only made when the SQLite cache is absent or older than 24 hours
  /// (REQ-010 AC: no network call on launch when cache is fresh).
  void _scheduleCatalogFetch() {
    Future.microtask(() async {
      try {
        await ref
            .read(providerCatalogManagerProvider)
            .getCachedCatalog();
      } catch (e) {
        // Errors are already handled inside getCachedCatalog; this guard
        // is an extra safety net so the notifier never throws from initState.
        debugPrint('AuthStateNotifier: catalog warm-up failed — $e');
      }
    });
  }

  /// Called after a successful OTP verification.
  Future<void> onLoginSuccess(AuthResult result) async {
    state = AsyncData(
      Authenticated(
        user: result.user,
        accessToken: result.accessToken,
      ),
    );
    // Also kick off a catalog refresh after fresh login so voice pickers have
    // up-to-date data without the user needing to navigate away and back.
    _scheduleCatalogFetch();
  }

  /// Called on explicit logout or when token refresh fails.
  Future<void> logout() async {
    final service = ref.read(authServiceProvider);
    await service.logout();
    state = const AsyncData(Unauthenticated());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Derived providers
// ─────────────────────────────────────────────────────────────────────────────

/// `true` when [authStateNotifierProvider] is in the [Authenticated] state.
@riverpod
bool isAuthenticated(Ref ref) {
  final stateAsync = ref.watch(authStateNotifierProvider);
  return stateAsync.maybeWhen(
    data: (state) => state is Authenticated,
    orElse: () => false,
  );
}

/// The currently logged-in [AuthUser], or `null` if unauthenticated.
@riverpod
AuthUser? currentUser(Ref ref) {
  final stateAsync = ref.watch(authStateNotifierProvider);
  return stateAsync.maybeWhen(
    data: (state) => state is Authenticated ? state.user : null,
    orElse: () => null,
  );
}
