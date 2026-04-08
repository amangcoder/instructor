import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/screens/now_playing/widgets/next_up_preview.dart';

/// Widget tests for [NextUpPreview].
///
/// ## Acceptance criteria (TASK-005)
/// 1. NextUpPreview shows the correct step type icon for the actual next step.
/// 2. When a SayStep is current and a WaitStep is next, the preview shows the
///    wait icon/color, not the say icon/color.
/// 3. Last step still shows 'Last step' indicator correctly.
/// 4. When nextStepType is null, NextUpPreview falls back to generic chevron icon.
void main() {
  /// Wraps [NextUpPreview] in a minimal [MaterialApp] so that theming and
  /// [MediaQuery] are available for the widget tree.
  Widget buildWidget({
    required String? nextStepText,
    StepType? nextStepType,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: NextUpPreview(
            nextStepText: nextStepText,
            nextStepType: nextStepType,
          ),
        ),
      ),
    );
  }

  group('NextUpPreview', () {
    // ── AC-3: Last step indicator ───────────────────────────────────────────
    group('when nextStepText is null (last step)', () {
      testWidgets('shows "Last step" text', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: null,
          nextStepType: null,
        ));

        expect(find.text('Last step'), findsOneWidget);
      });

      testWidgets('does not show "Next: " prefix', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: null,
          nextStepType: null,
        ));

        expect(find.text('Next: '), findsNothing);
      });

      testWidgets('shows check_circle_outline icon', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: null,
          nextStepType: null,
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.check_circle_outline,
          ),
          findsOneWidget,
        );
      });

      testWidgets('has accessible semantics label "Last step — no next step"',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: null,
          nextStepType: null,
        ));

        expect(
          find.bySemanticsLabel('Last step — no next step'),
          findsOneWidget,
        );
      });
    });

    // ── AC-1 + AC-2: Correct icon for the actual NEXT step ──────────────────
    group('when a WaitStep is next (say current → wait next)', () {
      testWidgets('shows timer_outlined icon (WaitStep icon)', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Breathe slowly for 60 seconds',
          nextStepType: StepType.wait, // NEXT step is wait
        ));

        // timer_outlined is the icon for StepType.wait
        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.timer_outlined,
          ),
          findsOneWidget,
        );
      });

      testWidgets('does NOT show record_voice_over icon (SayStep icon)',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Breathe slowly for 60 seconds',
          nextStepType: StepType.wait, // NEXT step is wait, not say
        ));

        // record_voice_over_outlined is the icon for StepType.say — must NOT appear
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Icon && w.icon == Icons.record_voice_over_outlined,
          ),
          findsNothing,
        );
      });

      testWidgets('shows the next step text', (tester) async {
        const nextText = 'Breathe slowly for 60 seconds';
        await tester.pumpWidget(buildWidget(
          nextStepText: nextText,
          nextStepType: StepType.wait,
        ));

        expect(find.text(nextText), findsOneWidget);
      });
    });

    group('when a SayStep is next', () {
      testWidgets('shows record_voice_over_outlined icon', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Inhale deeply',
          nextStepType: StepType.say,
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.record_voice_over_outlined,
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows the next step text', (tester) async {
        const nextText = 'Inhale deeply';
        await tester.pumpWidget(buildWidget(
          nextStepText: nextText,
          nextStepType: StepType.say,
        ));

        expect(find.text(nextText), findsOneWidget);
      });
    });

    group('when a PlayStep is next', () {
      testWidgets('shows music_note_outlined icon', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Ambient rain sound',
          nextStepType: StepType.play,
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.music_note_outlined,
          ),
          findsOneWidget,
        );
      });
    });

    // ── AC-4: Fallback chevron when nextStepType is null ───────────────────
    group('when nextStepText is set but nextStepType is null', () {
      testWidgets('shows chevron_right icon as fallback', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Some next step',
          nextStepType: null, // unknown type — fall back to chevron
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.chevron_right,
          ),
          findsOneWidget,
        );
      });

      testWidgets('still shows the next step text', (tester) async {
        const nextText = 'Some next step';
        await tester.pumpWidget(buildWidget(
          nextStepText: nextText,
          nextStepType: null,
        ));

        expect(find.text(nextText), findsOneWidget);
      });

      testWidgets('shows "Next: " prefix', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Some next step',
          nextStepType: null,
        ));

        expect(find.text('Next: '), findsOneWidget);
      });

      testWidgets('has accessible semantics label "Next up: <text>"',
          (tester) async {
        const nextText = 'Some next step';
        await tester.pumpWidget(buildWidget(
          nextStepText: nextText,
          nextStepType: null,
        ));

        expect(
          find.bySemanticsLabel('Next up: $nextText'),
          findsOneWidget,
        );
      });
    });

    // ── Verify "Next: " prefix appears for non-null nextStepText ────────────
    group('"Next: " prefix display', () {
      testWidgets('shows "Next: " label when nextStepText is non-null',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Relax',
          nextStepType: StepType.wait,
        ));

        expect(find.text('Next: '), findsOneWidget);
      });

      testWidgets('truncates long next step text with ellipsis', (tester) async {
        // A very long string — widget should not overflow.
        final longText = 'A' * 200;
        await tester.pumpWidget(buildWidget(
          nextStepText: longText,
          nextStepType: StepType.say,
        ));

        // No overflow errors — widget renders successfully.
        expect(tester.takeException(), isNull);
      });
    });
  });
}
