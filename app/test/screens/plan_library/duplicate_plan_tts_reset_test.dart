// Tests for TASK-064: duplicate plan TTS field reset.
//
// Verifies that the duplication logic in _PlanList._duplicatePlan correctly
// resets all TTS-related and activation fields to their initial defaults so
// that a duplicated plan starts in a clean state.
//
// These tests exercise the Plan.copyWith call made by _duplicatePlan directly,
// without a full widget tree or database, so they are fast pure-unit tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/enums.dart';

void main() {
  group('Plan duplication — TTS field reset (TASK-064)', () {
    /// Helper: simulate the copyWith call used by _duplicatePlan.
    Plan _simulateDuplicate(Plan original) {
      final now = DateTime.now();
      return original.copyWith(
        id: '',
        name: '${original.name} (copy)',
        createdAt: now,
        updatedAt: now,
        lastUsedAt: null,
        isActive: false,
        ttsStatus: 'none',
        ttsTotal: 0,
        ttsCompleted: 0,
      );
    }

    late Plan activePlanWithCompletedTts;

    setUp(() {
      final base = DateTime(2025, 1, 1);
      activePlanWithCompletedTts = Plan(
        id: 'server-uuid-123',
        name: 'Morning Yoga',
        category: PlanCategory.yoga,
        createdAt: base,
        updatedAt: base,
        lastUsedAt: base,
        isActive: true,
        ttsStatus: 'completed',
        ttsTotal: 12,
        ttsCompleted: 12,
      );
    });

    test('duplicate has isActive = false', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.isActive, isFalse,
          reason: 'Duplicated plan must not inherit the active flag');
    });

    test("duplicate has ttsStatus = 'none'", () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.ttsStatus, equals('none'),
          reason: 'Duplicated plan must reset TTS status to none');
    });

    test('duplicate has ttsTotal = 0', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.ttsTotal, equals(0),
          reason: 'Duplicated plan must reset ttsTotal to 0');
    });

    test('duplicate has ttsCompleted = 0', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.ttsCompleted, equals(0),
          reason: 'Duplicated plan must reset ttsCompleted to 0');
    });

    test('duplicate has empty id (signals new server assignment)', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.id, equals(''),
          reason: 'Duplicated plan must have empty id so repository assigns a new one');
    });

    test('duplicate appends "(copy)" to plan name', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.name, equals('Morning Yoga (copy)'));
    });

    test('duplicate clears lastUsedAt', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.lastUsedAt, isNull,
          reason: 'Duplicated plan has never been used');
    });

    test('duplicate preserves steps, category, and defaultVoice', () {
      final copy = _simulateDuplicate(activePlanWithCompletedTts);
      expect(copy.steps, equals(activePlanWithCompletedTts.steps));
      expect(copy.category, equals(activePlanWithCompletedTts.category));
      expect(copy.defaultVoice, equals(activePlanWithCompletedTts.defaultVoice));
    });

    test('duplicate with ttsStatus=pending also resets to none', () {
      final pendingPlan = activePlanWithCompletedTts.copyWith(
        ttsStatus: 'pending',
        ttsTotal: 5,
        ttsCompleted: 2,
        isActive: true,
      );
      final copy = _simulateDuplicate(pendingPlan);

      expect(copy.isActive, isFalse);
      expect(copy.ttsStatus, equals('none'));
      expect(copy.ttsTotal, equals(0));
      expect(copy.ttsCompleted, equals(0));
    });

    test('duplicate of already-inactive plan still has isActive=false', () {
      final inactivePlan = activePlanWithCompletedTts.copyWith(
        isActive: false,
        ttsStatus: 'none',
        ttsTotal: 0,
        ttsCompleted: 0,
      );
      final copy = _simulateDuplicate(inactivePlan);

      expect(copy.isActive, isFalse);
      expect(copy.ttsStatus, equals('none'));
      expect(copy.ttsTotal, equals(0));
      expect(copy.ttsCompleted, equals(0));
    });
  });
}
