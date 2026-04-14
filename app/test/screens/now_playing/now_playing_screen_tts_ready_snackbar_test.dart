/// Widget tests for TASK-057 — NowPlayingScreen "AI Voice is now ready" snackbar.
///
/// ## Acceptance criteria
/// 1. Snackbar with text "AI Voice is now ready" appears when [isTtsReadyProvider]
///    transitions from `false` to `true` during active playback.
/// 2. The snackbar is NOT shown on initial widget load even if [isTtsReadyProvider]
///    starts as `true` (guard: `prev == false`, not just `next == true`).
/// 3. The snackbar is NOT shown when the value remains `false`.
///
/// ## Strategy
/// All external providers are overridden in a [ProviderScope] so no real
/// database, network, or platform channels are needed:
/// - [executionStateProvider] → seeded with a minimal running [ExecutionState].
/// - [isTtsReadyProvider]      → backed by [_isTtsReadyCtrl], a test-local
///   [StateProvider] whose state can be flipped mid-test to simulate the
///   false→true transition.
/// - [planTtsStatusProvider]   → empty stream (not the focus of this test).
/// - [planExecutionEngineProvider] → no-op stub (gesture handlers are not
///   exercised by these tests).
library now_playing_screen_tts_ready_snackbar_test;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/screens/now_playing/now_playing_screen.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stub PlanExecutionEngine
// ─────────────────────────────────────────────────────────────────────────────

/// No-op stub — gesture handlers are not triggered by the snackbar tests.
class _StubEngine implements PlanExecutionEngine {
  @override
  Stream<ExecutionState> get stateStream => const Stream.empty();
  @override
  ExecutionState? get currentState => null;
  @override
  bool get isPreview => false;

  @override
  Future<void> startPlan(Plan plan) async {}
  @override
  Future<void> startPlanFromStep(Plan plan, int flatStepIndex) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> skipForward() async {}
  @override
  Future<void> skipBackward() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> startPreview(Plan plan) async {}
  @override
  Future<ExecutionState?> getRecoverableSession([String? planId]) async => null;
  @override
  Future<PersistedSessionSummary?> getPersistedSessionSummaryForPlan(
      String planId) async =>
      null;
  @override
  Future<int?> getRecoverableStepIndexForPlan(String planId) async => null;
  @override
  Future<bool> resumeFromPersistedState(String planId) async => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// In-test [StateProvider] that backs the [isTtsReadyProvider] override.
/// Using a [StateProvider] lets tests mutate the value mid-run without
/// rebuilding the entire [ProviderScope].
final _isTtsReadyCtrl = StateProvider<bool>((ref) => false);

Plan _makePlan({String id = 'plan-test-id'}) {
  final now = DateTime.utc(2025, 1, 1);
  return Plan(
    id: id,
    name: 'Test Plan',
    createdAt: now,
    updatedAt: now,
  );
}

ExecutionState _runningState(Plan plan) => ExecutionState(
      plan: plan,
      currentStepIndex: 0,
      timeRemaining: const Duration(seconds: 30),
      status: ExecutionStatus.running,
      currentStepText: 'Step 1',
      currentStepType: StepType.wait,
      currentStepDuration: const Duration(seconds: 60),
    );

/// Builds a [NowPlayingScreen] inside a [ProviderScope] + [MaterialApp] with
/// all non-focal providers overridden.
///
/// [initialTtsReady] sets the starting value of [_isTtsReadyCtrl].  Tests can
/// later flip it via `container.read(_isTtsReadyCtrl.notifier).state = true`.
Widget _buildScreen(Plan plan, {bool initialTtsReady = false}) {
  final state = _runningState(plan);
  return ProviderScope(
    overrides: [
      // Stable running execution state — no real engine needed.
      executionStateProvider.overrideWith(
        (ref) => Stream.value(state),
      ),

      // Control the isTtsReady value via a test-local StateProvider.
      _isTtsReadyCtrl.overrideWith((ref) => initialTtsReady),
      isTtsReadyProvider(plan.id).overrideWith(
        (ref) => ref.watch(_isTtsReadyCtrl),
      ),

      // Empty TTS status stream — not tested here.
      planTtsStatusProvider(plan.id).overrideWith(
        (ref) => const Stream.empty(),
      ),

      // No-op stub — gesture handlers are not exercised.
      planExecutionEngineProvider.overrideWith(
        (ref) => _StubEngine(),
      ),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('NowPlayingScreen — AI Voice ready snackbar (TASK-057)', () {
    late Plan plan;

    setUp(() => plan = _makePlan());

    // ── AC-1 & AC-3: snackbar appears on false → true transition ─────────────

    testWidgets(
        'shows snackbar "AI Voice is now ready" when isTtsReady transitions false→true',
        (tester) async {
      await tester.pumpWidget(_buildScreen(plan, initialTtsReady: false));
      await tester.pump(); // first frame

      // Sanity: no snackbar before the transition.
      expect(find.text('AI Voice is now ready'), findsNothing);

      // Flip isTtsReady: false → true.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingScreen)),
      );
      container.read(_isTtsReadyCtrl.notifier).state = true;

      await tester.pump(); // rebuild → ref.listen callback fires
      await tester.pump(); // snackbar animation begins

      expect(
        find.text('AI Voice is now ready'),
        findsOneWidget,
        reason: 'Snackbar must appear when isTtsReady transitions false→true',
      );
    });

    // ── AC-2: no snackbar on initial load ────────────────────────────────────

    testWidgets(
        'does NOT show snackbar on initial load when isTtsReady is already true',
        (tester) async {
      // Start with isTtsReady already true — prev will be null, not false.
      await tester.pumpWidget(_buildScreen(plan, initialTtsReady: true));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('AI Voice is now ready'),
        findsNothing,
        reason: 'Snackbar must not appear on initial load (prev is null, not false)',
      );
    });

    // ── AC-2: no snackbar when value stays false ──────────────────────────────

    testWidgets(
        'does NOT show snackbar when isTtsReady remains false',
        (tester) async {
      await tester.pumpWidget(_buildScreen(plan, initialTtsReady: false));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('AI Voice is now ready'),
        findsNothing,
        reason: 'Snackbar must not appear when isTtsReady stays false',
      );
    });
  });
}
