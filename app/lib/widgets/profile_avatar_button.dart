import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/providers/auth_providers.dart';

/// Circular avatar button shown in AppBars.
///
/// - Authenticated with photo → network image
/// - Authenticated without photo → email/name initial on primaryContainer
/// - Unauthenticated → person icon on surfaceContainer
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({
    required this.onTap,
    super.key,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final Widget avatar;

    if (user != null) {
      final photoUrl = user.photoUrl;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        avatar = CircleAvatar(
          radius: 16,
          backgroundImage: NetworkImage(photoUrl),
          backgroundColor: colorScheme.primaryContainer,
        );
      } else {
        final initial = (user.name?.isNotEmpty ?? false)
            ? user.name![0].toUpperCase()
            : user.email.isNotEmpty
                ? user.email[0].toUpperCase()
                : '?';
        avatar = CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        );
      }
    } else {
      avatar = CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.surfaceContainer,
        child: Icon(
          Icons.person,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}
