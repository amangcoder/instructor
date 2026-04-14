import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/audio_file_url.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/library_plan_summary.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/tts_status_info.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/providers/library_providers.dart' as libProviders;
import 'package:instructor/providers/plan_providers.dart';
import 'package:instructor/providers/tts_status_providers.dart';
import 'package:instructor/repositories/plan_repository.dart';
import 'package:instructor/screens/plan_library/plan_library_screen.dart';
import 'package:instructor/screens/plan_library/widgets/plan_card.dart';
import 'package:instructor/services/audio_download_service.dart';
import 'package:instructor/services/plan_api_service.dart';
import 'package:instructor/services/plan_execution_engine.dart';
import 'package:instructor/widgets/offline_banner.dart';
import 'package:instructor/widgets/tts_status_badge.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fakes
// ────────────────────────────────────────────────────────────────────────────

/// In-memory [PlanRepository] for tests — no database required.
class _FakePlanRepository implements PlanRepository {
  final List<Plan> _plans = [];
  int _nextNum = 1;

  // Broadcast controller so streams can emit multiple events.
  final StreamController<List<Plan>> _controller =
      StreamController<List<Plan>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_plans));

  @override
  Future<String> createPlan(Plan plan) async {
    // Use the supplied id if non-empty, otherwise auto-generate one.
    final id = plan.id.isEmpty ? 'plan-${_nextNum++}' : plan.id;
    _plans.add(plan.copyWith(id: id));
    _emit();
    return id;
  }

  @override
  Future<void> updatePlan(String id, Plan plan) async {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plans[index] = plan.copyWith(id: id);
      _emit();
    }
  }

  @override
  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    _emit();
  }

  @override
  Future<Plan?> getPlanById(String id) async =>
      _plans.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> activatePlan(String id, {required String voice, required String locale, required String speechRate}) async {}

  @override
  Stream<List<Plan>> watchUserPlans({
    String? searchQuery,
    PlanCategory? category,
  }) {
    return _controller.stream.map((plans) {
      var result = plans.toList();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        result = result
            .where(
              (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()),
            )
            .toList();
      }
      if (category != null) {
        result = result.where((p) => p.category == category).toList();
      }
      return result;
    });
  }

  @override
  Future<void> updateLastUsed(String id) async {
    final index = _plans.indexWhere((p) => p.id == id);
    if (index != -1) {
      _plans[index] = _plans[index].copyWith(lastUsedAt: DateTime.now());
      _emit();
    }
  }

  @override
  Future<int> remapPlanVoices(Map<String, String> voiceMap) async => 0;

  @override
  Future<void> refreshFromServer() async {
    refreshCallCount++;
    if (_refreshError != null) throw _refreshError!;
  }

  /// Tracks how many times [refreshFromServer] has been called.
  int refreshCallCount = 0;

  /// When set, [refreshFromServer] throws this error to simulate a
  /// network failure during pull-to-refresh.
  Exception? _refreshError;

  void simulateRefreshError(Exception error) => _refreshError = error;
  void clearRefreshError() => _refreshError = null;

  void dispose() => _controller.close();
}

// ────────────────────────────────────────────────────────────────────────────
// _FakeAudioDownloadService
// ────────────────────────────────────────────────────────────────────────────

/// In-memory [AudioDownloadService] for tests.
///
/// Records [downloadPlanAudio] calls in [downloadCalls] and supports
/// simulating errors via [nextError].
class _FakeAudioDownloadService implements AudioDownloadService {
  /// All plan IDs passed to [downloadPlanAudio] in call order.
  final List<String> downloadCalls = [];

  /// When non-null, the next [downloadPlanAudio] call throws this exception.
  Exception? nextError;

  final _progressController =
      StreamController<DownloadProgress>.broadcast();

  @override
  Stream<DownloadProgress> get downloadProgress =>
      _progressController.stream;

  @override
  Future<void> downloadPlanAudio(String planId) async {
    downloadCalls.add(planId);
    if (nextError != null) {
      final e = nextError!;
      nextError = null;
      throw e;
    }
  }

  @override
  Future<bool> isFullyDownloaded(String planId) async => false;

  void dispose() => _progressController.close();
}

// ────────────────────────────────────────────────────────────────────────────
// _FakePlanApiService
// ────────────────────────────────────────────────────────────────────────────

/// In-memory [PlanApiService] for tests — returns configurable library plans.
class _FakePlanApiService implements PlanApiService {
  /// Plans returned by [fetchLibraryPlans].
  List<LibraryPlanSummary> libraryPlans = [];

  /// Plans returned by [getLibraryPlanById], keyed by library plan ID.
  final Map<String, Plan> _libraryPlanDetails = {};

  /// When set, [getLibraryPlanById] throws this error.
  Exception? getLibraryPlanByIdError;

  void addLibraryPlanDetail(Plan plan) {
    _libraryPlanDetails[plan.id] = plan;
  }

  @override
  Future<List<LibraryPlanSummary>> fetchLibraryPlans({
    String? category,
    String? search,
    int page = 1,
  }) async {
    var result = libraryPlans;
    if (search != null && search.isNotEmpty) {
      result = result
          .where(
            (p) => p.name.toLowerCase().contains(search.toLowerCase()),
          )
          .toList();
    }
    if (category != null && category.isNotEmpty) {
      result = result
          .where((p) => p.category.name == category)
          .toList();
    }
    return result;
  }

