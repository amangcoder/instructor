import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/widgets/offline_banner.dart';

const _defaultMessage = 'You are offline — showing cached content';
const _customMessage = 'You are offline — Discover requires internet';

Widget _buildApp({
  required StreamController<bool> controller,
  String? message,
  IconData? icon,
}) {
  return ProviderScope(
    overrides: [
      isOnlineProvider.overrideWith((ref) => controller.stream),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            OfflineBanner(
              message: message,
              icon: icon ?? Icons.cloud_off_outlined,
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('when connectivity state is loading (no data yet)', () {
    testWidgets('does not show the banner (treats loading as online)',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(_buildApp(controller: controller));
      await tester.pump();

      expect(find.text(_defaultMessage), findsNothing);
    });
  });

  group('when device is online', () {
    testWidgets('does not show the banner', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(_buildApp(controller: controller));

      controller.add(true);
      await tester.pump();

      expect(find.text(_defaultMessage), findsNothing);
    });
  });

  group('when device is offline (default copy)', () {
    testWidgets('shows the default offline message', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(_buildApp(controller: controller));

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(_defaultMessage), findsOneWidget);
    });

    testWidgets('shows the cloud_off icon by default', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(_buildApp(controller: controller));

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });
  });

  group('with a custom message + icon (Discover variant)', () {
    testWidgets('shows the custom message when offline', (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _buildApp(
          controller: controller,
          message: _customMessage,
          icon: Icons.wifi_off_outlined,
        ),
      );

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text(_customMessage), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });
  });

  group('auto-dismiss when connectivity restored', () {
    testWidgets('banner disappears when online after being offline',
        (tester) async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);

      await tester.pumpWidget(_buildApp(controller: controller));

      controller.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(_defaultMessage), findsOneWidget);

      controller.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(_defaultMessage), findsNothing);
    });

    testWidgets(
      'banner can re-appear when connectivity is lost again after restore',
      (tester) async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        await tester.pumpWidget(_buildApp(controller: controller));

        controller.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text(_defaultMessage), findsOneWidget);

        controller.add(true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text(_defaultMessage), findsNothing);

        controller.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text(_defaultMessage), findsOneWidget);
      },
    );
  });

  group('accessibility', () {
    testWidgets(
      'banner has a Semantics node with the offline message as label',
      (tester) async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        await tester.pumpWidget(_buildApp(controller: controller));

        controller.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.bySemanticsLabel(_defaultMessage), findsOneWidget);
      },
    );

    testWidgets(
      'banner Semantics node has liveRegion=true for screen-reader announcements',
      (tester) async {
        final controller = StreamController<bool>();
        addTearDown(controller.close);

        await tester.pumpWidget(_buildApp(controller: controller));

        controller.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final semanticsNode =
            tester.getSemantics(find.bySemanticsLabel(_defaultMessage));
        expect(semanticsNode.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      },
    );
  });
}
