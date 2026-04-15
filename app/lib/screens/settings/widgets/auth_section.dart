/// AuthSection — auth status display and logout control for the Settings screen.
library auth_section;

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
            'Are you sure you want to log out? Your local data will be preserved.'),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outlined,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Signed in as', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Log out',
            child: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Log Out'),
            ),
          ),
        ],
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