  @override
  Future<Plan> getLibraryPlanById(String id) async {
    if (getLibraryPlanByIdError != null) throw getLibraryPlanByIdError!;
    final plan = _libraryPlanDetails[id];
    if (plan == null) {
      throw PlanApiException('Plan $id not found');
    }
    return plan;
  }

  @override
  Future<List<Plan>> fetchUserPlans() async => [];

  @override
  Future<Plan> getPlanById(String id) async {
    throw PlanApiException('not implemented');
  }

  @override
  Future<String> savePlan(Plan plan) async => plan.id;

  @override
  Future<void> deletePlan(String id) async {}

  @override
  Future<void> activatePlan(String planId, {required String voice, required String locale, required String speechRate}) async {}

  @override
  Future<TtsStatusInfo> getTtsStatus(String planId) async {
    throw PlanApiException('not implemented');
  }

  @override
  Future<List<AudioFileUrl>> getAudioUrls(String planId) async => [];
}

/// A [PlanApiService] wrapper that delegates [getLibraryPlanById] to a
/// [Completer] so tests can control when the future resolves.
class _SlowPlanApiService extends _FakePlanApiService {
  _SlowPlanApiService({
    required _FakePlanApiService delegate,
    required this.completer,
  }) {
    libraryPlans = delegate.libraryPlans;
  }

  final Completer<Plan> completer;

  @override
  Future<Plan> getLibraryPlanById(String id) => completer.future;
}

/// Minimal [PlanExecutionEngine] fake — records calls.
class _FakePlanExecutionEngine implements PlanExecutionEngine {
  Plan? startedPlan;
  bool pauseCalled = false;
  bool stopCalled = false;

  final _stateController = StreamController<ExecutionState>.broadcast();

  // Override to simulate an active session (non-null → triggers the guard).
  ExecutionState? _currentState;

  @override
  ExecutionState? get currentState => _currentState;

  void setRunningPlan(Plan plan) {
    _currentState = ExecutionState(
      plan: plan,
      currentStepIndex: 0,
      timeRemaining: const Duration(minutes: 5),
      status: ExecutionStatus.running,
    );
  }

  @override
  Future<void> startPlan(Plan plan) async => startedPlan = plan;

  @override
  Future<void> startPlanFromStep(Plan plan, int flatStepIndex) async =>
      startedPlan = plan;

  @override
  Future<void> pause() async => pauseCalled = true;

  @override
  Future<void> resume() async {}

  @override
  Future<void> skipForward() async {}

  @override
  Future<void> skipBackward() async {}

  @override
  Future<void> stop() async {
    stopCalled = true;
    _currentState = null;
  }

  @override
  Stream<ExecutionState> get stateStream => _stateController.stream;

  @override
  Future<ExecutionState?> getRecoverableSession([String? planId]) async => null;

  @override
  Future<int?> getRecoverableStepIndexForPlan(String planId) async => null;

  @override
  Future<bool> resumeFromPersistedState(String planId) async => false;

  @override
  Future<void> startPreview(Plan plan) async {}

  @override
  bool get isPreview => false;

  void dispose() => _stateController.close();
}

// ────────────────────────────────────────────────────────────────────────────
// Test helpers
// ────────────────────────────────────────────────────────────────────────────

Plan _makePlan({
  String id = '1',
  String name = 'Test Plan',
  PlanCategory category = PlanCategory.custom,
  Duration duration = const Duration(minutes: 5),
  DateTime? lastUsedAt,
}) {
  final now = DateTime.now();
  return Plan(
    id: id,
    name: name,
    category: category,
    steps: [],
    createdAt: now,
    updatedAt: now,
    lastUsedAt: lastUsedAt,
  );
}

