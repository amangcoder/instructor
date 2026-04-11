import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/providers/execution_providers.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/widgets/mini_player_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fakes
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal [PlanExecutionEngine] fake for widget tests.
///
/// Exposes [emitState] so tests can push execution states into the stream,
/// and records method calls so we can verify [pause]/[resume]/[stop] were
/// invoked by the widget.
class _FakeEngine implements PlanExecutionEngine {
  final StreamController<ExecutionState> _controller =
      StreamController<ExecutionState>.broadcast();

  ExecutionState? _currentState;
  bool pauseCalled = false;
  bool resumeCalled = false;
  bool stopCalled = false;

  @override
  ExecutionState? get currentState => _currentState;

  @override
  Stream<ExecutionState> get stateStream => _controller.stream;

  /// Push a new [ExecutionState] to all stream listeners.
  void emitState(ExecutionState state) {
    _currentState = state;
    _controller.add(state);
  }

  @override
  Future<void> startPlan(Plan plan) async {}

  @override
  Future<void> pause() async => pauseCalled = true;

  @override
  Future<void> resume() async => resumeCalled = true;

  @override
  Future<void> stop() async {
    stopCalled = true;
    _currentState = null;
  }

  @override
  Future<void> skipForward() async {}

  @override
  Future<void> skipBackward() async {}

  @override
  Future<ExecutionState?> getRecoverableSession([int? planId]) async => null;

  @override
  Future<int?> getRecoverableStepIndexForPlan(int planId) async => null;

  @override
  Future<bool> resumeFromPersistedState(int planId) async => false;

  @override
  Future<void> startPreview(Plan plan) async {}

  @override
  bool get isPreview => false;

  void dispose() => _controller.close();
}

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A minimal [Plan] fixture used in tests.
Plan _testPlan({String name = 'Morning Yoga'}) {
  final now = DateTime.now();
  return Plan(
    id: 1,
    name: name,
    category: PlanCategory.yoga,
    steps: [],
    createdAt: now,
    updatedAt: now,
  );
}

/// Creates an [ExecutionState] in the [running] status with the given fields.
ExecutionState _runningState({
  Plan? plan,
  String? currentStepText,
  StepType currentStepType = StepType.say,
  Duration currentStepDuration = const Duration(seconds: 60),
  Duration timeRemaining = const Duration(seconds: 30),
}) {
  return ExecutionState(
    plan: plan ?? _testPlan(),
    currentStepIndex: 0,
    status: ExecutionStatus.running,
    currentStepText: currentStepText ?? 'Inhale deeply',
    currentStepType: currentStepType,
    currentStepDuration: currentStepDuration,
    timeRemaining: timeRemaining,
  );
}

/// Creates an [ExecutionState] in the [paused] status.
ExecutionState _pausedState({Plan? plan}) {
  return ExecutionState(
    plan: plan ?? _testPlan(),
    currentStepIndex: 0,
    status: ExecutionStatus.paused,
    currentStepText: 'Exhale slowly',
    currentStepType: StepType.wait,
    currentStepDuration: const Duration(seconds: 30),
    timeRemaining: const Duration(seconds: 15),
  );
}

