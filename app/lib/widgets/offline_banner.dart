import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────────────────────────────────────────────────────
// Tab enum
// ────────────────────────────────────────────────────────────────────────────

/// Identifies which tab in the Plan Library the [OfflineBanner] is embedded in,
/// so that tab-specific offline messages can be shown.
enum LibraryTab {
  /// The "My Plans" tab — shows the user's own plans served from the local
  /// SQLite cache when offline.
  myPlans,

  /// The "Discover" tab — requires a live internet connection to load the
  /// server-side plan library.
  discover,
}

// ────────────────────────────────────────────────────────────────────────────
// Connectivity provider
// ────────────────────────────────────────────────────────────────────────────

/// Periodically checks internet connectivity by attempting a socket connection
/// to Google DNS (8.8.8.8:53).
///
/// Emits `true` when the device can reach the internet, `false` otherwise.
/// Checks every 5 seconds so the [OfflineBanner] auto-dismisses promptly when
/// connectivity is restored.
///
/// Kept alive so all screens share a single polling loop.
final isOnlineProvider = StreamProvider<bool>((ref) => _connectivityStream());

/// Attempts a TCP connection to Google DNS to determine internet reachability.
///
/// Returns `true` on success, `false` on any error (no network, timeout, etc.).
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
  // Emit immediately so the UI does not wait for the first poll cycle.
  yield await _checkConnectivity();

  // Then poll every 5 seconds so auto-dismiss is responsive.
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    yield await _checkConnectivity();
  }
}

// ────────────────────────────────────────────────────────────────────────────
// OfflineBanner widget
// ────────────────────────────────────────────────────────────────────────────

/// A connectivity-aware informational banner that slides in at the top of a
/// screen when the device is offline.
///
/// Shows a [tab]-specific message:
/// - [LibraryTab.myPlans]  → **"Showing cached plans"**
/// - [LibraryTab.discover] → **"Discover requires internet"**
///
/// Automatically dismisses (animates away) as soon as connectivity is restored.
/// The banner is zero-height when the device is online, so it has no visual
/// footprint in the normal (connected) state.
///
/// ## Usage
///
/// Place it at the top of your screen's body `Column`:
///
/// ```dart
/// Column(
///   children: [
///     OfflineBanner(tab: LibraryTab.myPlans),
///     Expanded(child: _PlanList()),
///   ],
/// )
/// ```
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.tab});

  /// Which library tab this banner belongs to, determining the message shown.
  final LibraryTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(isOnlineProvider);

    // Treat the loading state as "online" to avoid a banner flash on startup
    // before the first connectivity check completes.
    final isOffline = isOnlineAsync.maybeWhen(
      data: (online) => !online,
      orElse: () => false,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        // Slide in from top while also fading in.
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: isOffline
          ? _BannerContent(tab: tab, key: const ValueKey('offline'))
          : const SizedBox.shrink(key: ValueKey('online')),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Internal banner content
// ────────────────────────────────────────────────────────────────────────────

class _BannerContent extends StatelessWidget {
  const _BannerContent({super.key, required this.tab});

  final LibraryTab tab;

  String get _message {
    return switch (tab) {
      LibraryTab.myPlans => 'You are offline — showing cached plans',
      LibraryTab.discover => 'You are offline — Discover requires internet',
    };
  }

  IconData get _icon {
    return switch (tab) {
      LibraryTab.myPlans => Icons.cloud_off_outlined,
      LibraryTab.discover => Icons.wifi_off_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      // Announce the message to screen readers as a live region so it is read
      // aloud automatically when connectivity changes.
      liveRegion: true,
      label: _message,
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
              _icon,
              size: 16,
              color: colorScheme.onErrorContainer,
              semanticLabel: null, // parent Semantics node handles the label
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _message,
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
