/// Widget tests for TASK-058 — NowPlayingScreen crash-recovery TTS toggle
/// default.
///
/// ## Acceptance criteria
/// 1. After crash recovery succeeds, [ttsPlaybackModeProvider] is set to
///    [TtsPlaybackMode.genai] when [isTtsReadyProvider] returns `true`.
/// 2. After crash recovery succeeds, [ttsPlaybackModeProvider] is set to
///    [TtsPlaybackMode.platform] when [isTtsReadyProvider] returns `false`.
///
/// ## Strategy
/// All external providers are overridden in a [ProviderScope]:
/// - [executionStateProvider]    → error stream so the crash-recovery UI is
///   rendered immediately.
/// - [isTtsReadyProvider]        → hard-coded to `true` or `false` per test.
/// - [planTtsStatusProvider]     → empty stream (not the focus of this test).
/// - [planExecutionEngineProvider] → [_RecoveringStubEngine] whose
///   [getRecoverableSession] returns a [ExecutionState] for [_kPlanId] and
///   [resumeFromPersistedState] succeeds synchronously.
/// - [ttsPlaybackModeProvider]   → NOT overridden; we verify its value is
///   mutated by the recovery handler.
library now_playing_screen_crash_recovery_tts_test;

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
// Shared test constants
// ─────────────────────────────────────────────────────────────────────────────

const _kPlanId = 'crash-recovery-test-plan-id';

// ─────────────────────────────────────────────────────────────────────────────
// Stub PlanExecutionEngine — returns a recoverable session for [_kPlanId]
// ─────────────────────────────────────────────────────────────────────────────

Plan _makePlan({String id = _kPlanId}) {
  final now = DateTime.utc(2025, 1, 1);
  return Plan(
    id: id,
    name: 'Recovery Test Plan',
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

/// Stub engine whose [getRecoverableSession] returns a recoverable
/// [ExecutionState] for [_kPlanId].  All other operations are no-ops.
class _RecoveringStubEngine implements PlanExecutionEngine {
  _RecoveringStubEngine({required this.recoverablePlan});

  final Plan recoverablePlan;

  @override
  Stream<ExecutionState> get stateStream => const Stream.empty();

  @override
  ExecutionState? get currentState => null;

  @override
  bool get isPreview => false;

  @override
  Future<ExecutionState?> getRecoverableSession([String? planId]) async =>
      _runningState(recoverablePlan);

  @override
  Future<bool> resumeFromPersistedState(String planId) async => true;

  // ── Unused stubs ───────────────────────────────────────────────────────────

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
  Future<PersistedSessionSummary?> getPersistedSessionSummaryForPlan(
          String planId) async =>
      null;

  @override
  Future<int?> getRecoverableStepIndexForPlan(String planId) async => null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen builder
// ─────────────────────────────────────────────────────────────────────────────

/// Pumps a [NowPlayingScreen] in error state so the crash-recovery Retry
/// button is visible.  [isTtsReady] controls the overridden value of
/// [isTtsReadyProvider] for [_kPlanId].
Widget _buildCrashedScreen({required bool isTtsReady}) {
  final plan = _makePlan();
  return ProviderScope(
    overrides: [
      // Error stream → renders the crash-recovery UI with the Retry button.
      executionStateProvider.overrideWith(
        (ref) => Stream<ExecutionState>.error(Exception('simulated crash')),
      ),

      // Control TTS readiness: the value the recovery handler will read.
      isTtsReadyProvider(plan.id).overrideWith((ref) => isTtsReady),

      // Empty TTS status stream — not tested here.
      planTtsStatusProvider(plan.id).overrideWith(
        (ref) => const Stream.empty(),
      ),

      // Stub engine that returns a recoverable session for plan.id.
      planExecutionEngineProvider.overrideWith(
        (ref) => _RecoveringStubEngine(recoverablePlan: plan),
      ),
    ],
    child: const MaterialApp(home: NowPlayingScreen()),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('NowPlayingScreen — crash recovery TTS default (TASK-058)', () {
    // ── AC-1: AI Voice when TTS is ready ─────────────────────────────────────

    testWidgets(
        'sets ttsPlaybackModeProvider to genai when isTtsReady is true after recovery',
        (tester) async {
      await tester.pumpWidget(_buildCrashedScreen(isTtsReady: true));
      // First frame renders the error UI.
      await tester.pump();

      // The crash-recovery Retry button should be visible.
      expect(find.text('Retry'), findsOneWidget);

      // Capture the container before tapping (element is guaranteed to exist
      // while the error UI is rendered).
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingScreen)),
      );

      // Precondition: default mode is platform.
      expect(
        container.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
        reason: 'Default TTS mode should be platform before recovery',
      );

      // Tap Retry — triggers the crash recovery handler.
      await tester.tap(find.text('Retry'));
      await tester.pump(); // process microtasks / async completions

      // After recovery with isTtsReady == true → genai.
      expect(
        container.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.genai,
        reason:
            'Recovery should set ttsPlaybackModeProvider to genai when TTS is ready',
      );
    });

    // ── AC-2: Device when TTS is not ready ───────────────────────────────────

    testWidgets(
        'sets ttsPlaybackModeProvider to platform when isTtsReady is false after recovery',
        (tester) async {
      await tester.pumpWidget(_buildCrashedScreen(isTtsReady: false));
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(NowPlayingScreen)),
      );

      // Tap Retry — triggers the crash recovery handler.
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // After recovery with isTtsReady == false → platform.
      expect(
        container.read(ttsPlaybackModeProvider),
        TtsPlaybackMode.platform,
        reason:
            'Recovery should set ttsPlaybackModeProvider to platform when TTS is not ready',
      );
    });
  });
}
