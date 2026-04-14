import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/widgets/offline_banner.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a minimal app tree with the [OfflineBanner] and a provider override
/// that lets tests push arbitrary connectivity states via [controller].
Widget _buildApp({
  required LibraryTab tab,
  required StreamController<bool> controller,
}) {
  return ProviderScope(
    overrides: [
      isOnlineProvider.overrideWith(
        (ref) => controller.stream,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            OfflineBanner(tab: tab),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Loading / online state ─────────────────────────────────────────────────
  group('when connectivity state is loading (no data yet)', () {
    testWidgets('does not show the banner (treats loading as online)',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );
      await tester.pump(); // process initial build

      // Stream has emitted nothing yet → banner must be hidden.
      expect(find.text('Showing cached plans'), findsNothing);
      expect(find.text('Discover requires internet'), findsNothing);
    });
  });

  group('when device is online', () {
    testWidgets('does not show the banner', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(true);
      await tester.pump();

      expect(find.text('Showing cached plans'), findsNothing);
    });
  });

  // ── My Plans tab ──────────────────────────────────────────────────────────
  group('LibraryTab.myPlans', () {
    testWidgets('shows "Showing cached plans" when offline', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // animation

      expect(find.text('Showing cached plans'), findsOneWidget);
    });

    testWidgets('does NOT show Discover message for My Plans tab',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Discover requires internet'), findsNothing);
    });

    testWidgets('shows cloud_off icon when offline', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  // ── Discover tab ──────────────────────────────────────────────────────────
  group('LibraryTab.discover', () {
    testWidgets('shows "Discover requires internet" when offline',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.discover, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // animation

      expect(find.text('Discover requires internet'), findsOneWidget);
    });

    testWidgets('does NOT show My Plans message for Discover tab',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.discover, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Showing cached plans'), findsNothing);
    });

    testWidgets('shows wifi_off icon when offline', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.discover, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });
  });

  // ── Auto-dismiss on restore ────────────────────────────────────────────────
  group('auto-dismiss when connectivity restored', () {
    testWidgets('banner disappears when online after being offline',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      // Go offline — banner should appear.
      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Showing cached plans'), findsOneWidget);

      // Restore connectivity — banner should disappear.
      controller.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // animation out

      expect(find.text('Showing cached plans'), findsNothing);
    });

    testWidgets(
        'banner can re-appear when connectivity is lost again after restore',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.discover, controller: controller),
      );

      // Offline → banner visible.
      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Discover requires internet'), findsOneWidget);

      // Online → banner gone.
      controller.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Discover requires internet'), findsNothing);

      // Offline again → banner re-appears.
      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Discover requires internet'), findsOneWidget);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────
  group('accessibility', () {
    testWidgets('banner has a Semantics node with the offline message as label',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(
        find.bySemanticsLabel('Showing cached plans'),
        findsOneWidget,
      );
    });

    testWidgets(
        'banner Semantics node has liveRegion=true for screen reader announcements',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(tab: LibraryTab.myPlans, controller: controller),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final semanticsNode = tester.getSemantics(
        find.bySemanticsLabel('Showing cached plans'),
      );
      expect(semanticsNode.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    });
  });
}
