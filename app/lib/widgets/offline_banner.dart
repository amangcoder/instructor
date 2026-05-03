import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks internet connectivity by attempting a socket connection
/// to Google DNS (8.8.8.8:53).
///
/// Emits `true` when the device can reach the internet, `false` otherwise.
/// Checks every 5 seconds so the [OfflineBanner] auto-dismisses promptly when
/// connectivity is restored.
final isOnlineProvider = StreamProvider<bool>((ref) => _connectivityStream());

Future<bool> _checkConnectivity() async {
  try {
    final socket = await Socket.connect(
      '8.8.8.8',
      53,
      timeout: const Duration(seconds: 3),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Stream<bool> _connectivityStream() async* {
  yield await _checkConnectivity();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await _checkConnectivity();
  }
}

/// A connectivity-aware informational banner that slides in at the top of a
/// screen when the device is offline.
///
/// Pass an optional [message] to customise the body — defaults to a generic
/// "showing cached content" copy suitable for the Home feed.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({
    super.key,
    this.message,
    this.icon = Icons.cloud_off_outlined,
  });

  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);

    final isOffline = isOnlineAsync.maybeWhen(
      data: (online) => !online,
      orElse: () => false,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: isOffline
          ? _BannerContent(
              key: const ValueKey('offline'),
              message: message ?? 'You are offline — showing cached content',
              icon: icon,
            )
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.message,
    required this.icon,
    super.key,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.error.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
