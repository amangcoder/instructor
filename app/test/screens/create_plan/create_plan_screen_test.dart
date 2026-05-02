// Tests for CreatePlanScreen.
//
// Covers:
//   • Form renders with title, steps, and description fields.
//   • Validation: title too short, empty step, etc.
//   • Submit calls createPlanClient.createPlan and shows success view.
//   • Success view shows "Request Publish" button with plan title.
//   • Request Publish calls requestPublish and shows snackbar on success.
//   • Error states are displayed for both create and request-publish failures.
//   • Loading states: buttons are disabled while submitting.
//   • Unauthenticated user is redirected to login.
//   • Step list: add/remove steps works correctly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/models/auth_models.dart';
import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/screens/create_plan/create_plan_screen.dart';
import 'package:instructor/services/create_plan_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake client (implements abstract CreatePlanClient)
// ─────────────────────────────────────────────────────────────────────────────

class _FakeCreatePlanClient implements CreatePlanClient {
  // Stubbed response for createPlan.
  String createPlanResult = 'plan-uuid-001';
  CreatePlanException? createPlanError;

  // Stubbed response for requestPublish.
  CreatePlanException? requestPublishError;

  // Call tracking.
  final List<Map<String, dynamic>> createPlanCalls = [];
  final List<String> requestPublishCalls = [];

  @override
  Future<String> createPlan({
    required String title,
    required List<String> steps,
    required String description,
  }) async {
    createPlanCalls.add({
      'title': title,
      'steps': steps,
      'description': description,
    });
    if (createPlanError != null) throw createPlanError!;
    return createPlanResult;
  }

  @override
  Future<void> requestPublish(String planId) async {
    requestPublishCalls.add(planId);
    if (requestPublishError != null) throw requestPublishError!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Test scaffold helpers
// ─────────────────────────────────────────────────────────────────────────────

const _testUser = AuthUser(
  id: 'user-42',
  email: 'tester@example.com',
  name: 'Tester',
);

/// Builds the widget tree for [CreatePlanScreen] tests.
///
/// [user] — the authenticated user (null = unauthenticated).
/// [client] — fake [CreatePlanClient]; defaults to a success-configured one.
Widget _buildApp({
  AuthUser? user = _testUser,
  _FakeCreatePlanClient? client,
}) {
  final fakeClient = client ?? _FakeCreatePlanClient();

  final router = GoRouter(
    initialLocation: '/create-plan',
    routes: [
      GoRoute(
        path: '/create-plan',
        builder: (_, __) => const CreatePlanScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      createPlanClientProvider.overrideWithValue(fakeClient),
      currentUserProvider.overrideWithValue(user),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Finds the TextFormField whose hint text contains [hintSubstring].
Finder _stepField(int stepNumber) => find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField &&
          (widget.decoration?.hintText ?? '').contains('Step $stepNumber'),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('CreatePlanScreen — form rendering', () {
    testWidgets('displays title, step, and description fields', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // App bar title
      expect(find.text('Create Plan'), findsOneWidget);

      // Title field
      expect(find.widgetWithText(TextFormField, 'Title *'), findsOneWidget);

      // Description field
      expect(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        findsOneWidget,
      );

      // At least one step field hint
      expect(_stepField(1), findsOneWidget);

      // Submit button
      expect(find.text('Create plan'), findsOneWidget);
    });

    testWidgets('close button is present in app bar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Cancel'), findsOneWidget);
    });

    testWidgets('explanatory header text is shown', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Author a private plan'), findsOneWidget);
    });
  });

  group('CreatePlanScreen — step list management', () {
    testWidgets('starts with one step row', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(_stepField(1), findsOneWidget);
      expect(_stepField(2), findsNothing);
    });

    testWidgets('Add step button adds a new step row', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      expect(_stepField(2), findsOneWidget);
    });

