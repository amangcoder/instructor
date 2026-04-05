import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/models/enums.dart';

void main() {
  group('PlanCategory', () {
    test('has all expected values', () {
      expect(
        PlanCategory.values.map((e) => e.name),
        containsAll([
          'yoga',
          'meditation',
          'workout',
          'cooking',
          'routine',
          'focus',
          'custom',
        ]),
      );
    });

    test('round-trips through name string', () {
      for (final cat in PlanCategory.values) {
        final name = cat.name;
        final parsed = PlanCategory.values.byName(name);
        expect(parsed, equals(cat));
      }
    });
  });

  group('StepType', () {
    test('has all expected values', () {
      expect(
        StepType.values.map((e) => e.name),
        containsAll(['say', 'notify', 'play', 'wait', 'repeat', 'stopAudio']),
      );
    });
  });

  group('ExecutionStatus', () {
    test('has running, paused, completed', () {
      expect(
        ExecutionStatus.values.map((e) => e.name),
        containsAll(['running', 'paused', 'completed']),
      );
    });
  });

  group('PlanVoice', () {
    test('includes platform fallback', () {
      expect(
        PlanVoice.values.map((e) => e.name),
        contains('platform'),
      );
    });

    test('includes OpenAI voices', () {
      expect(
        PlanVoice.values.map((e) => e.name),
        containsAll(['nova', 'shimmer', 'onyx', 'alloy', 'echo', 'fable']),
      );
    });
  });
}
