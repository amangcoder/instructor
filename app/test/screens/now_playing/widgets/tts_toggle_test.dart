import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/screens/now_playing/widgets/tts_toggle.dart';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Wraps [widget] in a [MaterialApp] + [ProviderScope] so it can be pumped
/// inside a [testWidgets] callback.
Widget _wrap(
  Widget widget, {
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: Center(child: widget))),
    );

/// Convenience: finds the [SegmentedButton] in the tree.
Finder get _segmentedButton =>
    find.byType(SegmentedButton<TtsPlaybackMode>);

/// Returns the first [SegmentedButton] widget.
SegmentedButton<TtsPlaybackMode> _getButton(WidgetTester tester) =>
    tester.widget<SegmentedButton<TtsPlaybackMode>>(_segmentedButton);

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  group('TtsToggle', () {
    // ── Rendering ────────────────────────────────────────────────────────────

    testWidgets('renders a SegmentedButton with Device and AI Voice segments',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'none', isActive: false)),
      );

      expect(_segmentedButton, findsOneWidget);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('AI Voice'), findsOneWidget);
    });

    testWidgets('shows Device segment with phone icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'none', isActive: false)),
      );

      expect(find.byIcon(Icons.phone_android_outlined), findsOneWidget);
    });

    // ── Device always enabled ─────────────────────────────────────────────────

    testWidgets('Device segment is always enabled regardless of ttsStatus',
        (tester) async {
      for (final status in ['none', 'pending', 'processing', 'completed', 'partial', 'failed']) {
        await tester.pumpWidget(
          _wrap(TtsToggle(ttsStatus: status, isActive: false)),
        );
        await tester.pump();

        final btn = _getButton(tester);
        final deviceSegment = btn.segments.firstWhere(
          (s) => s.value == TtsPlaybackMode.platform,
        );
        expect(
          deviceSegment.enabled,
          isTrue,
          reason: 'Device segment should be enabled for status "$status"',
        );
      }
    });

    testWidgets('Device segment is selected by default', (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'none', isActive: false)),
      );

      final btn = _getButton(tester);
      expect(btn.selected, equals({TtsPlaybackMode.platform}));
    });

    // ── AI Voice disabled states ──────────────────────────────────────────────

    testWidgets('AI Voice segment is disabled when ttsStatus is "none"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'none', isActive: false)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isFalse);
    });

    testWidgets('AI Voice segment is disabled when ttsStatus is "failed"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'failed', isActive: true)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isFalse);
    });

    // ── Downloading state ─────────────────────────────────────────────────────

    testWidgets('shows "Downloading…" label when ttsStatus is "pending"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'pending', isActive: true)),
      );

      expect(find.text('Downloading…'), findsOneWidget);
      expect(find.text('AI Voice'), findsNothing);
    });

    testWidgets('shows "Downloading…" label when ttsStatus is "processing"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'processing', isActive: true)),
      );

      expect(find.text('Downloading…'), findsOneWidget);
    });

    testWidgets(
        'AI Voice segment is disabled while downloading (pending)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'pending', isActive: true)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isFalse);
    });

    testWidgets('shows CircularProgressIndicator when downloading',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'pending', isActive: true)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'AI Voice segment is disabled while downloading (processing)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'processing', isActive: true)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isFalse);
    });

    // ── AI Voice ready states ─────────────────────────────────────────────────

    testWidgets('AI Voice segment is enabled when ttsStatus is "completed"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'completed', isActive: true)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isTrue);
    });

    testWidgets('AI Voice segment is enabled when ttsStatus is "partial"',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'partial', isActive: true)),
      );

      final btn = _getButton(tester);
      final aiSegment = btn.segments.firstWhere(
        (s) => s.value == TtsPlaybackMode.genai,
      );
      expect(aiSegment.enabled, isTrue);
    });

    testWidgets('shows AI Voice label (not Downloading) when ready',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'completed', isActive: true)),
      );

      expect(find.text('AI Voice'), findsOneWidget);
      expect(find.text('Downloading…'), findsNothing);
    });

    testWidgets('shows auto_awesome icon when ready (not downloading)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'completed', isActive: true)),
      );

      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
    });

    // ── Mode toggling ─────────────────────────────────────────────────────────

    testWidgets('tapping AI Voice segment updates ttsPlaybackModeProvider',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const TtsToggle(
                      ttsStatus: 'completed',
                      isActive: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
      );

      // Tap the AI Voice segment text.
      await tester.tap(find.text('AI Voice'));
      await tester.pump();

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.genai,
      );
    });

    testWidgets(
        'tapping Device segment switches back from genai to platform',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlaybackModeProvider
                .overrideWith((ref) => TtsPlaybackMode.genai),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const TtsToggle(
                      ttsStatus: 'completed',
                      isActive: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the Device segment text.
      await tester.tap(find.text('Device'));
      await tester.pump();

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
      );
    });

    // ── Auto-reset when genai becomes unavailable ─────────────────────────────

    testWidgets(
        'resets to platform mode when genai is selected but AI Voice becomes unavailable',
        (tester) async {
      late WidgetRef capturedRef;

      // Create a fresh notifier for this test to avoid cross-test pollution.
      final statusNotifier = ValueNotifier<String>('completed');
      addTearDown(statusNotifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlaybackModeProvider
                .overrideWith((ref) => TtsPlaybackMode.genai),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return ValueListenableBuilder<String>(
                      valueListenable: statusNotifier,
                      builder: (_, status, __) => TtsToggle(
                        ttsStatus: status,
                        isActive: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Initially genai is selected and the segment is enabled.
      expect(capturedRef.read(ttsPlaybackModeProvider), TtsPlaybackMode.genai);

      // Simulate status change to 'failed' — AI Voice is no longer available.
      statusNotifier.value = 'failed';
      await tester.pump(); // rebuild with new ttsStatus
      await tester.pump(); // post-frame callback fires

      // Provider should have been reset to platform.
      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
      );
    });

    // ── Locked state ──────────────────────────────────────────────────────────

    testWidgets('isLocked disables the entire SegmentedButton', (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(
          ttsStatus: 'completed',
          isActive: true,
          isLocked: true,
        )),
      );

      final btn = _getButton(tester);
      expect(btn.onSelectionChanged, isNull);
    });

    testWidgets('isLocked prevents mode change when tapping AI Voice',
        (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const TtsToggle(
                      ttsStatus: 'completed',
                      isActive: true,
                      isLocked: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
      );

      // Attempt to tap AI Voice — locked, so provider must not change.
      await tester.tap(find.text('AI Voice'));
      await tester.pump();

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
      );
    });

    testWidgets('isLocked=false still allows mode change', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: Consumer(
                  builder: (context, ref, _) {
                    capturedRef = ref;
                    return const TtsToggle(
                      ttsStatus: 'completed',
                      isActive: true,
                      isLocked: false,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('AI Voice'));
      await tester.pump();

      expect(
        capturedRef.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.genai,
      );
    });

    // ── Semantics ─────────────────────────────────────────────────────────────

    testWidgets('has a voice mode semantics label', (tester) async {
      await tester.pumpWidget(
        _wrap(const TtsToggle(ttsStatus: 'none', isActive: false)),
      );

      expect(
        find.bySemanticsLabel('Voice mode'),
        findsOneWidget,
      );
    });

    testWidgets('shows locked semantics hint when isLocked is true',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const TtsToggle(
          ttsStatus: 'completed',
          isActive: true,
          isLocked: true,
        )),
      );

      // The Semantics node labelled 'Voice mode' carries the hint.
      final node = tester.getSemantics(find.bySemanticsLabel('Voice mode'));
      expect(node.hint, contains('cannot be changed'));
      handle.dispose();
    });
  });
}
