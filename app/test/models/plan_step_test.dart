import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan_step.dart';

void main() {
  group('SayStep', () {
    test('creates with required fields', () {
      const step = SayStep(id: 's1', text: 'Hello world');
      expect(step.id, equals('s1'));
      expect(step.text, equals('Hello world'));
      expect(step.voiceId, isNull);
      expect(step.estimatedDuration, isNull);
    });

    test('creates with all fields', () {
      const step = SayStep(
        id: 's2',
        text: 'Breathe in',
        voiceId: 'nova',
        estimatedDuration: Duration(seconds: 3),
      );
      expect(step.voiceId, equals('nova'));
      expect(step.estimatedDuration, equals(const Duration(seconds: 3)));
    });

    test('type is StepType.say', () {
      const step = SayStep(id: 's1', text: 'hi');
      expect(step.type, equals(StepType.say));
    });

    test('estimatedStepDuration returns estimatedDuration or zero', () {
      const withDuration = SayStep(
        id: 's1',
        text: 'x',
        estimatedDuration: Duration(seconds: 5),
      );
      const noDuration = SayStep(id: 's2', text: 'y');
      expect(
        withDuration.estimatedStepDuration,
        equals(const Duration(seconds: 5)),
      );
      expect(noDuration.estimatedStepDuration, equals(Duration.zero));
    });

    test('serializes to JSON and deserializes back', () {
      const step = PlanStep.say(
        id: 's1',
        text: 'Stand up straight',
        voiceId: 'onyx',
        estimatedDuration: Duration(seconds: 4),
      );
      final json = step.toJson();
      final roundTripped = PlanStep.fromJson(json);
      expect(roundTripped, equals(step));
    });
  });

  group('NotifyStep', () {
    test('creates with required fields', () {
      const step = NotifyStep(
        id: 'n1',
        title: 'Time check',
        body: 'You are doing great!',
      );
      expect(step.id, equals('n1'));
      expect(step.title, equals('Time check'));
      expect(step.body, equals('You are doing great!'));
    });

    test('type is StepType.notify', () {
      const step = NotifyStep(id: 'n1', title: 'T', body: 'B');
      expect(step.type, equals(StepType.notify));
    });

    test('estimatedStepDuration is zero', () {
      const step = NotifyStep(id: 'n1', title: 'T', body: 'B');
      expect(step.estimatedStepDuration, equals(Duration.zero));
    });

    test('round-trips through JSON', () {
      const step = PlanStep.notify(
        id: 'n1',
        title: 'Halfway',
        body: 'Keep going!',
      );
      final roundTripped = PlanStep.fromJson(step.toJson());
      expect(roundTripped, equals(step));
    });
  });

  group('PlayStep', () {
    test('has sensible defaults', () {
      const step = PlayStep(id: 'p1', audioAssetKey: 'rain');
      expect(step.loop, isTrue);
      expect(step.volume, equals(1.0));
      expect(step.fadeInMs, isNull);
      expect(step.fadeOutMs, isNull);
    });

    test('type is StepType.play', () {
      const step = PlayStep(id: 'p1', audioAssetKey: 'rain');
      expect(step.type, equals(StepType.play));
    });

    test('estimatedStepDuration is zero', () {
      const step = PlayStep(id: 'p1', audioAssetKey: 'rain');
      expect(step.estimatedStepDuration, equals(Duration.zero));
    });

    test('round-trips through JSON with custom values', () {
      const step = PlanStep.play(
        id: 'p1',
        audioAssetKey: 'forest',
        loop: false,
        volume: 0.6,
        fadeInMs: 2000,
        fadeOutMs: 1000,
      );
      final roundTripped = PlanStep.fromJson(step.toJson());
      expect(roundTripped, equals(step));
    });
  });

  group('WaitStep', () {
    test('creates with required fields', () {
      const step = WaitStep(id: 'w1', duration: Duration(seconds: 30));
      expect(step.duration, equals(const Duration(seconds: 30)));
    });

    test('type is StepType.wait', () {
      const step = WaitStep(id: 'w1', duration: Duration(seconds: 10));
      expect(step.type, equals(StepType.wait));
    });

    test('estimatedStepDuration equals the wait duration', () {
      const duration = Duration(seconds: 45);
      const step = WaitStep(id: 'w1', duration: duration);
      expect(step.estimatedStepDuration, equals(duration));
    });

    test('round-trips through JSON', () {
      const step = PlanStep.wait(
        id: 'w1',
        duration: Duration(minutes: 1, seconds: 30),
      );
      final roundTripped = PlanStep.fromJson(step.toJson());
      expect(roundTripped, equals(step));
    });
  });

  group('RepeatStep', () {
    test('creates with required fields (REQ-017)', () {
      const step = RepeatStep(
        id: 'r1',
        count: 3,
        children: [
          WaitStep(id: 'w1', duration: Duration(seconds: 10)),
          SayStep(id: 's1', text: 'Breathe'),
        ],
      );
      expect(step.count, equals(3));
      expect(step.children, hasLength(2));
    });

    test('count 1-999 edge cases are representable', () {
      const minStep = RepeatStep(id: 'r1', count: 1, children: []);
      const maxStep = RepeatStep(id: 'r2', count: 999, children: []);
      expect(minStep.count, equals(1));
      expect(maxStep.count, equals(999));
    });

    test('type is StepType.repeat', () {
      const step = RepeatStep(id: 'r1', count: 2, children: []);
      expect(step.type, equals(StepType.repeat));
    });

    test('estimatedStepDuration accumulates children * count', () {
      const step = RepeatStep(
        id: 'r1',
        count: 3,
        children: [
          WaitStep(id: 'w1', duration: Duration(seconds: 10)),
          WaitStep(id: 'w2', duration: Duration(seconds: 5)),
        ],
      );
      // (10s + 5s) * 3 = 45s
      expect(
        step.estimatedStepDuration,
        equals(const Duration(seconds: 45)),
      );
    });

    test('nested RepeatStep accumulates correctly', () {
      const inner = RepeatStep(
        id: 'inner',
        count: 2,
        children: [WaitStep(id: 'w1', duration: Duration(seconds: 5))],
      );
      const outer = RepeatStep(
        id: 'outer',
        count: 3,
        children: [inner],
      );
      // inner = 5s * 2 = 10s; outer = 10s * 3 = 30s
      expect(outer.estimatedStepDuration, equals(const Duration(seconds: 30)));
    });

    test('children list supports nesting (REQ-017)', () {
      const nestedStep = RepeatStep(
        id: 'r1',
        count: 5,
        children: [
          SayStep(id: 's1', text: 'Inhale'),
          WaitStep(id: 'w1', duration: Duration(seconds: 4)),
          SayStep(id: 's2', text: 'Exhale'),
          WaitStep(id: 'w2', duration: Duration(seconds: 4)),
        ],
      );
      expect(nestedStep.children, hasLength(4));
      expect(nestedStep.children[0], isA<SayStep>());
    });

    test('round-trips through JSON with nested children', () {
      const step = PlanStep.repeat(
        id: 'r1',
        count: 5,
        children: [
          PlanStep.say(id: 's1', text: 'Inhale'),
          PlanStep.wait(id: 'w1', duration: Duration(seconds: 4)),
        ],
      );
      final roundTripped = PlanStep.fromJson(step.toJson());
      expect(roundTripped, equals(step));
    });

    test('deeply nested RepeatStep round-trips through JSON', () {
      const step = PlanStep.repeat(
        id: 'outer',
        count: 3,
        children: [
          PlanStep.repeat(
            id: 'inner',
            count: 2,
            children: [
              PlanStep.wait(id: 'w1', duration: Duration(seconds: 5)),
            ],
          ),
        ],
      );
      final json = step.toJson();
      final roundTripped = PlanStep.fromJson(json);
      expect(roundTripped, equals(step));
    });
  });

  group('StopAudioStep', () {
    test('creates with required id', () {
      const step = StopAudioStep(id: 'sa1');
      expect(step.id, equals('sa1'));
    });

    test('type is StepType.stopAudio', () {
      const step = StopAudioStep(id: 'sa1');
      expect(step.type, equals(StepType.stopAudio));
    });

    test('estimatedStepDuration is zero', () {
      const step = StopAudioStep(id: 'sa1');
      expect(step.estimatedStepDuration, equals(Duration.zero));
    });

    test('round-trips through JSON', () {
      const step = PlanStep.stopAudio(id: 'sa1');
      final roundTripped = PlanStep.fromJson(step.toJson());
      expect(roundTripped, equals(step));
    });
  });

  group('PlanStep JSON discriminator', () {
    test('JSON includes type discriminator for each variant', () {
      final steps = <PlanStep>[
        const PlanStep.say(id: '1', text: 'Hi'),
        const PlanStep.notify(id: '2', title: 'T', body: 'B'),
        const PlanStep.play(id: '3', audioAssetKey: 'rain'),
        const PlanStep.wait(id: '4', duration: Duration(seconds: 1)),
        const PlanStep.repeat(id: '5', count: 2, children: []),
        const PlanStep.stopAudio(id: '6'),
      ];
      final expectedTypes = ['say', 'notify', 'play', 'wait', 'repeat', 'stopAudio'];

      for (var i = 0; i < steps.length; i++) {
        final json = steps[i].toJson();
        // The discriminator key used by freezed+json_serializable is 'runtimeType'
        expect(
          json.containsKey('runtimeType'),
          isTrue,
          reason: 'Step ${steps[i].runtimeType} JSON missing runtimeType key',
        );
        expect(
          json['runtimeType'],
          equals(expectedTypes[i]),
          reason: 'Discriminator mismatch for ${steps[i].runtimeType}',
        );
      }
    });

    test('unknown type JSON throws FormatException', () {
      final badJson = {'runtimeType': 'unknownStepType', 'id': 'x'};
      expect(
        () => PlanStep.fromJson(badJson),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });

  group('PlanStep list JSON encoding', () {
    test('encodes and decodes a mixed list', () {
      const steps = [
        PlanStep.say(id: 's1', text: 'Start'),
        PlanStep.wait(id: 'w1', duration: Duration(seconds: 60)),
        PlanStep.notify(id: 'n1', title: 'Done', body: 'Finished'),
        PlanStep.stopAudio(id: 'sa1'),
      ];
      final encoded = jsonEncode(steps.map((s) => s.toJson()).toList());
      final decoded = (jsonDecode(encoded) as List<dynamic>)
          .map((e) => PlanStep.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(decoded, equals(steps));
    });
  });
}
