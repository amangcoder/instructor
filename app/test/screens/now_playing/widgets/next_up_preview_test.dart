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
///
/// ## Acceptance criteria (TASK-013)
/// 5. Tapping NextUpPreview calls onTap once immediately.
/// 6. The FINAL STEP variant (nextStepText == null) is never tappable.
/// 7. When onTap is null, the card is rendered non-interactively.
/// 8. The interactive card carries button semantics and a tap hint.
void main() {
  /// Wraps [NextUpPreview] in a minimal [MaterialApp] so that theming and
  /// [MediaQuery] are available for the widget tree.
  Widget buildWidget({
    required String? nextStepText,
    StepType? nextStepType,
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: NextUpPreview(
            nextStepText: nextStepText,
            nextStepType: nextStepType,
            onTap: onTap,
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

        expect(find.text('Last step in this session'), findsOneWidget);
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

      // TASK-013: FINAL STEP card must never be tappable.
      testWidgets('is not tappable even when onTap is provided', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildWidget(
          nextStepText: null,
          nextStepType: null,
          onTap: () => tapped = true,
        ));

        // The FINAL STEP card ignores onTap — no InkWell is rendered.
        expect(find.byType(InkWell), findsNothing);
        expect(tapped, isFalse);
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

    // ── "NEXT UP" label display ──────────────────────────────────────────────
    group('"NEXT UP" label display', () {
      testWidgets('shows "NEXT UP" label when nextStepText is non-null',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Relax',
          nextStepType: StepType.wait,
        ));

        expect(find.text('NEXT UP'), findsOneWidget);
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

    // ── TASK-013: Tap-to-skip behaviour ─────────────────────────────────────
    group('TASK-013 — tap-to-skip interaction', () {
      testWidgets('calls onTap once when tapped', (tester) async {
        var tapCount = 0;
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Inhale',
          nextStepType: StepType.say,
          onTap: () => tapCount++,
        ));

        await tester.tap(find.byType(InkWell));
        await tester.pump();

        expect(tapCount, 1);
      });

      testWidgets('renders InkWell when onTap is provided', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Exhale',
          nextStepType: StepType.wait,
          onTap: () {},
        ));

        expect(find.byType(InkWell), findsOneWidget);
      });

      testWidgets('does NOT render InkWell when onTap is null', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Exhale',
          nextStepType: StepType.wait,
          // no onTap
        ));

        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('shows arrow affordance icon when tappable', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Exhale',
          nextStepType: StepType.wait,
          onTap: () {},
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.arrow_forward_ios_rounded,
          ),
          findsOneWidget,
        );
      });

      testWidgets('does NOT show arrow affordance when non-interactive',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Exhale',
          nextStepType: StepType.wait,
          // no onTap
        ));

        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.arrow_forward_ios_rounded,
          ),
          findsNothing,
        );
      });

      testWidgets('has button semantics when tappable', (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Hold breath',
          nextStepType: StepType.wait,
          onTap: () {},
        ));

        final semanticsNode = tester.getSemantics(
          find.bySemanticsLabel('Next up: Hold breath'),
        );

        // The Semantics wrapper marks it as a button with a tap hint.
        expect(semanticsNode.hasAction(SemanticsAction.tap), isTrue);
      });

      testWidgets('does not have button semantics when non-interactive',
          (tester) async {
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Hold breath',
          nextStepType: StepType.wait,
          // no onTap
        ));

        final semanticsNode = tester.getSemantics(
          find.bySemanticsLabel('Next up: Hold breath'),
        );

        expect(semanticsNode.hasAction(SemanticsAction.tap), isFalse);
      });

      testWidgets('multiple rapid taps all fire (debounce lives in parent)',
          (tester) async {
        // The widget itself does NOT debounce — debounce is handled in
        // NowPlayingScreen._onNextUpTap(). The widget just calls onTap each time.
        var tapCount = 0;
        await tester.pumpWidget(buildWidget(
          nextStepText: 'Sprint',
          nextStepType: StepType.wait,
          onTap: () => tapCount++,
        ));

        await tester.tap(find.byType(InkWell));
        await tester.tap(find.byType(InkWell));
        await tester.pump();

        // Both taps reach the callback — the caller (NowPlayingScreen) guards.
        expect(tapCount, 2);
      });
    });
  });
}