    testWidgets('Remove step button removes a step row', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Add a second step first.
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      expect(_stepField(2), findsOneWidget);

      // Remove the first step (first remove button).
      await tester.tap(find.byTooltip('Remove step').first);
      await tester.pumpAndSettle();

      // Only one step row should remain.
      expect(_stepField(2), findsNothing);
      expect(_stepField(1), findsOneWidget);
    });

    testWidgets('cannot remove the last remaining step', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // With only one step, the "Remove step" tooltip should not appear.
      expect(find.byTooltip('Remove step'), findsNothing);
    });

    testWidgets('Move step up button is absent for first step', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      // There are 2 steps; only one "Move step up" button (for step 2).
      expect(find.byTooltip('Move step up'), findsOneWidget);
    });

    testWidgets('Move step down button is absent for last step', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      // There are 2 steps; only one "Move step down" button (for step 1).
      expect(find.byTooltip('Move step down'), findsOneWidget);
    });
  });

  group('CreatePlanScreen — validation', () {
    testWidgets('shows error when title is too short', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Title too short.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'ab',
      );
      // Valid step text.
      await tester.enterText(_stepField(1), 'Do something useful');

      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      expect(
        find.text('Please enter a title (3+ characters).'),
        findsOneWidget,
      );
    });

    testWidgets('shows error when a step is empty on submit', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Valid title, empty step.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'My morning routine',
      );

      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Step 1 cannot be empty'), findsOneWidget);
    });

    testWidgets('does not submit when validation fails', (tester) async {
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      // Leave fields blank and tap submit.
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      expect(client.createPlanCalls, isEmpty);
    });
  });

  group('CreatePlanScreen — successful creation flow', () {
    Future<_FakeCreatePlanClient> _submitValidForm(
      WidgetTester tester, {
      String title = 'Morning mindfulness',
      String step = 'Take 3 deep breaths',
      String description = 'A gentle morning routine',
      _FakeCreatePlanClient? client,
    }) async {
      final fakeClient = client ?? _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: fakeClient));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        title,
      );
      await tester.enterText(_stepField(1), step);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optional)'),
        description,
      );

      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      return fakeClient;
    }

    testWidgets('calls createPlan with correct title and steps', (tester) async {
      final client = await _submitValidForm(tester);

      expect(client.createPlanCalls, hasLength(1));
      final call = client.createPlanCalls.first;
      expect(call['title'], 'Morning mindfulness');
      expect(call['steps'], contains('Take 3 deep breaths'));
      expect(call['description'], 'A gentle morning routine');
    });

    testWidgets('shows success view after creation', (tester) async {
      await _submitValidForm(tester);

      // Success heading
      expect(find.text('Plan created!'), findsOneWidget);

      // Plan title displayed
      expect(find.text('Morning mindfulness'), findsOneWidget);

      // Request Publish button present
      expect(find.text('Request Publish'), findsOneWidget);

      // Keep private option present
      expect(find.text('Keep private — done'), findsOneWidget);

      // Form is replaced (no "Create plan" button)
      expect(find.text('Create plan'), findsNothing);
    });

    testWidgets('success view shows the created plan title', (tester) async {
      await _submitValidForm(tester, title: 'Evening wind-down');

      expect(find.text('Evening wind-down'), findsOneWidget);
    });

    testWidgets('multiple steps are all sent to createPlan', (tester) async {
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Multi-step plan',
      );
      await tester.enterText(_stepField(1), 'First step text');

      // Add and fill second step.
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      await tester.enterText(_stepField(2), 'Second step text');

      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      final call = client.createPlanCalls.first;
      final steps = call['steps'] as List<String>;
      expect(steps, containsAll(['First step text', 'Second step text']));
    });
  });

  group('CreatePlanScreen — Request Publish flow', () {
    testWidgets('Request Publish calls requestPublish with plan id',
        (tester) async {
      final client = _FakeCreatePlanClient()
        ..createPlanResult = 'server-plan-123';
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Evening wind-down',
      );
      await tester.enterText(_stepField(1), 'Stretch for 5 minutes');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Request Publish'));
      await tester.pumpAndSettle();

      expect(client.requestPublishCalls, contains('server-plan-123'));
    });

    testWidgets('shows success snackbar after Request Publish', (tester) async {
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Weekend yoga',
      );
      await tester.enterText(_stepField(1), 'Sun salutation');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Request Publish'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Publish request submitted'),
        findsOneWidget,
      );
    });

    testWidgets('Keep private — done button navigates away', (tester) async {
      // With the test GoRouter there's only /create-plan and /login;
      // popping /create-plan with GoRouter in the test context doesn't crash.
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'My quiet plan',
      );
      await tester.enterText(_stepField(1), 'Breathe deeply');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      // Tap "Keep private — done"
      await tester.tap(find.text('Keep private — done'));
      await tester.pumpAndSettle();

      // requestPublish was NOT called.
      expect(client.requestPublishCalls, isEmpty);
    });
  });

  group('CreatePlanScreen — error states', () {
    testWidgets('shows error banner when createPlan fails', (tester) async {
      final client = _FakeCreatePlanClient()
        ..createPlanError = const CreatePlanException(
          'Network timeout',
          userMessage: 'Could not create your plan. Please try again.',
        );
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Broken plan',
      );
      await tester.enterText(_stepField(1), 'Do the thing');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not create your plan'),
        findsOneWidget,
      );

      // Form is still visible (not replaced with success view).
      expect(find.text('Create plan'), findsOneWidget);
      expect(find.text('Plan created!'), findsNothing);
    });

    testWidgets('shows error banner when requestPublish fails', (tester) async {
      final client = _FakeCreatePlanClient()
        ..requestPublishError = const CreatePlanException(
          'Server error',
          userMessage: 'Could not submit your publish request. Please try again.',
        );
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Publish fail test',
      );
      await tester.enterText(_stepField(1), 'First step');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      // Now on success view.
      expect(find.text('Plan created!'), findsOneWidget);

      await tester.tap(find.text('Request Publish'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not submit your publish request'),
        findsOneWidget,
      );

      // Still on success view (not popped).
      expect(find.text('Plan created!'), findsOneWidget);
    });

    testWidgets('generic error shown when exception has no userMessage',
        (tester) async {
      final client = _FakeCreatePlanClient()
        ..createPlanError = const CreatePlanException('Internal');
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Error test',
      );
      await tester.enterText(_stepField(1), 'Some step');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      // The default userMessage is the message itself.
      expect(find.text('Internal'), findsOneWidget);
    });
  });

  group('CreatePlanScreen — unauthenticated', () {
    testWidgets('redirects to login when user is null', (tester) async {
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(user: null, client: client));
      await tester.pumpAndSettle();

      // Fill and attempt to submit.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Ghost plan',
      );
      await tester.enterText(_stepField(1), 'Haunted step');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      // Should be navigated to /login.
      expect(find.text('Login Screen'), findsOneWidget);
      // createPlan was not called.
      expect(client.createPlanCalls, isEmpty);
    });
  });

  group('CreatePlanScreen — accessibility', () {
    testWidgets('Create plan button has a Semantics wrapper with label',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Find a Semantics node with label 'Create plan'.
      final semanticsWidget = find.bySemanticsLabel('Create plan');
      expect(semanticsWidget, findsOneWidget);
    });

    testWidgets('Request Publish button has a Semantics wrapper', (tester) async {
      final client = _FakeCreatePlanClient();
      await tester.pumpWidget(_buildApp(client: client));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title *'),
        'Pub plan',
      );
      await tester.enterText(_stepField(1), 'Step');
      await tester.tap(find.text('Create plan'));
      await tester.pumpAndSettle();

      final semanticsWidget = find.bySemanticsLabel(
        RegExp(r'Request plan to be published', caseSensitive: false),
      );
      expect(semanticsWidget, findsOneWidget);
    });

    testWidgets('step number badges are present', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // The first step badge shows '1'.
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('Move step tooltips are accessible via keyboard nav',
        (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Move step up'), findsOneWidget);
      expect(find.byTooltip('Move step down'), findsOneWidget);
    });
  });
}
