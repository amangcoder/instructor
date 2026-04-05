import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/database/type_converters.dart';
import 'package:instructor/models/plan_step.dart';

void main() {
  group('StepListConverter', () {
    const converter = StepListConverter();

    test('converts empty list to "[]" and back', () {
      final sql = converter.toSql([]);
      expect(sql, equals('[]'));
      final result = converter.fromSql(sql);
      expect(result, isEmpty);
    });

    test('round-trips a SayStep', () {
      const steps = [PlanStep.say(id: 's1', text: 'Hello')];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a NotifyStep', () {
      const steps = [
        PlanStep.notify(id: 'n1', title: 'Alert', body: 'Pay attention'),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a PlayStep with all fields', () {
      const steps = [
        PlanStep.play(
          id: 'p1',
          audioAssetKey: 'ocean',
          loop: false,
          volume: 0.5,
          fadeInMs: 3000,
          fadeOutMs: 1500,
        ),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a WaitStep', () {
      const steps = [
        PlanStep.wait(id: 'w1', duration: Duration(minutes: 2)),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a RepeatStep with children', () {
      const steps = [
        PlanStep.repeat(
          id: 'r1',
          count: 5,
          children: [
            PlanStep.say(id: 's1', text: 'Inhale'),
            PlanStep.wait(id: 'w1', duration: Duration(seconds: 4)),
          ],
        ),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a StopAudioStep', () {
      const steps = [PlanStep.stopAudio(id: 'sa1')];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('round-trips a mixed list of all step types', () {
      const steps = [
        PlanStep.say(id: 's1', text: 'Start'),
        PlanStep.notify(id: 'n1', title: 'Heads up', body: 'Halfway done'),
        PlanStep.play(id: 'p1', audioAssetKey: 'forest'),
        PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
        PlanStep.repeat(
          id: 'r1',
          count: 3,
          children: [
            PlanStep.say(id: 's2', text: 'Breathe'),
            PlanStep.wait(id: 'w2', duration: Duration(seconds: 5)),
          ],
        ),
        PlanStep.stopAudio(id: 'sa1'),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });

    test('output is valid JSON array string', () {
      const steps = [PlanStep.say(id: 's1', text: 'Test')];
      final sql = converter.toSql(steps);
      expect(sql, startsWith('['));
      expect(sql, endsWith(']'));
    });

    test('round-trips deeply nested RepeatSteps', () {
      const steps = [
        PlanStep.repeat(
          id: 'outer',
          count: 2,
          children: [
            PlanStep.repeat(
              id: 'inner',
              count: 3,
              children: [
                PlanStep.wait(id: 'w1', duration: Duration(seconds: 10)),
              ],
            ),
          ],
        ),
      ];
      final sql = converter.toSql(steps);
      final result = converter.fromSql(sql);
      expect(result, equals(steps));
    });
  });

  group('StringListConverter', () {
    const converter = StringListConverter();

    test('converts empty list to "[]" and back', () {
      final sql = converter.toSql([]);
      expect(sql, equals('[]'));
      final result = converter.fromSql(sql);
      expect(result, isEmpty);
    });

    test('round-trips a single tag', () {
      final sql = converter.toSql(['yoga']);
      final result = converter.fromSql(sql);
      expect(result, equals(['yoga']));
    });

    test('round-trips multiple tags', () {
      final tags = ['morning', 'breathing', 'beginner'];
      final sql = converter.toSql(tags);
      final result = converter.fromSql(sql);
      expect(result, equals(tags));
    });

    test('handles tags with special characters', () {
      final tags = ['10-minute', 'high intensity', 'core & abs'];
      final sql = converter.toSql(tags);
      final result = converter.fromSql(sql);
      expect(result, equals(tags));
    });

    test('output is valid JSON array string', () {
      final sql = converter.toSql(['a', 'b']);
      expect(sql, startsWith('['));
      expect(sql, endsWith(']'));
    });
  });
}