/// Builds the test widget tree with GoRouter and provider overrides.
///
/// [isAuthenticated] controls the [isAuthenticatedProvider] value.
/// Defaults to `true` so the FAB is visible on My Plans tab.
///
/// [isOnline] controls the [isOnlineProvider] value; defaults to `true`
/// (online). Pass `false` to test the offline banner.
///
/// [apiService] when provided overrides [planApiServiceProvider] so tests
/// can return fake library plans without real HTTP calls.
///
/// [audioDownloadService] when provided overrides [audioDownloadServiceProvider]
/// so tests can record [downloadPlanAudio] calls without real HTTP/disk I/O.
///
/// [ttsStatusStreamFactory] when provided overrides [planTtsStatusProvider] for
/// all plan IDs, allowing tests to inject custom TTS status streams without
/// real network polling.
Widget _buildApp({
  required _FakePlanRepository repo,
  required _FakePlanExecutionEngine engine,
  _FakePlanApiService? apiService,
  _FakeAudioDownloadService? audioDownloadService,
  Stream<TtsStatusInfo> Function(String planId)? ttsStatusStreamFactory,
  bool isAuthenticated = true,
  bool isOnline = true,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const PlanLibraryScreen(),
      ),
      GoRoute(
        path: '/editor/new',
        builder: (_, __) => const Scaffold(body: Text('New Editor')),
      ),
      GoRoute(
        path: '/editor/:planId',
        builder: (_, __) => const Scaffold(body: Text('Editor')),
      ),
      GoRoute(
        path: '/now-playing',
        builder: (_, __) => const Scaffold(body: Text('Now Playing')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );

  // Build the overrides list.
  final fakeApiService = apiService ?? _FakePlanApiService();

  return ProviderScope(
    overrides: [
      planRepositoryProvider.overrideWithValue(repo),
      planExecutionEngineProvider.overrideWithValue(engine),
      planApiServiceProvider.overrideWithValue(fakeApiService),
      isAuthenticatedProvider.overrideWithValue(isAuthenticated),
      // Override connectivity so tests don't make real socket connections.
      isOnlineProvider.overrideWith(
        (ref) => Stream.value(isOnline),
      ),
      // Override library plans provider to avoid real HTTP calls.
      // The override respects fakeApiService.libraryPlans for Discover tests.
      libProviders.libraryPlansProvider.overrideWith(
        (ref) => fakeApiService.fetchLibraryPlans(),
      ),
      // Override audio download service when provided.
      if (audioDownloadService != null)
        audioDownloadServiceProvider.overrideWithValue(audioDownloadService),
      // Override TTS status polling provider when a factory is provided.
      if (ttsStatusStreamFactory != null)
        planTtsStatusProvider.overrideWith(
          (ref, planId) => ttsStatusStreamFactory(planId),
        ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakePlanRepository repo;
  late _FakePlanExecutionEngine engine;

  setUp(() {
    repo = _FakePlanRepository();
    engine = _FakePlanExecutionEngine();
  });

  tearDown(() {
    repo.dispose();
    engine.dispose();
  });

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('PlanLibraryScreen rendering', () {
    testWidgets('shows app bar with title "My Plans"', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.text('My Plans'), findsOneWidget);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows search bar', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows "All" category chip', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('shows a FilterChip for each PlanCategory', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      for (final category in PlanCategory.values) {
        expect(
          find.text(planCategoryLabel(category)),
          findsOneWidget,
          reason: 'Missing chip for $category',
        );
      }
    });

    testWidgets('shows FAB with add icon on My Plans tab', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await tester.pump();
      // _GradientFab renders with Semantics(label: 'New Plan') and Icon(Icons.add).
      expect(find.bySemanticsLabel('New Plan'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows empty state when no plans', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      // Emit an empty list from the stream.
      repo._emit();
      await tester.pumpAndSettle();
      expect(find.text('No plans yet'), findsOneWidget);
    });

    testWidgets('shows plan cards when plans are available', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Yoga Flow'));
      await repo.createPlan(_makePlan(id: '2', name: 'Morning Routine'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Morning Routine'), findsOneWidget);
    });

    testWidgets('shows loading spinner while waiting for plans', (tester) async {
      // Use a completer so the stream never emits, keeping the loading state.
      final completer = Completer<List<Plan>>();
      final delayedRepo = _FakePlanRepository();

      await tester.pumpWidget(_buildApp(repo: delayedRepo, engine: engine));
      // Before the stream emits, the AsyncValue is loading.
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
      delayedRepo.dispose();
    });
  });

  // ── FAB tab-conditional visibility ────────────────────────────────────────

  group('FAB tab visibility', () {
    testWidgets('FAB is visible on My Plans tab (index 0)', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      // Default tab is My Plans (index 0) — FAB must be present.
      expect(find.bySemanticsLabel('New Plan'), findsOneWidget);
    });

    testWidgets('FAB is hidden on Discover tab (index 1)', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      // Switch to the Discover tab.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // FAB must not be present on the Discover tab.
      expect(find.bySemanticsLabel('New Plan'), findsNothing);
    });

    testWidgets('FAB reappears when switching back to My Plans', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      // Navigate away to Discover.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('New Plan'), findsNothing);

      // Navigate back to My Plans.
      await tester.tap(find.text('My Plans'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('New Plan'), findsOneWidget);
    });

    testWidgets('FAB is hidden when unauthenticated on My Plans tab',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, isAuthenticated: false),
      );
      repo._emit();
      await tester.pumpAndSettle();

      // Even on My Plans, unauthenticated users see no FAB.
      expect(find.bySemanticsLabel('New Plan'), findsNothing);
    });
  });

  // ── PlanCard content ──────────────────────────────────────────────────────

  group('PlanCard displays correct content', () {
    testWidgets('shows plan name in bold', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Sunrise Yoga'));
      await tester.pumpAndSettle();

      // Name text should be visible.
      expect(find.text('Sunrise Yoga'), findsOneWidget);
    });

    testWidgets('shows category icon for yoga plan', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        name: 'Yoga Plan',
        category: PlanCategory.yoga,
      ));
      await tester.pumpAndSettle();

      // Yoga maps to Icons.self_improvement.
      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
    });

    testWidgets('shows "Never used" when lastUsedAt is null', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(lastUsedAt: null));
      await tester.pumpAndSettle();

      expect(find.textContaining('Never used'), findsOneWidget);
    });

    testWidgets('shows popup menu button', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan'));
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuButton<Object>), findsOneWidget);
    });
  });

  // ── Search ────────────────────────────────────────────────────────────────

  group('Search bar', () {
    testWidgets('filters plans by name in real-time', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: '1', name: 'Morning Yoga'));
      await repo.createPlan(_makePlan(id: '2', name: 'Deep Focus'));
      await tester.pumpAndSettle();

      // Both plans visible initially.
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);

      // Type in search bar.
      await tester.enterText(find.byType(TextField), 'yoga');
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsNothing);
    });

    testWidgets('shows clear button when query is non-empty', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears search when clear button tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: '1', name: 'Morning Yoga'));
      await repo.createPlan(_makePlan(id: '2', name: 'Deep Focus'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'yoga');
      await tester.pumpAndSettle();
      expect(find.text('Deep Focus'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });
  });

  // ── Category filter ───────────────────────────────────────────────────────

  group('CategoryFilter', () {
    testWidgets('filters by category when chip tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: '1',
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: '2',
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Scroll to the Yoga chip and tap it.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsNothing);
    });

    testWidgets('returns to all plans when All chip tapped', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: '1',
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: '2',
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Select Yoga filter.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();
      expect(find.text('Deep Focus'), findsNothing);

      // Tap All to reset.
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });

    testWidgets('deselects category chip when tapped again', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(
        id: '1',
        name: 'Yoga Flow',
        category: PlanCategory.yoga,
      ));
      await repo.createPlan(_makePlan(
        id: '2',
        name: 'Deep Focus',
        category: PlanCategory.focus,
      ));
      await tester.pumpAndSettle();

      // Select then deselect.
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoga'));
      await tester.pumpAndSettle();

      expect(find.text('Yoga Flow'), findsOneWidget);
      expect(find.text('Deep Focus'), findsOneWidget);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  group('Navigation', () {
    testWidgets('FAB navigates to new editor', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      // Tap the gradient FAB (identified by its semantics label).
      await tester.tap(find.bySemanticsLabel('New Plan'));
      await tester.pumpAndSettle();

      expect(find.text('New Editor'), findsOneWidget);
    });

    testWidgets('settings icon navigates to settings', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('Edit menu item navigates to editor with plan ID', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'My Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Editor'), findsOneWidget);
    });
  });

  // ── Duplicate ─────────────────────────────────────────────────────────────

  group('Duplicate plan', () {
    testWidgets('creates a copy with "(copy)" suffix', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Morning Yoga'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga (copy)'), findsOneWidget);
    });

    testWidgets('shows snackbar after duplicate', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan A'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(find.textContaining('duplicated'), findsOneWidget);
    });
  });

  // ── Delete ────────────────────────────────────────────────────────────────

  group('Delete plan', () {
    testWidgets('shows confirmation dialog before deleting', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan to Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Plan'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('removes plan when confirmed', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Gone Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion.
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(find.text('Gone Plan'), findsNothing);
      expect(find.textContaining('deleted'), findsOneWidget);
    });

    testWidgets('keeps plan when cancelled', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Kept Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<Object>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Kept Plan'), findsOneWidget);
    });
  });

  // ── Countdown overlay ─────────────────────────────────────────────────────

  group('Countdown overlay', () {
    testWidgets('tapping plan card shows countdown overlay', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Run This'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run This'));
      // Pump to show the overlay (don't settle — countdown is running).
      await tester.pump();

      // The overlay shows the first count (3).
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Cancel button dismisses overlay without starting', (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Yoga'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yoga'));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // No navigation — still on library screen.
      expect(find.text('My Plans'), findsOneWidget);
      expect(engine.startedPlan, isNull);
    });
  });

  // ── Active session guard ──────────────────────────────────────────────────

  group('Active session guard', () {
    testWidgets(
        'shows confirmation dialog when another plan is running and user taps a card',
        (tester) async {
      // Set up Plan 1 as the currently running plan.
      final plan1 = _makePlan(id: '1', name: 'Plan One');
      engine.setRunningPlan(plan1);

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      // Add Plan 2 to the library.
      await repo.createPlan(_makePlan(id: '2', name: 'Plan Two'));
      await tester.pumpAndSettle();

      // Tap Plan Two's play button.
      await tester.tap(find.text('Plan Two'));
      await tester.pumpAndSettle();

      // Active session dialog should appear.
      expect(find.text('Session already running'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets(
        'Cancel keeps the active session — engine.stop() not called and plan not started',
        (tester) async {
      final plan1 = _makePlan(id: '1', name: 'Active Plan');
      engine.setRunningPlan(plan1);

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: '2', name: 'New Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Plan'));
      await tester.pumpAndSettle();

      expect(find.text('Session already running'), findsOneWidget);

      // Tap Cancel.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // stop() should NOT have been called.
      expect(engine.stopCalled, isFalse);
      // startPlan should NOT have been called.
      expect(engine.startedPlan, isNull);
      // Still on library screen.
      expect(find.text('Plan Library'), findsOneWidget);
    });

    testWidgets(
        'Start stops active session and begins countdown for new plan',
        (tester) async {
      final plan1 = _makePlan(id: '1', name: 'Running Plan');
      engine.setRunningPlan(plan1);

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(id: '2', name: 'Incoming Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Incoming Plan'));
      await tester.pumpAndSettle();

      expect(find.text('Session already running'), findsOneWidget);

      // Tap Start to confirm.
      await tester.tap(find.text('Start'));
      // pump() — guard calls engine.stop() then shows the countdown overlay.
      await tester.pump();

      // engine.stop() must have been called.
      expect(engine.stopCalled, isTrue);

      // Countdown overlay should appear (shows '3').
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no dialog when no session is active', (tester) async {
      // engine has no active session (currentState is null, default).
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Solo Plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Solo Plan'));
      // Pump once — should go straight to countdown.
      await tester.pump();

      // No session dialog.
      expect(find.text('Session already running'), findsNothing);
      // Countdown overlay is visible.
      expect(find.text('3'), findsOneWidget);
    });
  });

  // ── Pull-to-refresh ───────────────────────────────────────────────────────

  group('Pull-to-refresh', () {
    testWidgets('pull-to-refresh on non-empty list calls refreshFromServer',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Morning Yoga'));
      await tester.pumpAndSettle();

      expect(repo.refreshCallCount, 0);

      // Fling the ListView downward (overscroll) to trigger the refresh.
      await tester.fling(
        find.byType(ListView),
        const Offset(0, 400),
        800,
      );
      // Let the RefreshIndicator animate and the onRefresh Future complete.
      await tester.pump(); // frame after fling
      await tester.pump(const Duration(seconds: 1)); // wait for indicator
      await tester.pumpAndSettle();

      expect(repo.refreshCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets('pull-to-refresh on empty list calls refreshFromServer',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      repo._emit(); // emit empty list
      await tester.pumpAndSettle();

      // The empty state is inside a CustomScrollView.
      expect(find.text('No plans yet'), findsOneWidget);
      expect(repo.refreshCallCount, 0);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        800,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.refreshCallCount, greaterThanOrEqualTo(1));
    });

    testWidgets(
        'network error (SocketException) shows friendly offline snackbar',
        (tester) async {
      repo.simulateRefreshError(
        SocketException('Failed host lookup: api.example.com'),
      );

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan A'));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 400),
        800,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No internet connection'),
        findsOneWidget,
      );
    });

    testWidgets('cached plans remain visible after network error',
        (tester) async {
      repo.simulateRefreshError(
        SocketException('Failed host lookup: api.example.com'),
      );

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Cached Plan'));
      await tester.pumpAndSettle();

      // Verify plan is visible before refresh.
      expect(find.text('Cached Plan'), findsOneWidget);

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 400),
        800,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Snackbar shown, but cached plan is still visible.
      expect(find.textContaining('No internet connection'), findsOneWidget);
      expect(find.text('Cached Plan'), findsOneWidget);
    });

    testWidgets('generic (non-network) error does not show raw exception text',
        (tester) async {
      // Simulate a non-network failure (e.g. server 500).
      repo.simulateRefreshError(Exception('Internal server error at line 42'));

      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      await repo.createPlan(_makePlan(name: 'Plan A'));
      await tester.pumpAndSettle();

      await tester.fling(
        find.byType(ListView),
        const Offset(0, 400),
        800,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should show friendly message, not raw exception text.
      expect(find.textContaining('Could not refresh plans'), findsOneWidget);
      expect(
        find.textContaining('Internal server error at line 42'),
        findsNothing,
      );
    });
  });

  // ── Offline banner ────────────────────────────────────────────────────────

  group('Offline banner', () {
    testWidgets('offline banner is hidden when online', (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, isOnline: true),
      );
      repo._emit();
      await tester.pumpAndSettle();

      expect(find.text('Showing cached plans'), findsNothing);
    });

    testWidgets('offline banner shows "Showing cached plans" when offline',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, isOnline: false),
      );
      repo._emit();
      await tester.pumpAndSettle();

      expect(find.text('Showing cached plans'), findsOneWidget);
    });

    testWidgets('offline banner is on My Plans tab not Discover tab',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, isOnline: false),
      );
      repo._emit();
      await tester.pumpAndSettle();

      // On My Plans tab: banner should be present.
      expect(find.text('Showing cached plans'), findsOneWidget);

      // Switch to Discover tab.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // The Discover tab's offline banner is not rendered by _MyPlansTab.
      // Verify the My Plans offline banner text is no longer visible.
      expect(find.text('Showing cached plans'), findsNothing);
    });
  });

  // ── TTS badges ────────────────────────────────────────────────────────────

  group('TTS status badges', () {
    Plan _makePlanWithTts({
      required String ttsStatus,
      int ttsCompleted = 0,
      int ttsTotal = 0,
    }) {
      final now = DateTime.now();
      return Plan(
        id: 'tts-plan',
        name: 'AI Plan',
        category: PlanCategory.custom,
        steps: [],
        createdAt: now,
        updatedAt: now,
        isActive: true,
        ttsStatus: ttsStatus,
        ttsCompleted: ttsCompleted,
        ttsTotal: ttsTotal,
      );
    }

    testWidgets('TTS badge is NOT shown for ttsStatus == "none"',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      final plan = _makePlanWithTts(ttsStatus: 'none');
      await repo.createPlan(plan);
      await tester.pumpAndSettle();

      // TtsStatusBadge should not be present when status is 'none'.
      expect(find.byType(TtsStatusBadge), findsNothing);
    });

    testWidgets('TTS badge IS shown for ttsStatus == "pending"',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      final plan = _makePlanWithTts(ttsStatus: 'pending');
      await repo.createPlan(plan);
      await tester.pumpAndSettle();

      expect(find.byType(TtsStatusBadge), findsOneWidget);
    });

    testWidgets('TTS badge IS shown for ttsStatus == "completed"',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      final plan = _makePlanWithTts(
        ttsStatus: 'completed',
        ttsCompleted: 5,
        ttsTotal: 5,
      );
      await repo.createPlan(plan);
      await tester.pumpAndSettle();

      expect(find.byType(TtsStatusBadge), findsOneWidget);
    });

    testWidgets('TTS badge IS shown for ttsStatus == "partial"',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: repo, engine: engine));
      final plan = _makePlanWithTts(
        ttsStatus: 'partial',
        ttsCompleted: 3,
        ttsTotal: 5,
      );
      await repo.createPlan(plan);
      await tester.pumpAndSettle();

      expect(find.byType(TtsStatusBadge), findsOneWidget);
    });
  });

  // ── Helper function tests ──────────────────────────────────────────────────

  group('formatRelativeTime', () {
    test('returns "Never used" for null', () {
      expect(formatRelativeTime(null), 'Never used');
    });

    test('returns "Just now" for less than 60 seconds', () {
      final now = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(now), 'Just now');
    });

    test('returns minutes ago', () {
      final dt = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(dt), '5 mins ago');
    });

    test('returns hours ago', () {
      final dt = DateTime.now().subtract(const Duration(hours: 2));
      expect(formatRelativeTime(dt), '2 hours ago');
    });

    test('returns days ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 3));
      expect(formatRelativeTime(dt), '3 days ago');
    });

    test('returns "Yesterday" for 1 day ago', () {
      final dt = DateTime.now().subtract(const Duration(days: 1));
      expect(formatRelativeTime(dt), 'Yesterday');
    });
  });

  group('formatPlanDuration', () {
    test('formats seconds only', () {
      expect(formatPlanDuration(const Duration(seconds: 45)), '45s');
    });

    test('formats minutes only', () {
      expect(formatPlanDuration(const Duration(minutes: 10)), '10m');
    });

    test('formats minutes and seconds', () {
      expect(
        formatPlanDuration(const Duration(minutes: 5, seconds: 30)),
        '5m 30s',
      );
    });

    test('formats hours and minutes', () {
      expect(
        formatPlanDuration(const Duration(hours: 1, minutes: 15)),
        '1h 15m',
      );
    });

    test('formats hours only', () {
      expect(formatPlanDuration(const Duration(hours: 2)), '2h');
    });
  });

  group('planCategoryIcon', () {
    test('returns different icons for each category', () {
      final icons = PlanCategory.values.map(planCategoryIcon).toSet();
      // Each category should have a unique icon.
      expect(icons.length, PlanCategory.values.length);
    });
  });

  group('planCategoryLabel', () {
    test('returns non-empty label for every category', () {
      for (final category in PlanCategory.values) {
        expect(planCategoryLabel(category), isNotEmpty);
      }
    });
  });

  // ── Discover tab ──────────────────────────────────────────────────────────

  group('Discover tab', () {
    late _FakePlanApiService apiService;

    setUp(() {
      apiService = _FakePlanApiService();
    });

    LibraryPlanSummary _makeLibrarySummary({
      String id = 'lib-1',
      String name = 'Library Plan',
      PlanCategory category = PlanCategory.yoga,
      String? description,
      int stepCount = 5,
    }) {
      final now = DateTime.now();
      _ = now; // suppress unused warning
      return LibraryPlanSummary(
        id: id,
        name: name,
        category: category,
        description: description,
        stepCount: stepCount,
      );
    }

    Plan _makeFullPlan({
      String id = 'lib-1',
      String name = 'Library Plan',
    }) {
      final now = DateTime.now();
      return Plan(
        id: id,
        name: name,
        steps: [],
        createdAt: now,
        updatedAt: now,
      );
    }

    testWidgets('shows "Discover" heading when on Discover tab', (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsWidgets);
    });

    testWidgets('shows library plan cards on Discover tab', (tester) async {
      apiService.libraryPlans = [
        _makeLibrarySummary(id: 'lib-1', name: 'Morning Yoga'),
        _makeLibrarySummary(id: 'lib-2', name: 'Evening Flow'),
      ];

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Evening Flow'), findsOneWidget);
    });

    testWidgets('shows "Add to My Plans" button on each library card',
        (tester) async {
      apiService.libraryPlans = [
        _makeLibrarySummary(id: 'lib-1', name: 'Yoga Flow'),
      ];

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Add to My Plans'), findsOneWidget);
    });

    testWidgets(
        'tapping "Add to My Plans" fetches full plan, saves, and navigates to My Plans tab',
        (tester) async {
      final summary = _makeLibrarySummary(id: 'lib-1', name: 'Power Hour');
      final fullPlan = _makeFullPlan(id: 'lib-1', name: 'Power Hour');
      apiService.libraryPlans = [summary];
      apiService.addLibraryPlanDetail(fullPlan);

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      // Switch to Discover tab.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // Tap the "Add to My Plans" button.
      await tester.tap(find.text('Add to My Plans'));
      await tester.pumpAndSettle();

      // Should have navigated back to My Plans tab (FAB is visible again).
      expect(find.bySemanticsLabel('New Plan'), findsOneWidget);

      // The plan should now be in the repo.
      expect(repo._plans.isNotEmpty, isTrue);
    });

    testWidgets('shows "Added to My Plans" after successful add', (tester) async {
      final summary = _makeLibrarySummary(id: 'lib-1', name: 'Focus Block');
      final fullPlan = _makeFullPlan(id: 'lib-1', name: 'Focus Block');
      apiService.libraryPlans = [summary];
      apiService.addLibraryPlanDetail(fullPlan);

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to My Plans'));
      await tester.pumpAndSettle();

      // Navigate back to Discover to verify the button state.
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Added to My Plans'), findsOneWidget);
      expect(find.text('Add to My Plans'), findsNothing);
    });

    testWidgets('shows error snackbar when add fails', (tester) async {
      final summary = _makeLibrarySummary(id: 'lib-1', name: 'Broken Plan');
      apiService.libraryPlans = [summary];
      apiService.getLibraryPlanByIdError =
          const PlanApiException('Network error', userMessage: 'Network error');

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to My Plans'));
      await tester.pumpAndSettle();

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('search bar filters library plans', (tester) async {
      apiService.libraryPlans = [
        _makeLibrarySummary(id: 'lib-1', name: 'Morning Yoga'),
        _makeLibrarySummary(id: 'lib-2', name: 'Deep Focus'),
      ];

      // Override library plans provider to respect search query changes.
      final container = ProviderContainer(
        overrides: [
          planApiServiceProvider.overrideWithValue(apiService),
          libProviders.libraryPlansProvider.overrideWith(
            (ref) {
              final search = ref.watch(libProviders.searchQueryProvider);
              final category = ref.watch(libProviders.selectedCategoryProvider);
              return apiService.fetchLibraryPlans(
                search: search.isEmpty ? null : search,
                category: category,
              );
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      // Use _buildApp but rebuild with a custom ProviderScope that supports
      // reactive search. For this test, verify the provider behaviour directly.
      expect(
        await container.read(libProviders.libraryPlansProvider.future),
        hasLength(2),
      );

      container.read(libProviders.searchQueryProvider.notifier).state = 'yoga';
      expect(
        await container.read(libProviders.libraryPlansProvider.future),
        hasLength(1),
      );
    });

    testWidgets('category filter chips are shown on Discover tab',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // "All" chip should be visible.
      expect(find.text('All'), findsWidgets);
    });

    testWidgets('shows empty state when no library plans match', (tester) async {
      // Empty library plans list.
      apiService.libraryPlans = [];

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: apiService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('No plans found'), findsOneWidget);
    });

    testWidgets('offline banner shown on Discover tab when offline',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          repo: repo,
          engine: engine,
          apiService: apiService,
          isOnline: false,
        ),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      expect(find.text('Discover requires internet'), findsOneWidget);
    });

    testWidgets('"Add to My Plans" button is disabled while loading',
        (tester) async {
      // Use a completer to control when getLibraryPlanById resolves.
      final completer = Completer<Plan>();
      final slowApiService = _FakePlanApiService();
      slowApiService.libraryPlans = [
        _makeLibrarySummary(id: 'lib-1', name: 'Slow Plan'),
      ];
      // Override getLibraryPlanById to use the completer.
      final overriddenService = _SlowPlanApiService(
        delegate: slowApiService,
        completer: completer,
      );

      await tester.pumpWidget(
        _buildApp(repo: repo, engine: engine, apiService: overriddenService),
      );
      repo._emit();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();

      // Tap "Add to My Plans" — triggers loading.
      await tester.tap(find.text('Add to My Plans'));
      await tester.pump(); // single frame to show loading state

      // Button should now show "Adding…" (loading state).
      expect(find.text('Adding…'), findsOneWidget);

      // Complete the future so we don't leak.
      final now = DateTime.now();
      completer.complete(
        Plan(
          id: 'lib-1',
          name: 'Slow Plan',
          steps: [],
          createdAt: now,
          updatedAt: now,
        ),
      );
      await tester.pumpAndSettle();
    });
  });

  // ── TTS auto-download effect (TASK-035) ────────────────────────────────────

  group('_TtsAutoDownloadEffect', () {
    late _FakeAudioDownloadService audioService;

    setUp(() {
      audioService = _FakeAudioDownloadService();
    });

    tearDown(() {
      audioService.dispose();
    });

    /// Creates a Plan with [isActive] = true and the given [ttsStatus].
    Plan _makeActivePlan({
      String id = 'plan-active-1',
      String ttsStatus = 'processing',
      int ttsTotal = 3,
      int ttsCompleted = 0,
    }) {
      final now = DateTime.now();
      return Plan(
        id: id,
        name: 'Active Plan',
        steps: [],
        createdAt: now,
        updatedAt: now,
        isActive: true,
        ttsStatus: ttsStatus,
        ttsTotal: ttsTotal,
        ttsCompleted: ttsCompleted,
      );
    }

    testWidgets(
        'triggers downloadPlanAudio when TTS status reaches "completed"',
        (tester) async {
      const planId = 'plan-1';

      // Create an active plan so _TtsAutoDownloadEffect is rendered.
      final activePlan = _makeActivePlan(id: planId, ttsStatus: 'processing');

      // TTS stream emits 'completed' immediately.
      Stream<TtsStatusInfo> ttsFactory(String id) => Stream.value(
            TtsStatusInfo(
                planId: id, status: 'completed', total: 3, completed: 3),
          );

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      // Add the active plan to trigger effect widget rendering.
      await repo.createPlan(activePlan);
      await tester.pumpAndSettle();

      // Effect should have triggered exactly one download for this plan.
      expect(audioService.downloadCalls, equals([planId]));
    });

    testWidgets(
        'triggers downloadPlanAudio when TTS status reaches "partial"',
        (tester) async {
      const planId = 'plan-2';
      final activePlan = _makeActivePlan(id: planId, ttsStatus: 'processing');

      Stream<TtsStatusInfo> ttsFactory(String id) => Stream.value(
            TtsStatusInfo(
                planId: id, status: 'partial', total: 5, completed: 3),
          );

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      await repo.createPlan(activePlan);
      await tester.pumpAndSettle();

      expect(audioService.downloadCalls, equals([planId]));
    });

    testWidgets('does not trigger download for non-terminal status',
        (tester) async {
      const planId = 'plan-3';
      final activePlan = _makeActivePlan(id: planId, ttsStatus: 'processing');

      // Stream only emits non-terminal statuses.
      Stream<TtsStatusInfo> ttsFactory(String id) => Stream.fromIterable([
            TtsStatusInfo(
                planId: id, status: 'pending', total: 3, completed: 0),
            TtsStatusInfo(
                planId: id, status: 'processing', total: 3, completed: 1),
          ]);

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      await repo.createPlan(activePlan);
      await tester.pumpAndSettle();

      // No terminal status received — no download triggered.
      expect(audioService.downloadCalls, isEmpty);
    });

    testWidgets('does not double-trigger for same terminal event on rebuild',
        (tester) async {
      const planId = 'plan-4';
      final activePlan = _makeActivePlan(id: planId, ttsStatus: 'processing');

      // Stream emits 'completed' twice (e.g. hot restart scenario).
      Stream<TtsStatusInfo> ttsFactory(String id) => Stream.fromIterable([
            TtsStatusInfo(
                planId: id, status: 'completed', total: 3, completed: 3),
            TtsStatusInfo(
                planId: id, status: 'completed', total: 3, completed: 3),
          ]);

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      await repo.createPlan(activePlan);
      await tester.pumpAndSettle();

      // Only one download triggered despite two 'completed' events.
      expect(audioService.downloadCalls, hasLength(1));
      expect(audioService.downloadCalls, equals([planId]));
    });

    testWidgets('does not trigger for non-active plans', (tester) async {
      // Non-active plan — isActive == false.
      final now = DateTime.now();
      final nonActivePlan = Plan(
        id: 'plan-inactive',
        name: 'Non Active Plan',
        steps: [],
        createdAt: now,
        updatedAt: now,
        isActive: false,
        ttsStatus: 'none',
      );

      Stream<TtsStatusInfo> ttsFactory(String id) => Stream.value(
            TtsStatusInfo(
                planId: id, status: 'completed', total: 3, completed: 3),
          );

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      await repo.createPlan(nonActivePlan);
      await tester.pumpAndSettle();

      // No _TtsAutoDownloadEffect rendered for non-active plan.
      expect(audioService.downloadCalls, isEmpty);
    });

    testWidgets('resets flag and can retry after download failure',
        (tester) async {
      const planId = 'plan-5';
      final activePlan = _makeActivePlan(id: planId, ttsStatus: 'processing');

      // First 'completed' event causes a download failure.
      // Second 'completed' event (from a new stream subscription) should retry.
      int callCount = 0;
      final streamController =
          StreamController<TtsStatusInfo>.broadcast();

      // Override downloadPlanAudio to fail on first call.
      audioService.nextError =
          AudioDownloadException('Simulated network error');

      Stream<TtsStatusInfo> ttsFactory(String id) => streamController.stream;

      await tester.pumpWidget(_buildApp(
        repo: repo,
        engine: engine,
        audioDownloadService: audioService,
        ttsStatusStreamFactory: ttsFactory,
      ));

      await repo.createPlan(activePlan);
      await tester.pumpAndSettle();

      // Emit first terminal status — download fails.
      streamController.add(
        TtsStatusInfo(planId: planId, status: 'completed', total: 3, completed: 3),
      );
      await tester.pumpAndSettle();

      // One failed attempt recorded.
      expect(audioService.downloadCalls, hasLength(1));
      expect(audioService.downloadCalls.first, equals(planId));

      // After failure, _downloadTriggered is reset — a second emit can retry.
      audioService.downloadCalls.clear(); // clear for next assertion
      streamController.add(
        TtsStatusInfo(planId: planId, status: 'completed', total: 3, completed: 3),
      );
      await tester.pumpAndSettle();

      // Retry download triggered (no error this time).
      expect(audioService.downloadCalls, equals([planId]));

      await streamController.close();
    });
  });
}