/// Builds the widget tree with GoRouter navigation and provider overrides.
///
/// [initialState] — if provided, the engine is seeded with this state so
/// that [executionStateProvider] immediately emits it (simulating a session
/// already in progress when the widget is first pumped).
Widget _buildApp({
  required _FakeEngine engine,
  ExecutionState? initialState,
}) {
  if (initialState != null) {
    engine.emitState(initialState);
  }

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: const Center(child: Text('Home')),
          bottomNavigationBar: const MiniPlayerBar(),
        ),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Now Playing')),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      planExecutionEngineProvider.overrideWithValue(engine),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakeEngine engine;

  setUp(() {
    engine = _FakeEngine();
  });

  tearDown(() {
    engine.dispose();
  });

  // ── AC-2: Hidden when idle ─────────────────────────────────────────────────
  group('when execution state is idle', () {
    testWidgets('renders SizedBox.shrink (zero size) — bar is hidden',
        (tester) async {
      await tester.pumpWidget(_buildApp(engine: engine));
      // No state emitted → executionStateProvider is AsyncLoading → idle
      await tester.pump();

      // The MiniPlayerBar should produce no visible content.
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
    });
  });

  // ── AC-1: Visible when running ─────────────────────────────────────────────
  group('when execution state is running', () {
    testWidgets('shows the mini-player bar', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump(); // process stream

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows plan name as primary text', (tester) async {
      final state = _runningState(plan: _testPlan(name: 'Evening Run'));
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.text('Evening Run'), findsOneWidget);
    });

    testWidgets('shows current step text as secondary text', (tester) async {
      final state = _runningState(currentStepText: 'Breathe in for 4 counts');
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.text('Breathe in for 4 counts'), findsOneWidget);
    });

    testWidgets('shows pause icon when running', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('shows stop button', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });
  });

  // ── AC-1: Visible when paused ──────────────────────────────────────────────
  group('when execution state is paused', () {
    testWidgets('shows mini-player bar', (tester) async {
      final state = _pausedState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows play icon when paused', (tester) async {
      final state = _pausedState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });
  });

  // ── AC-3: Progress indicator value ────────────────────────────────────────
  group('progress indicator', () {
    testWidgets('shows 50% progress when half duration elapsed', (tester) async {
      // Total 60s, 30s remaining → 50% elapsed.
      final state = _runningState(
        currentStepDuration: const Duration(seconds: 60),
        timeRemaining: const Duration(seconds: 30),
      );
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.5, 0.01));
    });

    testWidgets('shows 0% progress when no time has elapsed', (tester) async {
      // Total 60s, 60s remaining → 0% elapsed.
      final state = _runningState(
        currentStepDuration: const Duration(seconds: 60),
        timeRemaining: const Duration(seconds: 60),
      );
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.0, 0.01));
    });

    testWidgets('shows ~100% progress when almost done', (tester) async {
      final state = _runningState(
        currentStepDuration: const Duration(seconds: 60),
        timeRemaining: const Duration(seconds: 1),
      );
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, greaterThan(0.95));
    });

    testWidgets('returns 0.0 when step duration is zero', (tester) async {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        status: ExecutionStatus.running,
        currentStepDuration: Duration.zero,
        timeRemaining: Duration.zero,
      );
      engine.emitState(state);

      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, closeTo(0.0, 0.01));
    });
  });

  // ── AC-5: Play/pause toggle ────────────────────────────────────────────────
  group('play/pause button', () {
    testWidgets('tapping pause button calls engine.pause()', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(engine.pauseCalled, isTrue);
      expect(engine.resumeCalled, isFalse);
    });

    testWidgets('tapping play button calls engine.resume()', (tester) async {
      final state = _pausedState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(engine.resumeCalled, isTrue);
      expect(engine.pauseCalled, isFalse);
    });

    testWidgets('icon switches from pause to play after state transitions',
        (tester) async {
      final runningState = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: runningState));
      await tester.pump();

      // Initially running → shows pause icon.
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Engine transitions to paused.
      engine.emitState(_pausedState());
      await tester.pump();

      // Now shows play icon.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });
  });

  // ── AC-6: Stop confirmation dialog ────────────────────────────────────────
  group('stop button', () {
    testWidgets('tapping stop shows confirmation dialog', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('End session?'), findsOneWidget);
    });

    testWidgets('cancelling the dialog does NOT call engine.stop()',
        (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(engine.stopCalled, isFalse);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('confirming the dialog calls engine.stop()', (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      expect(engine.stopCalled, isTrue);
    });
  });

  // ── AC-4: Body tap navigates to /now-playing ──────────────────────────────
  group('body tap navigation', () {
    testWidgets('tapping the text area navigates to /now-playing',
        (tester) async {
      final state = _runningState(plan: _testPlan(name: 'Yoga Flow'));
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      // Tap the plan name text (part of the tappable body area).
      await tester.tap(find.text('Yoga Flow'));
      await tester.pumpAndSettle();

      expect(find.text('Now Playing'), findsOneWidget);
    });
  });

  // ── Accessibility ──────────────────────────────────────────────────────────
  group('accessibility', () {
    testWidgets('play/pause button has semantic label "Pause" when playing',
        (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    });

    testWidgets('play/pause button has semantic label "Play" when paused',
        (tester) async {
      final state = _pausedState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.bySemanticsLabel('Play'), findsOneWidget);
    });

    testWidgets('stop button has semantic label "Stop session"',
        (tester) async {
      final state = _runningState();
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.bySemanticsLabel('Stop session'), findsOneWidget);
    });

    testWidgets('body area has semantic label with plan name', (tester) async {
      final state = _runningState(plan: _testPlan(name: 'HIIT Workout'));
      await tester.pumpWidget(_buildApp(engine: engine, initialState: state));
      await tester.pump();

      expect(find.bySemanticsLabel('Open HIIT Workout'), findsOneWidget);
    });
  });

  // ── Step type fallback labels ──────────────────────────────────────────────
  group('step type fallback labels when currentStepText is null', () {
    testWidgets('shows "Speaking…" for SayStep with null currentStepText',
        (tester) async {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        status: ExecutionStatus.running,
        currentStepType: StepType.say,
        currentStepText: null,
        currentStepDuration: const Duration(seconds: 10),
        timeRemaining: const Duration(seconds: 5),
      );
      engine.emitState(state);
      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();

      expect(find.text('Speaking…'), findsOneWidget);
    });

    testWidgets('shows "Waiting…" for WaitStep with null currentStepText',
        (tester) async {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        status: ExecutionStatus.running,
        currentStepType: StepType.wait,
        currentStepText: null,
        currentStepDuration: const Duration(seconds: 30),
        timeRemaining: const Duration(seconds: 15),
      );
      engine.emitState(state);
      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();

      expect(find.text('Waiting…'), findsOneWidget);
    });

    testWidgets('shows "Playing audio…" for PlayStep with null currentStepText',
        (tester) async {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        status: ExecutionStatus.running,
        currentStepType: StepType.play,
        currentStepText: null,
        currentStepDuration: const Duration(seconds: 120),
        timeRemaining: const Duration(seconds: 60),
      );
      engine.emitState(state);
      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();

      expect(find.text('Playing audio…'), findsOneWidget);
    });

    testWidgets('shows "Running…" for unknown step type', (tester) async {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        status: ExecutionStatus.running,
        currentStepType: null,
        currentStepText: null,
        currentStepDuration: const Duration(seconds: 10),
        timeRemaining: const Duration(seconds: 5),
      );
      engine.emitState(state);
      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();

      expect(find.text('Running…'), findsOneWidget);
    });
  });

  // ── AnimatedSize: visibility transitions ──────────────────────────────────
  group('animated visibility transitions', () {
    testWidgets('bar appears when session starts (idle → running)',
        (tester) async {
      // Start with no state → bar hidden.
      await tester.pumpWidget(_buildApp(engine: engine));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsNothing);

      // Emit a running state.
      engine.emitState(_runningState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // animation

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('bar disappears when session ends (running → idle)',
        (tester) async {
      // Start with a running session.
      await tester.pumpWidget(_buildApp(
        engine: engine,
        initialState: _runningState(),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Emit an idle/completed state.
      engine.emitState(
        ExecutionState(
          plan: _testPlan(),
          currentStepIndex: 0,
          status: ExecutionStatus.completed,
          currentStepDuration: Duration.zero,
          timeRemaining: Duration.zero,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // animation

      expect(find.byIcon(Icons.pause_rounded), findsNothing);
    });
  });
}
