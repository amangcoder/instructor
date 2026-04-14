/// ProfileSidebar — EndDrawer with user identity, quick links, and account actions.
///
/// Slides in from the right when opened via `Scaffold.of(context).openEndDrawer()`.
///
/// - **Authenticated**: shows user initial avatar, email, Sign Out with confirmation.
/// - **Unauthenticated**: generic avatar, Login button.
/// - **Quick Links**: Cloud Sync (coming soon), Help & Feedback, Rate Instructor, Privacy Policy.
/// - **Footer**: app version via package_info_plus.
library profile_sidebar;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';

/// A sidebar drawer displaying user account info, quick links, and app version.
///
/// Intended for use as `endDrawer` on the Settings screen Scaffold.
class ProfileSidebar extends ConsumerStatefulWidget {
  const ProfileSidebar({super.key});

  @override
  ConsumerState<ProfileSidebar> createState() => _ProfileSidebarState();
}

class _ProfileSidebarState extends ConsumerState<ProfileSidebar> {
  // Cached so that provider rebuilds do not create a new Future and cause
  // FutureBuilder to flash back to ConnectionState.waiting on every rebuild.
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final currentUser = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Handle edge case: token exists but email is null/empty.
    final email = currentUser?.email;
    final hasValidEmail = email != null && email.isNotEmpty;
    final showAuthenticated = isAuthenticated && hasValidEmail;
    final name = currentUser?.name;
    final username = currentUser?.username;
    final photoUrl = currentUser?.photoUrl;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close sidebar',
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Account',
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (showAuthenticated)
                    _AuthenticatedHeader(
                      email: email!,
                      name: name,
                      username: username,
                      photoUrl: photoUrl,
                    )
                  else
                    const _UnauthenticatedHeader(),
                ],
              ),
            ),

            const Divider(),

            // ── Quick Links ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'QUICK LINKS',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  color: colorScheme.outline,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Cloud Sync'),
              trailing: Chip(
                label: Text(
                  'Soon',
                  style: textTheme.labelSmall,
                ),
                visualDensity: VisualDensity.compact,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming soon'),
                    duration: Duration(seconds: 4),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Feedback'),
              onTap: () => _launchUrlSafe(
                context,
                Uri.parse('mailto:support@thecuratedstillness.com'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Rate Instructor'),
              onTap: () => _launchUrlSafe(
                context,
                Uri.parse(
                  Platform.isIOS
                      ? 'https://apps.apple.com/app/instructor/id6744189217'
                      : 'https://play.google.com/store/apps/details?id=com.thecuratedstillness.instructor',
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () => _launchUrlSafe(
                context,
                Uri.parse('https://thecuratedstillness.com/privacy'),
              ),
            ),

            const Divider(),

            // ── Account ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'ACCOUNT',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  color: colorScheme.outline,
                ),
              ),
            ),
            if (isAuthenticated)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign Out'),
                onTap: () => _logout(context, ref),
              )
            else
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Log In'),
                onTap: () {
                  Navigator.pop(context); // close drawer first
                  context.push(AppRoutes.login);
                },
              ),

            const Spacer(),

            // ── Footer ───────────────────────────────────────────────────
            FutureBuilder<PackageInfo>(
              future: _packageInfoFuture,
              builder: (context, snapshot) {
                final version = snapshot.data?.version ?? '…';
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'v$version · Instructor',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Launches [url] via url_launcher, catching errors and showing a SnackBar
  /// fallback on failure.
  Future<void> _launchUrlSafe(BuildContext context, Uri url) async {
    try {
      final launched = await launchUrl(url);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open link. Please try again.'),
          ),
        );
      }
    }
  }

  /// Shows a confirmation dialog, then logs out and navigates to login.
  ///
  /// Mirrors the logout flow from [AuthSection._logout].
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

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AuthenticatedHeader extends StatelessWidget {
  const _AuthenticatedHeader({required this.email, this.name, this.username, this.photoUrl});

  final String email;
  final String? name;
  final String? username;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final initial = name != null && name!.isNotEmpty
        ? name![0].toUpperCase()
        : email[0].toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primaryContainer,
          backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
              ? NetworkImage(photoUrl!)
              : null,
          child: photoUrl == null || photoUrl!.isEmpty
              ? Text(
                  initial,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name != null && name!.isNotEmpty)
                Text(
                  name!,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                email,
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (username != null && username!.isNotEmpty)
                Text(
                  '@$username',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  '● Free Plan',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnauthenticatedHeader extends StatelessWidget {
  const _UnauthenticatedHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person_off,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Not signed in',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
