// AuthSection — auth status display and logout control for the Settings screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';

/// Displays the current auth status at the top of the Settings screen.
///
/// - Authenticated: shows logged-in email and a Logout button.
/// - Unauthenticated: shows a Login button.
class AuthSection extends ConsumerWidget {
  const AuthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (isAuthenticated && currentUser != null) {
      return _AuthenticatedTile(
        email: currentUser.email,
        onLogout: () => _logout(context, ref),
      );
    }

    return _UnauthenticatedTile(
      onLogin: () => context.push(AppRoutes.login),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog.adaptive(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to log out? Your local data will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(authStateNotifierProvider.notifier).logout();

    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }
}

class _AuthenticatedTile extends StatelessWidget {
  const _AuthenticatedTile({
    required this.email,
    required this.onLogout,
  });

  final String email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      label: 'Sign out of $email',
      button: true,
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                size: 20,
                color: colorScheme.error,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign Out',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnauthenticatedTile extends StatelessWidget {
  const _UnauthenticatedTile({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.person_off_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      title: const Text('Not signed in'),
      subtitle: const Text('Sign in to enable cloud sync and AI features'),
      trailing: Semantics(
        label: 'Log in',
        child: FilledButton(
          onPressed: onLogin,
          child: const Text('Log In'),
        ),
      ),
    );
  }
}
