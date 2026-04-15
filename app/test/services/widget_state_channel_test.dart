/// Unit tests for [WidgetStateChannel] — the iOS WidgetKit bridge.
///
/// ## Strategy
///
/// [WidgetStateChannel] sits at the boundary between Flutter and native iOS
/// (WidgetKit / UserDefaults). Tests avoid real MethodChannel calls by
/// registering a mock binary-messenger handler that captures every
/// `updateWidgetState` invocation.
///
/// Because [WidgetStateChannel.init] is a no-op on non-iOS platforms, tests
/// override [debugDefaultTargetPlatformOverride] to [TargetPlatform.iOS] for
/// the duration of each test.
///
/// ## What is tested
///
/// 1. **Throttle — immediate write** (REQ-014, AC-014)
///    First write after a cold start goes out immediately without waiting.
///
/// 2. **Throttle — coalesce rapid writes**
///    Multiple writes within 1 second are coalesced into a single channel
///    invocation, preventing UserDefaults write storms.
///
/// 3. **Throttle — write after window expires**
///    A second write that arrives more than 1 second after the first is
///    immediately flushed (not held in the pending buffer).
///
/// 4. **Streak keys included in every write** (REQ-012, AC-012)
///    Both the initial idle write and every execution-state write carry the
///    three streak keys: streak_count, completed_today, streak_freeze_count.
///
/// 5. **Streak update triggers a write** (REQ-014, AC-014)
///    When [StreakService.watchStreak] emits a new [StreakState], the channel
///    schedules a write within the throttle window.
///
/// 6. **Streak data merged with idle payload**
///    When streak updates but no plan is active, the payload status is
///    "stopped" and streak keys reflect the latest values.
///
/// 7. **Streak data merged with active-plan payload**
///    When execution state is active, the merged payload carries both playback
///    keys and streak keys.
///
/// 8. **dispose() cancels subscriptions**
///    After [dispose], no further writes are triggered by streak or execution
///    state changes.
///
/// 9. **Non-iOS platform — no writes**
///    [init] is a no-op on non-iOS; no channel invocations are made.
library widget_state_channel_test;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

import 'package:instructor/services/widget_state_channel.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/services/streak_service.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/models/streak_state.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fakes
// ────────────────────────────────────────────────────────────────────────────

/// Minimal [PlanExecutionEngine] fake with controllable [stateStream].
class _FakeEngine implements PlanExecutionEngine {
  final _controller = StreamController<ExecutionState>.broadcast();

  @override
  Stream<ExecutionState> get stateStream => _controller.stream;

  @override
  ExecutionState? get currentState => null;

  void emit(ExecutionState state) => _controller.add(state);

  Future<void> close() => _controller.close();

  // ── Stubbed out — not exercised by WidgetStateChannel tests ──────────────

  @override
  Future<void> start(Plan plan, {int startFromIndex = 0}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> skipForward() async {}

  @override
  Future<void> skipBackward() async {}

  @override
  Future<void> dispose() async {}
}

/// Minimal [StreakService] fake with controllable [watchStreak] stream.
class _FakeStreakService implements StreakService {
  final _controller = StreamController<StreakState>.broadcast();

  @override
  Stream<StreakState> watchStreak() => _controller.stream;

  @override
  StreakState calculateStreak() => _emptyState();

  void emit(StreakState state) => _controller.add(state);

  Future<void> close() => _controller.close();

  @override
  Future<bool> consumeStreakFreeze() async => false;

  @override
  Future<int> availableFreezes() async => 0;

  @override
  Future<List<DayStatus>> getCalendarDays(int count) async => [];
}

// ────────────────────────────────────────────────────────────────────────────
// Factories for test data
// ────────────────────────────────────────────────────────────────────────────

StreakState _emptyState({
  int currentStreak = 0,
  bool completedToday = false,
  int freezesAvailable = 0,
}) =>
    StreakState(
      currentStreak: currentStreak,
      longestStreak: currentStreak,
      completedToday: completedToday,
      freezesAvailable: freezesAvailable,
      calendarDays: [],
      computedAt: DateTime(2026, 4, 15),
    );

/// Builds a minimal [Plan] for constructing [ExecutionState].
Plan _fakePlan({String name = 'Test Plan'}) => Plan(
      id: 'plan-1',
      name: name,
      steps: [
        PlanStep.tts(id: 'step-1', text: 'Step one'),
      ],
      createdAt: DateTime(2026, 4, 15),
      updatedAt: DateTime(2026, 4, 15),
      isLocal: true,
    );

/// Builds an [ExecutionState] for the given status.
ExecutionState _fakeState({
  ExecutionStatus status = ExecutionStatus.running,
  String planName = 'Test Plan',
  String stepText = 'Step one',
}) =>
    ExecutionState(
      plan: _fakePlan(name: planName),
      status: status,
      currentStepIndex: 0,
      currentStepText: stepText,
      nextStepText: null,
      currentStepDuration: const Duration(seconds: 30),
      timeRemaining: const Duration(seconds: 22),
    );

// ────────────────────────────────────────────────────────────────────────────
// Test helper — capture MethodChannel calls
// ────────────────────────────────────────────────────────────────────────────

/// Registers a mock handler on [kWidgetStateChannel] that appends every
/// `updateWidgetState` invocation argument map to [calls].
///
/// Returns a teardown callback that removes the mock.
void Function() _captureCalls(List<Map<String, dynamic>> calls) {
  const codec = StandardMethodCodec();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(kWidgetStateChannel),
    (call) async {
      if (call.method == 'updateWidgetState') {
        calls.add(Map<String, dynamic>.from(call.arguments as Map));
      }
      return null;
    },
  );

