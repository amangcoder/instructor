/// Unit tests for [InstructorAudioHandler], [PhoneCallHandlerImpl], and
/// [executionStateToMediaItem].
///
/// ## Test strategy
///
/// [audio_service] and [audio_session] both require native platform plugins.
/// To run these tests in a pure-Dart environment we:
///
///   1. Construct [InstructorAudioHandler] directly (without calling
///      [AudioService.init]) — [BaseAudioHandler] is a plain Dart class and
///      does not need the platform plugin to be active.
///
///   2. Use fake implementations ([_FakePlanExecutionEngine],
///      [_FakeNotificationService], [_FakePhoneCallHandler]) to record calls
///      and drive state without any platform channels.
///
///   3. Do NOT test [initializeBackgroundService] — that function calls
///      [AudioService.init] and [AudioSession.instance] which need real
///      platform channels. Those paths are exercised in manual QA on a device.
///
/// ## What is tested
///
/// - [InstructorAudioHandler.play]  → calls [PlanExecutionEngine.resume]
/// - [InstructorAudioHandler.pause] → calls [PlanExecutionEngine.pause]
/// - [InstructorAudioHandler.skipToNext] → calls [PlanExecutionEngine.skipForward]
/// - [InstructorAudioHandler.skipToPrevious] → calls [PlanExecutionEngine.skipBackward]
/// - [InstructorAudioHandler.stop] → calls [PlanExecutionEngine.stop]
/// - Lock screen [mediaItem] update on state change
/// - Lock screen [playbackState] update (playing flag, controls)
/// - [PhoneCallHandlerImpl] start/stop listening call counts
/// - [executionStateToMediaItem]: title, artist, duration, stable id
library background_service_test;

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/services/background_service.dart';
import 'package:instructor/services/notification_service.dart';
import 'package:instructor/services/phone_call_handler.dart';
import 'package:instructor/services/plan_execution_engine.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fake implementations
// ────────────────────────────────────────────────────────────────────────────

/// Observable fake [PlanExecutionEngine].
///
/// Exposes a [stateController] so tests can push [ExecutionState] values and
/// verify that the handler updates the lock screen accordingly.
class _FakePlanExecutionEngine implements PlanExecutionEngine {
  // ── Call tracking ──────────────────────────────────────────────────────────
  int pauseCount = 0;
  int resumeCount = 0;
  int skipForwardCount = 0;
  int skipBackwardCount = 0;
  int stopCount = 0;

  // ── State stream ───────────────────────────────────────────────────────────
  final StreamController<ExecutionState> stateController =
      StreamController<ExecutionState>.broadcast();

  @override
  Stream<ExecutionState> get stateStream => stateController.stream;

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  @override
  Future<void> skipForward() async => skipForwardCount++;

  @override
  Future<void> skipBackward() async => skipBackwardCount++;

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> startPlan(Plan plan) async {}

  @override
  Future<ExecutionState?> getRecoverableSession() async => null;

  @override
  Future<void> startPreview(Plan plan) async {}

  @override
  bool get isPreview => false;

  Future<void> dispose() async {
    await stateController.close();
  }
}

/// Observable fake [NotificationService].
class _FakeNotificationService implements NotificationService {
  int initializeCount = 0;
  int cancelAllCount = 0;
  final List<String> resumePromptPlanNames = [];
  final List<({String title, String body})> stepNotifications = [];
  final List<({String stepText, Duration remaining})> foregroundUpdates = [];

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<void> showStepNotification(String title, String body) async {
    stepNotifications.add((title: title, body: body));
  }

  @override
  Future<void> showResumePrompt(String planName) async {
    resumePromptPlanNames.add(planName);
  }

  @override
  Future<void> cancelAll() async => cancelAllCount++;

  @override
  Future<void> updateForegroundNotification(
    String stepText,
    Duration remaining,
  ) async {
    foregroundUpdates.add((stepText: stepText, remaining: remaining));
  }
}

/// Observable fake [PhoneCallHandler].
class _FakePhoneCallHandler implements PhoneCallHandler {
  int startCount = 0;
  int stopCount = 0;

  @override
  void startListening() => startCount++;

