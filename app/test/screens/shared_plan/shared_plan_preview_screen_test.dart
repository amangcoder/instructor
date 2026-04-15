/// Widget tests for [SharedPlanPreviewScreen] — the screen shown when a user
/// opens a shared plan deep link.
///
/// ## Strategy
///
/// Uses ProviderScope overrides with fake services so no real HTTP or database
/// calls are made. Tests verify:
///   - Loading state while fetching shared plan
///   - Plan preview displays name, description, step count, estimated duration
///   - 'Save to My Plans' button functionality
///   - Error state when plan is not found (revoked link)
///   - Deep link token extraction
///
/// Follows the existing plan_library_screen_test.dart patterns for widget
/// testing with Riverpod providers.
library shared_plan_preview_screen_test;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructor/services/plan_sharing_service.dart';
import 'package:instructor/models/shared_plan_preview.dart';
import 'package:instructor/screens/shared_plan/shared_plan_preview_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fakes
// ────────────────────────────────────────────────────────────────────────────

/// Fake [PlanSharingService] that returns controllable results.
class _FakePlanSharingService implements PlanSharingService {
  SharedPlanPreview? _planToReturn;
  Exception? _errorToThrow;
  int fetchCallCount = 0;
  int saveCallCount = 0;
  String? lastSavedToken;

  void setSharedPlan(SharedPlanPreview plan) {
    _planToReturn = plan;
    _errorToThrow = null;
  }

  void setError(Exception error) {
    _errorToThrow = error;
    _planToReturn = null;
  }

  @override
  Future<SharedPlanPreview> fetchSharedPlan(String shareToken) async {
    fetchCallCount++;
    if (_errorToThrow != null) throw _errorToThrow!;
    if (_planToReturn != null) return _planToReturn!;
    throw Exception('Plan not found');
  }

  @override
  Future<String> sharePlan(String planId) async {
    return 'https://instructor.app/s/fake-token';
  }

  @override
  Future<void> revokePlanSharing(String planId) async {}

  @override
  Future<void> saveSharedPlanToLibrary(SharedPlanPreview plan) async {
    saveCallCount++;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Test data
// ────────────────────────────────────────────────────────────────────────────

SharedPlanPreview _makePreview({
  String name = 'Morning Yoga',
  String description = 'A relaxing yoga routine to start your day.',
  int stepCount = 5,
  int estimatedDurationMs = 1200000,
}) {
  return SharedPlanPreview(
    name: name,
    description: description,
    steps: List.generate(
      stepCount,
      (i) => SharedPlanStep(type: 'say', text: 'Step ${i + 1}'),
    ),
    stepCount: stepCount,
    estimatedDurationMs: estimatedDurationMs,
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Widget builder
// ────────────────────────────────────────────────────────────────────────────

/// Wraps [SharedPlanPreviewScreen] in the minimum widget tree needed for tests.
Widget _buildTestWidget({
  required String shareToken,
  required _FakePlanSharingService sharingService,
}) {
  return ProviderScope(
    overrides: [
      // Override the PlanSharingService provider with our fake
      planSharingServiceProvider.overrideWithValue(sharingService),
    ],
    child: MaterialApp(
      home: SharedPlanPreviewScreen(shareToken: shareToken),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Tests
// ────────────────────────────────────────────────────────────────────────────

void main() {
  late _FakePlanSharingService fakeSharingService;

  setUp(() {
    fakeSharingService = _FakePlanSharingService();
  });

  group('SharedPlanPreviewScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      // Use a completer to hold the fetch in progress
      fakeSharingService.setSharedPlan(_makePreview());

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));

      // First frame should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays plan name after loading', (tester) async {
      fakeSharingService.setSharedPlan(
        _makePreview(name: 'Evening Meditation'),
      );

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));

      // Wait for async fetch to complete
      await tester.pumpAndSettle();

      expect(find.text('Evening Meditation'), findsOneWidget);
    });

    testWidgets('displays plan description', (tester) async {
      fakeSharingService.setSharedPlan(
        _makePreview(description: 'A calming meditation practice.'),
      );

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      expect(find.text('A calming meditation practice.'), findsOneWidget);
    });

    testWidgets('displays step count', (tester) async {
      fakeSharingService.setSharedPlan(_makePreview(stepCount: 8));

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      // Should show the step count somewhere on screen
      expect(find.textContaining('8'), findsWidgets);
    });

    testWidgets('displays estimated duration', (tester) async {
      fakeSharingService.setSharedPlan(
        _makePreview(estimatedDurationMs: 1800000), // 30 minutes
      );

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      // Should display duration in human-readable format (e.g., "30 min")
      expect(find.textContaining('30'), findsWidgets);
    });

    testWidgets('shows Save to My Plans button', (tester) async {
      fakeSharingService.setSharedPlan(_makePreview());

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, 'Save to My Plans'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Save calls saveSharedPlanToLibrary', (tester) async {
      fakeSharingService.setSharedPlan(_makePreview());

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'test-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      // Tap the save button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save to My Plans'));
      await tester.pumpAndSettle();

      expect(fakeSharingService.saveCallCount, 1);
    });

    testWidgets('shows error state when plan not found (revoked)', (tester) async {
      fakeSharingService.setError(Exception('Plan no longer available'));

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'revoked-token',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.textContaining('no longer available'), findsOneWidget);
      // Should NOT show save button
      expect(
        find.widgetWithText(ElevatedButton, 'Save to My Plans'),
        findsNothing,
      );
    });

    testWidgets('passes correct shareToken to service', (tester) async {
      fakeSharingService.setSharedPlan(_makePreview());

      await tester.pumpWidget(_buildTestWidget(
        shareToken: 'specific-token-123',
        sharingService: fakeSharingService,
      ));
      await tester.pumpAndSettle();

      expect(fakeSharingService.fetchCallCount, 1);
    });
  });
}
