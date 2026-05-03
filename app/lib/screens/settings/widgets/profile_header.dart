// ProfileHeader — displays user identity at the top of the Profile / Settings screen.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';

import 'package:instructor/screens/settings/widgets/edit_profile_sheet.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    final textTheme = Theme.of(context).textTheme;

    final email = user?.email;
    final name = user?.name;
    final username = user?.username;
    final photoUrl = user?.photoUrl;

    final effectiveEmail = (email == null || email.isEmpty) ? null : email;
    final initial = name != null && name.isNotEmpty
        ? name[0].toUpperCase()
        : effectiveEmail != null
            ? effectiveEmail[0].toUpperCase()
            : '?';

    final displayName = name ?? username ?? effectiveEmail;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.45),
            colorScheme.surface.withValues(alpha: 0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Avatar with edit overlay ─────────────────────────────────────
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Semantics(
                label: 'Profile avatar',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.22),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SizedBox.fromSize(
                      size: const Size.fromRadius(52),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: colorScheme.primaryContainer,
                            child: Center(
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                          if (photoUrl != null && photoUrl.isNotEmpty)
                            Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                color: colorScheme.secondaryContainer,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => showEditProfileSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.edit_rounded,
                      size: 15,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Display name ─────────────────────────────────────────────────
          if (displayName != null && displayName != effectiveEmail)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                displayName,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // ── Email ────────────────────────────────────────────────────────
          Text(
            effectiveEmail ?? '—',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          // ── Username ─────────────────────────────────────────────────────
          if (username != null && username.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '@$username',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),

          // ── Plan badge + Upgrade button ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Free Plan',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => _showUpgradeSheet(context),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Upgrade'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context) {
    unawaited(
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
                    'Premium plans are coming soon — stay tuned!',
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
      ),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            colorScheme.surface.withValues(alpha: 0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Not signed in',
            child: CircleAvatar(
              radius: 52,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.person_off_rounded,
                size: 36,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            'Not signed in',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),

          const SizedBox(height: 6),

          Text(
            'Sign in to sync your plans and track progress',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          Semantics(
            button: true,
            label: 'Log in to your account',
            child: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.login),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }
}
