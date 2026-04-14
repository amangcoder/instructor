import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/widgets/tts_status_badge.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [TtsStatusBadge] in a minimal Material app so that Theme and
/// Directionality are available without any provider setup.
Widget _buildApp({
  required String status,
  int completed = 0,
  int total = 0,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: TtsStatusBadge(
          status: status,
          completed: completed,
          total: total,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── none ────────────────────────────────────────────────────────────────────
  group('status: none', () {
    testWidgets('renders nothing (SizedBox.shrink)', (tester) async {
      await tester.pumpWidget(_buildApp(status: 'none'));

      // No progress indicator, no icons, no text.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('unknown status values also render nothing', (tester) async {
      await tester.pumpWidget(_buildApp(status: 'something_unknown'));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Icon), findsNothing);
    });
  });

  // ── processing ──────────────────────────────────────────────────────────────
  group('status: processing', () {
    testWidgets('shows a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 3, total: 10),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows determinate progress when total > 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 4, total: 8),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      // value should be 4/8 = 0.5
      expect(indicator.value, closeTo(0.5, 0.001));
    });

    testWidgets('shows indeterminate spinner when total == 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 0, total: 0),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('shows N/M progress text label when total > 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 3, total: 10),
      );

      expect(find.text('3/10'), findsOneWidget);
    });

    testWidgets('hides progress text label when total == 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 0, total: 0),
      );

      // No N/M text when total is unknown.
      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('has accessibility label describing progress', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 2, total: 5),
      );

      expect(
        find.bySemanticsLabel('Generating TTS audio: 2 of 5 complete'),
        findsOneWidget,
      );
    });

    testWidgets(
        'has generic accessibility label when total is 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 0, total: 0),
      );

      expect(
        find.bySemanticsLabel('TTS audio generation in progress'),
        findsOneWidget,
      );
    });

    testWidgets('does not render a warning or checkmark icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 1, total: 4),
      );

      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });
  });

  // ── pending ──────────────────────────────────────────────────────────────────
  group('status: pending', () {
    testWidgets('shows a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'pending', completed: 0, total: 5),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows determinate progress when total > 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'pending', completed: 1, total: 4),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, closeTo(0.25, 0.001));
    });

    testWidgets('shows indeterminate spinner when total == 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'pending', completed: 0, total: 0),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, isNull);
    });

    testWidgets('shows N/M text when total > 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'pending', completed: 0, total: 7),
      );

      expect(find.text('0/7'), findsOneWidget);
    });
  });

  // ── completed ─────────────────────────────────────────────────────────────
  group('status: completed', () {
    testWidgets('shows a checkmark icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'completed', completed: 10, total: 10),
      );

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('does not show a spinner or warning icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'completed', completed: 10, total: 10),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('has accessibility label "TTS generation complete"',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'completed', completed: 10, total: 10),
      );

      expect(
        find.bySemanticsLabel('TTS generation complete'),
        findsOneWidget,
      );
    });
  });

  // ── partial ───────────────────────────────────────────────────────────────
  group('status: partial', () {
    testWidgets('shows a warning icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'partial', completed: 7, total: 10),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show a spinner or checkmark', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'partial', completed: 7, total: 10),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets(
        'has accessibility label "TTS generation partially complete"',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'partial', completed: 7, total: 10),
      );

      expect(
        find.bySemanticsLabel('TTS generation partially complete'),
        findsOneWidget,
      );
    });
  });

  // ── failed ────────────────────────────────────────────────────────────────
  group('status: failed', () {
    testWidgets('shows a warning icon', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'failed', completed: 0, total: 10),
      );

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('does not show a spinner or checkmark', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'failed', completed: 0, total: 10),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('has accessibility label "TTS generation failed"',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'failed', completed: 0, total: 10),
      );

      expect(
        find.bySemanticsLabel('TTS generation failed'),
        findsOneWidget,
      );
    });
  });

  // ── progress value clamping ───────────────────────────────────────────────
  group('progress value clamping', () {
    testWidgets('clamps to 1.0 when completed > total', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 12, total: 10),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, closeTo(1.0, 0.001));
    });

    testWidgets('shows 0.0 when completed is 0', (tester) async {
      await tester.pumpWidget(
        _buildApp(status: 'processing', completed: 0, total: 8),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, closeTo(0.0, 0.001));
    });
  });
}