  // Also silence the deep-link channel so it doesn't throw.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(kWidgetDeepLinkChannel),
    (call) async => null,
  );

  return () {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(kWidgetStateChannel),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel(kWidgetDeepLinkChannel),
      null,
    );
  };
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetStateChannel (iOS platform)', () {
    late _FakeEngine engine;
    late _FakeStreakService streakService;
    late List<Map<String, dynamic>> capturedCalls;
    late void Function() removeMock;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      engine = _FakeEngine();
      streakService = _FakeStreakService();
      capturedCalls = [];
      removeMock = _captureCalls(capturedCalls);
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      removeMock();
      await engine.close();
      await streakService.close();
    });

    // ── 1. Throttle — immediate write ──────────────────────────────────────

    test('init() writes idle state immediately on first call', () async {
      final channel = WidgetStateChannel.forTesting();
      addTearDown(channel.dispose);

      channel.init(engine, streakService);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.first['status'], 'stopped');
    });

    test('first execution-state write goes out immediately', () async {
      final channel = WidgetStateChannel.forTesting();
      addTearDown(channel.dispose);

      channel.init(engine, streakService);
      await Future<void>.delayed(Duration.zero);
      final initCount = capturedCalls.length; // 1 from idle write

      // Simulate time passing so we're past the throttle window.
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      engine.emit(_fakeState(status: ExecutionStatus.running));
      await Future<void>.delayed(Duration.zero);

      // Should have received exactly one more call.
      expect(capturedCalls.length, initCount + 1);
      expect(capturedCalls.last['status'], 'playing');
    });

    // ── 2. Throttle — coalesce rapid writes ───────────────────────────────

    test('rapid execution-state writes within 1 second are coalesced',
        () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();
        final initCount = capturedCalls.length; // 1 from idle write

        // Advance past the initial throttle window.
        async.elapse(const Duration(milliseconds: 1100));

        // First write after the window → goes immediately.
        engine.emit(_fakeState(stepText: 'Step A'));
        async.flushMicrotasks();
        final afterFirst = capturedCalls.length;

        // Rapid subsequent writes within 1 second — only one pending timer.
        engine.emit(_fakeState(stepText: 'Step B'));
        engine.emit(_fakeState(stepText: 'Step C'));
        engine.emit(_fakeState(stepText: 'Step D'));
        async.flushMicrotasks();

        // No additional writes yet (still in throttle window).
        expect(capturedCalls.length, afterFirst);

        // Advance past the throttle window — pending write flushes.
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        // Exactly one additional write — carrying the last payload (Step D).
        expect(capturedCalls.length, afterFirst + 1);
        expect(capturedCalls.last['step_text'], 'Step D');

        channel.dispose();
        expect(initCount, 1);
      });
    });

    // ── 3. Throttle — write after window expires ──────────────────────────

    test('writes separated by >1 second both go out immediately', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 1100));

        engine.emit(_fakeState(stepText: 'First'));
        async.flushMicrotasks();
        final afterFirst = capturedCalls.length;

        async.elapse(const Duration(milliseconds: 1100));

        engine.emit(_fakeState(stepText: 'Second'));
        async.flushMicrotasks();

        expect(capturedCalls.length, afterFirst + 1);
        expect(capturedCalls.last['step_text'], 'Second');

        channel.dispose();
      });
    });

    // ── 4. Streak keys included in every write ────────────────────────────

    test('idle write carries streak keys with default zero values', () async {
      final channel = WidgetStateChannel.forTesting();
      addTearDown(channel.dispose);

      channel.init(engine, streakService);
      await Future<void>.delayed(Duration.zero);

      final payload = capturedCalls.first;
      expect(payload, containsPair('streak_count', 0));
      expect(payload, containsPair('completed_today', false));
      expect(payload, containsPair('streak_freeze_count', 0));
    });

    test('execution-state write carries streak keys', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();

        // Seed streak state first.
        streakService.emit(
          _emptyState(
            currentStreak: 7,
            completedToday: true,
            freezesAvailable: 1,
          ),
        );
        async.elapse(const Duration(milliseconds: 1100));

        engine.emit(_fakeState());
        async.flushMicrotasks();

        final payload = capturedCalls.last;
        expect(payload, containsPair('streak_count', 7));
        expect(payload, containsPair('completed_today', true));
        expect(payload, containsPair('streak_freeze_count', 1));

        channel.dispose();
      });
    });

    test('all five required playback keys are present', () async {
      final channel = WidgetStateChannel.forTesting();
      addTearDown(channel.dispose);

      channel.init(engine, streakService);
      await Future<void>.delayed(Duration.zero);

      final payload = capturedCalls.first;
      expect(payload, contains('plan_name'));
      expect(payload, contains('step_text'));
      expect(payload, contains('next_step_text'));
      expect(payload, contains('status'));
      expect(payload, contains('step_duration_ms'));
      expect(payload, contains('elapsed_ms'));
      expect(payload, contains('updated_at'));
      expect(payload, contains('streak_count'));
      expect(payload, contains('completed_today'));
      expect(payload, contains('streak_freeze_count'));
    });

    // ── 5. Streak update triggers a write ─────────────────────────────────

    test('streak state change schedules a write', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();

        // Advance past the initial throttle window.
        async.elapse(const Duration(milliseconds: 1100));

        final callsBefore = capturedCalls.length;

        streakService.emit(_emptyState(currentStreak: 5, completedToday: true));
        async.flushMicrotasks();

        // Should have received an additional write for the streak update.
        expect(capturedCalls.length, greaterThan(callsBefore));
        expect(capturedCalls.last['streak_count'], 5);
        expect(capturedCalls.last['completed_today'], true);

        channel.dispose();
      });
    });

    // ── 6. Streak data merged with idle payload ────────────────────────────

    test('streak-only update uses idle (stopped) playback payload when no '
        'active plan', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1100));

        streakService.emit(_emptyState(currentStreak: 3, completedToday: false));
        async.flushMicrotasks();

        expect(capturedCalls.last['status'], 'stopped');
        expect(capturedCalls.last['streak_count'], 3);
        expect(capturedCalls.last['completed_today'], false);

        channel.dispose();
      });
    });

    // ── 7. Streak data merged with active-plan payload ─────────────────────

    test('streak update while plan is running keeps playing status', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1100));

        // First make an execution state known.
        engine.emit(_fakeState(status: ExecutionStatus.running, planName: 'Yoga'));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1100));

        // Now emit a streak update.
        streakService.emit(_emptyState(currentStreak: 10, completedToday: true));
        async.flushMicrotasks();

        expect(capturedCalls.last['status'], 'playing');
        expect(capturedCalls.last['plan_name'], 'Yoga');
        expect(capturedCalls.last['streak_count'], 10);

        channel.dispose();
      });
    });

    // ── 8. dispose() cancels subscriptions ────────────────────────────────

    test('dispose() prevents further writes after streak update', () async {
      fakeAsync((async) {
        final channel = WidgetStateChannel.forTesting();
        channel.init(engine, streakService);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1100));

        channel.dispose();
        final callsAfterDispose = capturedCalls.length;

        streakService.emit(_emptyState(currentStreak: 99));
        engine.emit(_fakeState());
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // No additional writes after dispose.
        expect(capturedCalls.length, callsAfterDispose);
      });
    });
  });

  // ── 9. Non-iOS platform — no writes ─────────────────────────────────────

  group('WidgetStateChannel (non-iOS platform)', () {
    late List<Map<String, dynamic>> capturedCalls;
    late void Function() removeMock;

    setUp(() {
      // Explicitly NOT setting iOS override — uses host platform (linux/etc.)
      capturedCalls = [];
      removeMock = _captureCalls(capturedCalls);
    });

    tearDown(() {
      removeMock();
    });

    test('init() is a no-op on non-iOS — no channel calls made', () async {
      final engine = _FakeEngine();
      final streakService = _FakeStreakService();
      addTearDown(() async {
        await engine.close();
        await streakService.close();
      });

      final channel = WidgetStateChannel.forTesting();
      addTearDown(channel.dispose);

      channel.init(engine, streakService);
      await Future<void>.delayed(Duration.zero);

      expect(capturedCalls, isEmpty);
    });
  });
}
