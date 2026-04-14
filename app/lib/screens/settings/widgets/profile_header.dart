/// ProfileHeader — displays user identity at the top of the Profile / Settings screen.
library profile_header;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';

import 'edit_profile_sheet.dart';

/// Displays user identity at the top of the Settings / Profile screen.
///
/// - **Authenticated**: circular avatar (network photo or email initial), display
///   name, email, a '● Free' plan chip, an Upgrade button, and an edit-profile
///   icon that opens [showEditProfileSheet].
/// - **Unauthenticated**: person_off icon, 'Not signed in' label, and a Log In button.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: isAuthenticated
          ? _AuthenticatedHeader(user: currentUser)
          : const _UnauthenticatedHeader(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Authenticated
// ─────────────────────────────────────────────────────────────────────────────

class _AuthenticatedHeader extends StatelessWidget {
  const _AuthenticatedHeader({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final email = user?.email;
    final name = user?.name;
    final username = user?.username;
    final photoUrl = user?.photoUrl;

    // Derive avatar initial — fall back to '?' when email is null or empty.
    final effectiveEmail = (email == null || email.isEmpty) ? null : email;
    final initial = name != null && name.isNotEmpty
        ? name[0].toUpperCase()
        : effectiveEmail != null
            ? effectiveEmail[0].toUpperCase()
            : '?';

    // Display name: name > username > email.
    final displayName = name ?? username ?? effectiveEmail;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Avatar with edit overlay ─────────────────────────────────────
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Semantics(
              label: 'Profile avatar',
              child: ClipOval(
                child: SizedBox.fromSize(
                  size: const Size.fromRadius(72),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fallback — always visible; hidden by image once loaded.
                      ColoredBox(
                        color: colorScheme.primaryContainer,
                        child: Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 48,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      // Network image — covers fallback on success, disappears on error.
                      if (photoUrl != null && photoUrl.isNotEmpty)
                        Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Edit icon badge
            Material(
              color: colorScheme.secondaryContainer,
              shape: const CircleBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => showEditProfileSheet(context),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── Display name (if set) ────────────────────────────────────────
        if (displayName != null && displayName != effectiveEmail)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              displayName,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),

        // ── Email ────────────────────────────────────────────────────────
        Text(
          effectiveEmail ?? '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),

        // ── Username ─────────────────────────────────────────────────────
        if (username != null && username.isNotEmpty)
          Text(
            '@$username',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),

        const SizedBox(height: 8),

        // ── Plan badge + Upgrade button ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Chip(
              label: const Text('\u25cf Free'),
              labelStyle: TextStyle(color: colorScheme.outline),
            ),
            TextButton(
              onPressed: () => _showUpgradeSheet(context),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ],
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Premium plans are coming soon \u2014 stay tuned!',
                  style: Theme.of(sheetContext).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Unauthenticated
// ─────────────────────────────────────────────────────────────────────────────

class _UnauthenticatedHeader extends StatelessWidget {
  const _UnauthenticatedHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Avatar placeholder ───────────────────────────────────────────
        Semantics(
          label: 'Not signed in',
          child: CircleAvatar(
            radius: 72,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.person_off,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Label ────────────────────────────────────────────────────────
        Text(
          'Not signed in',
          style: Theme.of(context).textTheme.bodyLarge,
        ),

        const SizedBox(height: 8),

        // ── Log In button ────────────────────────────────────────────────
        Semantics(
          button: true,
          label: 'Log in to your account',
          child: FilledButton(
            onPressed: () => context.push(AppRoutes.login),
            child: const Text('Log In'),
          ),
        ),
      ],
    );
  }
}