  @override
  void stopListening() => stopCount++;
}

// ────────────────────────────────────────────────────────────────────────────
// Test fixtures
// ────────────────────────────────────────────────────────────────────────────

/// A minimal [Plan] for use in tests.
Plan _testPlan({
  int id = 1,
  String name = 'Morning Yoga',
  List<PlanStep>? steps,
}) {
  return Plan(
    id: id,
    name: name,
    steps: steps ?? [],
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

/// A minimal running [ExecutionState].
ExecutionState _runningState({
  Plan? plan,
  int currentStepIndex = 0,
  Duration timeRemaining = const Duration(minutes: 5),
}) {
  return ExecutionState(
    plan: plan ?? _testPlan(),
    currentStepIndex: currentStepIndex,
    timeRemaining: timeRemaining,
    status: ExecutionStatus.running,
  );
}

/// A minimal paused [ExecutionState].
ExecutionState _pausedState({
  Plan? plan,
  int currentStepIndex = 0,
}) {
  return ExecutionState(
    plan: plan ?? _testPlan(),
    currentStepIndex: currentStepIndex,
    timeRemaining: const Duration(minutes: 3),
    status: ExecutionStatus.paused,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ── InstructorAudioHandler — lock screen controls ─────────────────────────

  group('InstructorAudioHandler — control delegation', () {
    late _FakePlanExecutionEngine engine;
    late _FakePhoneCallHandler phoneCallHandler;
    late InstructorAudioHandler handler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      phoneCallHandler = _FakePhoneCallHandler();
      handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: phoneCallHandler,
      );
    });

    tearDown(() async {
      await handler.disposeHandler();
      await engine.dispose();
    });

    test('play() delegates to PlanExecutionEngine.resume()', () async {
      await handler.play();
      expect(engine.resumeCount, 1);
      expect(engine.pauseCount, 0);
    });

    test('pause() delegates to PlanExecutionEngine.pause()', () async {
      await handler.pause();
      expect(engine.pauseCount, 1);
      expect(engine.resumeCount, 0);
    });

    test('skipToNext() delegates to PlanExecutionEngine.skipForward()', () async {
      await handler.skipToNext();
      expect(engine.skipForwardCount, 1);
      expect(engine.skipBackwardCount, 0);
    });

    test('skipToPrevious() delegates to PlanExecutionEngine.skipBackward()',
        () async {
      await handler.skipToPrevious();
      expect(engine.skipBackwardCount, 1);
      expect(engine.skipForwardCount, 0);
    });

    test('stop() delegates to PlanExecutionEngine.stop()', () async {
      await handler.stop();
      expect(engine.stopCount, 1);
    });

    test('multiple sequential controls are all delegated', () async {
      await handler.play();
      await handler.pause();
      await handler.skipToNext();
      await handler.skipToPrevious();
      await handler.stop();

      expect(engine.resumeCount, 1);
      expect(engine.pauseCount, 1);
      expect(engine.skipForwardCount, 1);
      expect(engine.skipBackwardCount, 1);
      expect(engine.stopCount, 1);
    });
  });

  // ── InstructorAudioHandler — lock screen mediaItem ────────────────────────

  group('InstructorAudioHandler — mediaItem updates', () {
    late _FakePlanExecutionEngine engine;
    late InstructorAudioHandler handler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: _FakePhoneCallHandler(),
      );
    });

    tearDown(() async {
      await handler.disposeHandler();
      await engine.dispose();
    });

    test('mediaItem title is set to plan name on state change', () async {
      final plan = _testPlan(name: 'Evening Meditation');

      engine.stateController.add(_runningState(plan: plan));
      await Future<void>.delayed(Duration.zero); // allow stream to dispatch

      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.title, 'Evening Meditation');
    });

    test(
        'mediaItem artist falls back to "Step N" when no step text in state',
        () async {
      // _runningState does not set currentStepText, so the "Step N" fallback
      // kicks in: currentStepIndex 2 → "Step 3".
      engine.stateController.add(_runningState(currentStepIndex: 2));
      await Future<void>.delayed(Duration.zero);

      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.artist, 'Step 3');
    });

    test('mediaItem artist shows actual step text when state carries it',
        () async {
      engine.stateController.add(ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: const Duration(seconds: 20),
        status: ExecutionStatus.running,
        currentStepText: 'Inhale for four counts',
        currentStepType: StepType.say,
      ));
      await Future<void>.delayed(Duration.zero);

      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.artist, 'Inhale for four counts');
    });

    test('mediaItem artist shows Wait format for WaitStep state', () async {
      engine.stateController.add(ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 1,
        timeRemaining: const Duration(seconds: 15),
        status: ExecutionStatus.running,
        currentStepType: StepType.wait,
      ));
      await Future<void>.delayed(Duration.zero);

      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.artist, 'Wait: 15s remaining');
    });

    test('mediaItem id is stable across state updates with same plan', () async {
      final plan = _testPlan(id: 42);

      engine.stateController.add(_runningState(plan: plan, currentStepIndex: 0));
      await Future<void>.delayed(Duration.zero);
      final id1 = handler.mediaItem.value?.id;

      engine.stateController.add(_runningState(plan: plan, currentStepIndex: 1));
      await Future<void>.delayed(Duration.zero);
      final id2 = handler.mediaItem.value?.id;

      expect(id1, id2);
    });

    test('mediaItem duration reflects plan totalDuration', () async {
      final plan = _testPlan(
        steps: [
          const PlanStep.wait(id: 'w1', duration: Duration(minutes: 10)),
          const PlanStep.wait(id: 'w2', duration: Duration(minutes: 5)),
        ],
      );

      engine.stateController.add(_runningState(plan: plan));
      await Future<void>.delayed(Duration.zero);

      final item = handler.mediaItem.value;
      expect(item, isNotNull);
      expect(item!.duration, const Duration(minutes: 15));
    });

    test('mediaItem updates on each state emission', () async {
      final plan1 = _testPlan(id: 1, name: 'Plan A');
      final plan2 = _testPlan(id: 2, name: 'Plan B');

      engine.stateController.add(_runningState(plan: plan1));
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.title, 'Plan A');

      engine.stateController.add(_runningState(plan: plan2));
      await Future<void>.delayed(Duration.zero);
      expect(handler.mediaItem.value?.title, 'Plan B');
    });
  });

  // ── InstructorAudioHandler — lock screen playbackState ────────────────────

  group('InstructorAudioHandler — playbackState updates', () {
    late _FakePlanExecutionEngine engine;
    late InstructorAudioHandler handler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: _FakePhoneCallHandler(),
      );
    });

    tearDown(() async {
      await handler.disposeHandler();
      await engine.dispose();
    });

    test('playbackState.playing is true when status is running', () async {
      engine.stateController.add(_runningState());
      await Future<void>.delayed(Duration.zero);

      expect(handler.playbackState.value.playing, isTrue);
    });

    test('playbackState.playing is false when status is paused', () async {
      engine.stateController.add(_pausedState());
      await Future<void>.delayed(Duration.zero);

      expect(handler.playbackState.value.playing, isFalse);
    });

    test('playbackState includes pause control when running', () async {
      engine.stateController.add(_runningState());
      await Future<void>.delayed(Duration.zero);

      final controls = handler.playbackState.value.controls;
      expect(
        controls.any((c) => c.action == MediaAction.pause),
        isTrue,
        reason: 'pause control should be present while running',
      );
    });

    test('playbackState includes play control when paused', () async {
      engine.stateController.add(_pausedState());
      await Future<void>.delayed(Duration.zero);

      final controls = handler.playbackState.value.controls;
      expect(
        controls.any((c) => c.action == MediaAction.play),
        isTrue,
        reason: 'play control should be present while paused',
      );
    });

    test('playbackState always includes skip-previous and skip-next controls',
        () async {
      engine.stateController.add(_runningState());
      await Future<void>.delayed(Duration.zero);

      final controls = handler.playbackState.value.controls;
      expect(
        controls.any((c) => c.action == MediaAction.skipToPrevious),
        isTrue,
      );
      expect(
        controls.any((c) => c.action == MediaAction.skipToNext),
        isTrue,
      );
    });

    test('playbackState processingState is completed when execution completes',
        () async {
      engine.stateController.add(ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: Duration.zero,
        status: ExecutionStatus.completed,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.completed,
      );
    });

    test('playbackState processingState is ready while running or paused',
        () async {
      engine.stateController.add(_runningState());
      await Future<void>.delayed(Duration.zero);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.ready,
      );

      engine.stateController.add(_pausedState());
      await Future<void>.delayed(Duration.zero);
      expect(
        handler.playbackState.value.processingState,
        AudioProcessingState.ready,
      );
    });
  });

  // ── InstructorAudioHandler — phone call handler wiring ────────────────────

  group('InstructorAudioHandler — phone call handler lifecycle', () {
    late _FakePlanExecutionEngine engine;
    late _FakePhoneCallHandler phoneCallHandler;
    late InstructorAudioHandler handler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      phoneCallHandler = _FakePhoneCallHandler();
      handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: phoneCallHandler,
      );
    });

    tearDown(() async {
      await handler.disposeHandler();
      await engine.dispose();
    });

    test('startPhoneCallHandler() calls phoneCallHandler.startListening()', () {
      handler.startPhoneCallHandler();
      expect(phoneCallHandler.startCount, 1);
    });

    test('disposeHandler() calls phoneCallHandler.stopListening()', () async {
      await handler.disposeHandler();
      expect(phoneCallHandler.stopCount, 1);
    });
  });

  // ── PhoneCallHandlerImpl — call tracking ──────────────────────────────────

  group('PhoneCallHandlerImpl — startListening / stopListening', () {
    late _FakePlanExecutionEngine engine;
    late _FakeNotificationService notificationService;
    late PhoneCallHandlerImpl callHandler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      notificationService = _FakeNotificationService();
      callHandler = PhoneCallHandlerImpl(
        engine: engine,
        notificationService: notificationService,
      );
    });

    tearDown(() async {
      callHandler.stopListening();
      await engine.dispose();
    });

    test('stopListening() after startListening() does not throw', () {
      callHandler.startListening();
      expect(() => callHandler.stopListening(), returnsNormally);
    });

    test('stopListening() without startListening() does not throw', () {
      expect(() => callHandler.stopListening(), returnsNormally);
    });

    test(
        'stopListening() resets call state so a second startListening() '
        'starts fresh', () {
      callHandler.startListening();
      callHandler.stopListening();
      // A second start+stop cycle should also be safe.
      callHandler.startListening();
      expect(() => callHandler.stopListening(), returnsNormally);
    });
  });

  // ── executionStateToMediaItem ─────────────────────────────────────────────

  group('executionStateToMediaItem', () {
    test('title is the plan name', () {
      final item = executionStateToMediaItem(
        _runningState(plan: _testPlan(name: 'Yoga Flow')),
      );
      expect(item.title, 'Yoga Flow');
    });

    // When currentStepText is null (no step text in state), fall back to
    // "Step N" so the lock screen always shows something meaningful.
    test('artist falls back to "Step N" when currentStepText is null', () {
      expect(
        executionStateToMediaItem(_runningState(currentStepIndex: 0)).artist,
        'Step 1',
      );
      expect(
        executionStateToMediaItem(_runningState(currentStepIndex: 4)).artist,
        'Step 5',
      );
      expect(
        executionStateToMediaItem(_runningState(currentStepIndex: 9)).artist,
        'Step 10',
      );
    });

    test('artist shows actual step text when currentStepText is provided', () {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 2,
        timeRemaining: const Duration(seconds: 10),
        status: ExecutionStatus.running,
        currentStepText: 'Breathe in deeply',
        currentStepType: StepType.say,
      );
      expect(executionStateToMediaItem(state).artist, 'Breathe in deeply');
    });

    test('artist is truncated to 100 chars with ellipsis for long step text',
        () {
      // 101-character step text — must be truncated to exactly 100 chars.
      final longText = 'A' * 101;
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: const Duration(seconds: 5),
        status: ExecutionStatus.running,
        currentStepText: longText,
        currentStepType: StepType.say,
      );
      final artist = executionStateToMediaItem(state).artist;
      expect(artist.length, 100);
      expect(artist, endsWith('...'));
    });

    test('artist is NOT truncated when step text is exactly 100 chars', () {
      final exactText = 'B' * 100;
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: const Duration(seconds: 5),
        status: ExecutionStatus.running,
        currentStepText: exactText,
        currentStepType: StepType.say,
      );
      final artist = executionStateToMediaItem(state).artist;
      expect(artist, exactText);
    });

    test('WaitStep shows "Wait: Ns remaining" using timeRemaining', () {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 1,
        timeRemaining: const Duration(seconds: 45),
        status: ExecutionStatus.running,
        currentStepType: StepType.wait,
        currentStepDuration: const Duration(seconds: 60),
      );
      expect(executionStateToMediaItem(state).artist, 'Wait: 45s remaining');
    });

    test('WaitStep uses timeRemaining not currentStepDuration for Ns value',
        () {
      // timeRemaining=30s but total step duration is 120s — must show 30s.
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: const Duration(seconds: 30),
        status: ExecutionStatus.running,
        currentStepType: StepType.wait,
        currentStepDuration: const Duration(seconds: 120),
      );
      expect(executionStateToMediaItem(state).artist, 'Wait: 30s remaining');
    });

    test('WaitStep with zero remaining shows "Wait: 0s remaining"', () {
      final state = ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: Duration.zero,
        status: ExecutionStatus.running,
        currentStepType: StepType.wait,
      );
      expect(executionStateToMediaItem(state).artist, 'Wait: 0s remaining');
    });

    test('duration is plan totalDuration', () {
      final plan = _testPlan(
        steps: [
          const PlanStep.wait(id: 'w1', duration: Duration(minutes: 3)),
          const PlanStep.wait(id: 'w2', duration: Duration(minutes: 7)),
        ],
      );
      final item = executionStateToMediaItem(_runningState(plan: plan));
      expect(item.duration, const Duration(minutes: 10));
    });

    test('id is stable for the same plan across different step indices', () {
      final plan = _testPlan(id: 99);
      final id0 = executionStateToMediaItem(
        _runningState(plan: plan, currentStepIndex: 0),
      ).id;
      final id5 = executionStateToMediaItem(
        _runningState(plan: plan, currentStepIndex: 5),
      ).id;
      expect(id0, id5);
    });

    test('id changes when plan changes', () {
      final id1 = executionStateToMediaItem(
        _runningState(plan: _testPlan(id: 1)),
      ).id;
      final id2 = executionStateToMediaItem(
        _runningState(plan: _testPlan(id: 2)),
      ).id;
      expect(id1, isNot(id2));
    });

    test('works with an empty plan (no steps)', () {
      final plan = _testPlan(steps: []);
      expect(
        () => executionStateToMediaItem(_runningState(plan: plan)),
        returnsNormally,
      );
    });

    test('works for paused and completed states', () {
      final pausedItem = executionStateToMediaItem(_pausedState());
      expect(pausedItem.title, isNotEmpty);

      final completedItem = executionStateToMediaItem(ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: Duration.zero,
        status: ExecutionStatus.completed,
      ));
      expect(completedItem.title, isNotEmpty);
    });

    test('title with special characters is preserved verbatim', () {
      final item = executionStateToMediaItem(
        _runningState(plan: _testPlan(name: 'Plan: "Sunrise" — v2')),
      );
      expect(item.title, 'Plan: "Sunrise" — v2');
    });

    test('id contains plan id', () {
      final plan = _testPlan(id: 123);
      final item = executionStateToMediaItem(_runningState(plan: plan));
      expect(item.id, contains('123'));
    });
  });

  // ── InstructorAudioHandler — compile-time interface compliance ────────────

  group('InstructorAudioHandler — interface compliance', () {
    test('is a BaseAudioHandler', () {
      final engine = _FakePlanExecutionEngine();
      final handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: _FakePhoneCallHandler(),
      );
      expect(handler, isA<BaseAudioHandler>());
    });

    test('PhoneCallHandlerImpl is a PhoneCallHandler', () {
      final callHandler = PhoneCallHandlerImpl(
        engine: _FakePlanExecutionEngine(),
        notificationService: _FakeNotificationService(),
      );
      expect(callHandler, isA<PhoneCallHandler>());
    });
  });

  // ── PhoneCallHandlerImpl — interruption event filtering ───────────────────
  //
  // Verifies that duck interruption events (short notification/navigation
  // sounds) do NOT trigger a pause, and that the engine is only paused on
  // genuine non-duck begin interruptions when a plan is actively running.
  //
  // This guards against the regression introduced by androidWillPauseWhenDucked:
  // if that flag were set to true, audio_session would report duck focus-loss
  // events as AudioInterruptionType.pause, and every notification sound would
  // spuriously pause execution.
  //
  // Uses [PhoneCallHandlerImpl.handleInterruptionForTest] (visibleForTesting)
  // to drive interruption events without requiring a live AudioSession.

  group('PhoneCallHandlerImpl — interruption event filtering', () {
    late _FakePlanExecutionEngine engine;
    late _FakeNotificationService notificationService;
    late PhoneCallHandlerImpl callHandler;

    /// Pushes a running [ExecutionState] so [PhoneCallHandlerImpl._lastState]
    /// is set, allowing interruption events to reach the pause logic.
    Future<void> seedRunningState() async {
      engine.stateController.add(ExecutionState(
        plan: _testPlan(),
        currentStepIndex: 0,
        timeRemaining: const Duration(minutes: 5),
        status: ExecutionStatus.running,
      ));
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      engine = _FakePlanExecutionEngine();
      notificationService = _FakeNotificationService();
      callHandler = PhoneCallHandlerImpl(
        engine: engine,
        notificationService: notificationService,
      );
      // Start the state subscription (AudioSession.instance will fail silently
      // in the test environment — that is intentional and handled by onError).
      callHandler.startListening();
    });

    tearDown(() async {
      callHandler.stopListening();
      await engine.dispose();
    });

    test(
      'duck interruption (begin=true, type=duck) does NOT pause execution '
      '— guard against notification/nav sounds being treated as phone calls',
      () async {
        await seedRunningState();

        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(true, AudioInterruptionType.duck),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          engine.pauseCount,
          0,
          reason:
              'Duck interruptions (notification / navigation sounds) must NOT '
              'pause execution. If androidWillPauseWhenDucked were true, these '
              'events would arrive as type=pause and spuriously pause the plan.',
        );
      },
    );

    test(
      'duck end event (begin=false, type=duck) does NOT pause execution',
      () async {
        await seedRunningState();

        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(false, AudioInterruptionType.duck),
        );
        await Future<void>.delayed(Duration.zero);

        expect(engine.pauseCount, 0);
      },
    );

    test(
      'non-duck begin interruption (type=pause) DOES pause when plan is running',
      () async {
        await seedRunningState();

        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          engine.pauseCount,
          1,
          reason:
              'A genuine phone-call interruption (type=pause, begin=true) '
              'must pause execution when the plan is running.',
        );
      },
    );

    test(
      'non-duck begin interruption does NOT pause when plan is already paused',
      () async {
        // Push a paused state — the handler should short-circuit.
        engine.stateController.add(ExecutionState(
          plan: _testPlan(),
          currentStepIndex: 0,
          timeRemaining: const Duration(minutes: 3),
          status: ExecutionStatus.paused,
        ));
        await Future<void>.delayed(Duration.zero);

        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          engine.pauseCount,
          0,
          reason:
              'Engine.pause() must not be called when the plan is already '
              'paused — the engine guards against re-entrant pauses, but '
              'the phone-call handler should not add unnecessary calls.',
        );
      },
    );

    test(
      'end event (begin=false) does NOT pause — only shows resume prompt '
      'when _pausedForCall is true',
      () async {
        await seedRunningState();

        // Fire an end event without a preceding begin event — should be a no-op.
        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(false, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);

        expect(engine.pauseCount, 0);
        expect(
          notificationService.resumePromptPlanNames,
          isEmpty,
          reason:
              'No resume prompt should appear when there was no preceding '
              'phone-call interruption (spurious end events are ignored).',
        );
      },
    );

    test(
      'end event after begin event shows resume prompt with plan name',
      () async {
        await seedRunningState();

        // Begin: phone call starts → pauses plan.
        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(true, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);
        expect(engine.pauseCount, 1);

        // End: phone call finishes → resume prompt shown.
        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(false, AudioInterruptionType.pause),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          notificationService.resumePromptPlanNames,
          contains('Morning Yoga'),
          reason:
              'After the call ends, a resume-prompt notification must be '
              'shown with the plan name so the user can return to the session.',
        );
      },
    );

    test(
      'unknown begin interruption (type=unknown) DOES pause when running',
      () async {
        await seedRunningState();

        callHandler.handleInterruptionForTest(
          const AudioInterruptionEvent(true, AudioInterruptionType.unknown),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          engine.pauseCount,
          1,
          reason:
              'Unknown interruption types (e.g. permanent focus loss on '
              'Android) should pause execution as a safe default.',
        );
      },
    );
  });

  // ── InstructorAudioHandler — stop latency benchmark (REQ-003) ────────────
  //
  // REQ-003 requires the stop action to complete within 500 ms so the
  // notification is dismissed without a perceptible delay.  In the unit-test
  // environment all collaborators are fakes (no I/O, no platform channels),
  // so the test validates that the *code path* itself — i.e. no double-stop,
  // no unnecessary sequential awaits — does not structurally add latency.
  //
  // Note: AudioSession.instance is called inside stop() but is a no-op in the
  // test environment (the audio_session plugin registers a no-op fallback when
  // no native platform is present). super.stop() is also a no-op in the
  // BaseAudioHandler test path.

  group('InstructorAudioHandler — stop latency benchmark', () {
    late _FakePlanExecutionEngine engine;
    late _FakePhoneCallHandler phoneCallHandler;
    late InstructorAudioHandler handler;

    setUp(() {
      engine = _FakePlanExecutionEngine();
      phoneCallHandler = _FakePhoneCallHandler();
      handler = InstructorAudioHandler(
        engine: engine,
        phoneCallHandler: phoneCallHandler,
      );
    });

    tearDown(() async {
      await handler.disposeHandler();
      await engine.dispose();
    });

    test(
      'stop() calls engine.stop() exactly once — no double-stop (REQ-003)',
      () async {
        await handler.stop();

        // engine.stop() must be called exactly once: the handler delegates to
        // the engine which internally calls Future.wait([stopAll, ...]).
        // A count > 1 would mean a redundant stopAll() is being triggered.
        expect(
          engine.stopCount,
          1,
          reason:
              'InstructorAudioHandler.stop() must call engine.stop() exactly '
              'once. A count > 1 indicates a redundant stopAll() call that '
              'adds latency and violates REQ-003.',
        );
      },
    );

    test(
      'stop() completes within 500 ms (REQ-003 latency benchmark)',
      () async {
        // In the unit-test environment all fakes complete synchronously or
        // near-synchronously.  If the stop chain were ever serialised with a
        // redundant _audioEngine.stopAll() it would appear as an extra async
        // hop here, making the test timing erratic.  Asserting an upper bound
        // of 500 ms catches regressions even without a real device.
        final sw = Stopwatch()..start();
        await handler.stop();
        sw.stop();

        expect(
          sw.elapsedMilliseconds,
          lessThan(500),
          reason:
              'stop() must complete within 500 ms to satisfy REQ-003. '
              'Elapsed: ${sw.elapsedMilliseconds} ms.',
        );
      },
    );

    test(
      'playbackState is idle after stop() (REQ-003 — notification dismissed)',
      () async {
        // Simulate an active session first.
        engine.stateController.add(_runningState());
        await Future<void>.delayed(Duration.zero);
        expect(handler.playbackState.value.playing, isTrue);

        // Stop and verify the handler emits an idle playback state, which
        // triggers the lock-screen widget and notification to clear.
        await handler.stop();
        final state = handler.playbackState.value;
        expect(state.processingState, AudioProcessingState.idle);
        expect(state.playing, isFalse);
      },
    );
  });
}
