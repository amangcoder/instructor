import 'package:flutter_test/flutter_test.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';

void main() {
  final now = DateTime(2025, 1, 1, 12);

  Plan makePlan({
    String id = 'plan-1',
    String name = 'Test Plan',
    String? description,
    PlanCategory category = PlanCategory.custom,
    List<String> tags = const [],
    String defaultVoice = 'nova',
    List<PlanStep> steps = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return Plan(
      id: id,
      name: name,
      description: description,
      category: category,
      tags: tags,
      defaultVoice: defaultVoice,
      steps: steps,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      lastUsedAt: lastUsedAt,
    );
  }

  group('Plan model (REQ-005)', () {
    test('creates with required fields', () {
      final plan = makePlan();
      expect(plan.id, equals('plan-1'));
      expect(plan.name, equals('Test Plan'));
      expect(plan.description, isNull);
      expect(plan.category, equals(PlanCategory.custom));
      expect(plan.tags, isEmpty);
      expect(plan.defaultVoice, equals('nova'));
      expect(plan.steps, isEmpty);
      expect(plan.lastUsedAt, isNull);
    });

    test('name is required and stored as-is', () {
      final plan = makePlan(name: 'Morning Yoga');
      expect(plan.name, equals('Morning Yoga'));
    });

    test('description is optional and nullable', () {
      final withDesc = makePlan(description: 'A calming session');
      final withoutDesc = makePlan();
      expect(withDesc.description, equals('A calming session'));
      expect(withoutDesc.description, isNull);
    });

    test('supports all PlanCategory values', () {
      for (final cat in PlanCategory.values) {
        final plan = makePlan(category: cat);
        expect(plan.category, equals(cat));
      }
    });

    test('tags list supports multiple tags', () {
      final plan = makePlan(tags: ['morning', 'breathing', 'yoga']);
      expect(plan.tags, equals(['morning', 'breathing', 'yoga']));
    });

    test('defaultVoice is stored', () {
      final plan = makePlan(defaultVoice: 'shimmer');
      expect(plan.defaultVoice, equals('shimmer'));
    });

    test('lastUsedAt is nullable', () {
      final withUsed = makePlan(lastUsedAt: now);
      final withoutUsed = makePlan();
      expect(withUsed.lastUsedAt, equals(now));
      expect(withoutUsed.lastUsedAt, isNull);
    });

    test('stores steps list', () {
      final steps = [
        const PlanStep.say(id: 's1', text: 'Begin'),
        const PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
      ];
      final plan = makePlan(steps: steps);
      expect(plan.steps, equals(steps));
    });

    // REQ-001: Plan.id is String
    test('id is String type', () {
      final plan = makePlan(id: 'uuid-abc-123');
      expect(plan.id, isA<String>());
      expect(plan.id, equals('uuid-abc-123'));
    });
  });

  group('Plan TTS fields (REQ-002)', () {
    test('isActive defaults to false', () {
      final plan = makePlan();
      expect(plan.isActive, isFalse);
    });

    test('ttsStatus defaults to none', () {
      final plan = makePlan();
      expect(plan.ttsStatus, equals('none'));
    });

    test('ttsTotal defaults to 0', () {
      final plan = makePlan();
      expect(plan.ttsTotal, equals(0));
    });

    test('ttsCompleted defaults to 0', () {
      final plan = makePlan();
      expect(plan.ttsCompleted, equals(0));
    });

    test('copyWith updates isActive', () {
      final plan = makePlan();
      final active = plan.copyWith(isActive: true);
      expect(active.isActive, isTrue);
    });

    test('copyWith updates ttsStatus to all valid values', () {
      final plan = makePlan();
      for (final status in [
        'none',
        'pending',
        'processing',
        'completed',
        'partial',
        'failed',
      ]) {
        final updated = plan.copyWith(ttsStatus: status);
        expect(updated.ttsStatus, equals(status));
      }
    });

    test('copyWith updates ttsTotal and ttsCompleted', () {
      final plan = makePlan();
      final updated = plan.copyWith(ttsTotal: 10, ttsCompleted: 7);
      expect(updated.ttsTotal, equals(10));
      expect(updated.ttsCompleted, equals(7));
    });

    test('TTS fields round-trip through JSON', () {
      const now = Duration.zero;
      final plan = Plan(
        id: 'plan-tts-1',
        name: 'TTS Plan',
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
        isActive: true,
        ttsStatus: 'processing',
        ttsTotal: 20,
        ttsCompleted: 5,
      );
      final json = plan.toJson();
      expect(json['isActive'], isTrue);
      expect(json['ttsStatus'], equals('processing'));
      expect(json['ttsTotal'], equals(20));
      expect(json['ttsCompleted'], equals(5));

      final roundTripped = Plan.fromJson(json);
      expect(roundTripped.isActive, isTrue);
      expect(roundTripped.ttsStatus, equals('processing'));
      expect(roundTripped.ttsTotal, equals(20));
      expect(roundTripped.ttsCompleted, equals(5));
    });

    test('TTS fields parse with missing keys (use defaults)', () {
      final json = {
        'id': 'plan-defaults',
        'name': 'Default TTS',
        'createdAt': DateTime(2025).toIso8601String(),
        'updatedAt': DateTime(2025).toIso8601String(),
      };
      final plan = Plan.fromJson(json);
      expect(plan.isActive, isFalse);
      expect(plan.ttsStatus, equals('none'));
      expect(plan.ttsTotal, equals(0));
      expect(plan.ttsCompleted, equals(0));
    });
  });

  group('Plan.totalDuration', () {
    test('returns zero for empty steps', () {
      final plan = makePlan();
      expect(plan.totalDuration, equals(Duration.zero));
    });

    test('sums SayStep durations', () {
      final plan = makePlan(
        steps: [
          const PlanStep.say(
            id: 's1',
            text: 'Hello',
            estimatedDuration: Duration(seconds: 3),
          ),
          const PlanStep.say(
            id: 's2',
            text: 'World',
            estimatedDuration: Duration(seconds: 2),
          ),
        ],
      );
      expect(plan.totalDuration, equals(const Duration(seconds: 5)));
    });

    test('sums WaitStep durations', () {
      final plan = makePlan(
        steps: [
          const PlanStep.wait(id: 'w1', duration: Duration(seconds: 60)),
          const PlanStep.wait(id: 'w2', duration: Duration(seconds: 30)),
        ],
      );
      expect(plan.totalDuration, equals(const Duration(seconds: 90)));
    });

    test('ignores zero-duration steps (notify, play, stopAudio)', () {
      final plan = makePlan(
        steps: [
          const PlanStep.wait(id: 'w1', duration: Duration(seconds: 10)),
          const PlanStep.notify(id: 'n1', title: 'T', body: 'B'),
          const PlanStep.play(id: 'p1', audioAssetKey: 'rain'),
          const PlanStep.stopAudio(id: 'sa1'),
        ],
      );
      expect(plan.totalDuration, equals(const Duration(seconds: 10)));
    });

    test('accumulates RepeatStep children * count', () {
      final plan = makePlan(
        steps: [
          const PlanStep.repeat(
            id: 'r1',
            count: 4,
            children: [
              PlanStep.wait(id: 'w1', duration: Duration(seconds: 15)),
            ],
          ),
        ],
      );
      // 15s * 4 = 60s
      expect(plan.totalDuration, equals(const Duration(seconds: 60)));
    });

    test('mixes all step types correctly', () {
      final plan = makePlan(
        steps: [
          const PlanStep.say(
            id: 's1',
            text: 'Start',
            estimatedDuration: Duration(seconds: 5),
          ),
          const PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
          const PlanStep.notify(id: 'n1', title: 'T', body: 'B'),
          const PlanStep.repeat(
            id: 'r1',
            count: 3,
            children: [
              PlanStep.wait(id: 'w2', duration: Duration(seconds: 10)),
            ],
          ),
          const PlanStep.stopAudio(id: 'sa1'),
        ],
      );
      // 5 + 30 + 0 + (10 * 3) + 0 = 65s
      expect(plan.totalDuration, equals(const Duration(seconds: 65)));
    });

    test('totalDuration — 3-level nesting: multiplies counts at every level',
        () {
      // outer(count=2) × middle(count=3) × inner(count=4) × wait(5s) = 120s
      final plan = makePlan(
        steps: const [
          PlanStep.repeat(
            id: 'outer',
            count: 2,
            children: [
              PlanStep.repeat(
                id: 'middle',
                count: 3,
                children: [
                  PlanStep.repeat(
                    id: 'inner',
                    count: 4,
                    children: [
                      PlanStep.wait(id: 'w1', duration: Duration(seconds: 5)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      expect(plan.totalDuration, equals(const Duration(seconds: 120)));
    });

    test('totalDuration — 3-level nesting with mixed sibling steps', () {
      // outer(count=2):
      //   middle(count=3):
      //     inner(count=4): wait(5s)  → 4×5 = 20s per middle iteration
      //   + notify (0s per middle iter)
      //   middle total = 3 × 20 = 60s per outer iteration
      // + stopAudio at outer level (0s)
      // outer total = 2 × (60 + 0) = 120s
      // + say(5s) at top level
      // grand total = 120 + 5 = 125s
      //
      // But actually the say and stopAudio are siblings of the outer repeat,
      // not children. Let's compute:
      // top-level say: 5s
      // outer repeat (count=2):
      //   middle repeat (count=3):
      //     inner repeat (count=4): wait(5s) = 4*5 = 20s
      //   middle total per outer iteration = 3*20 = 60s
      // outer total = 2*60 = 120s
      // stopAudio: 0s
      // total = 5 + 120 + 0 = 125s
      final plan = makePlan(
        steps: const [
          PlanStep.say(
            id: 's1',
            text: 'Begin',
            estimatedDuration: Duration(seconds: 5),
          ),
          PlanStep.repeat(
            id: 'outer',
            count: 2,
            children: [
              PlanStep.repeat(
                id: 'middle',
                count: 3,
                children: [
                  PlanStep.repeat(
                    id: 'inner',
                    count: 4,
                    children: [
                      PlanStep.wait(id: 'w1', duration: Duration(seconds: 5)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          PlanStep.stopAudio(id: 'sa1'),
        ],
      );
      expect(plan.totalDuration, equals(const Duration(seconds: 125)));
    });
  });

  group('Plan JSON serialization', () {
    test('round-trips with all fields', () {
      final plan = makePlan(
        id: 'plan-42',
        name: 'Morning Yoga',
        description: 'A calming 10 minute yoga session',
        category: PlanCategory.yoga,
        tags: ['morning', 'yoga'],
        defaultVoice: 'shimmer',
        steps: [
          const PlanStep.say(id: 's1', text: 'Begin'),
          const PlanStep.wait(id: 'w1', duration: Duration(seconds: 60)),
        ],
        lastUsedAt: now.add(const Duration(days: 1)),
      );
      final json = plan.toJson();
      final roundTripped = Plan.fromJson(json);
      expect(roundTripped.id, equals(plan.id));
      expect(roundTripped.name, equals(plan.name));
      expect(roundTripped.description, equals(plan.description));
      expect(roundTripped.category, equals(plan.category));
      expect(roundTripped.tags, equals(plan.tags));
      expect(roundTripped.defaultVoice, equals(plan.defaultVoice));
      expect(roundTripped.steps, equals(plan.steps));
    });

    test('round-trips with nullable fields null', () {
      final plan = makePlan();
      final json = plan.toJson();
      final roundTripped = Plan.fromJson(json);
      expect(roundTripped.description, isNull);
      expect(roundTripped.lastUsedAt, isNull);
    });

    test('round-trips with all six step types', () {
      final plan = makePlan(
        id: 'plan-10',
        name: 'All Types Plan',
        steps: const [
          PlanStep.say(
            id: 's1',
            text: 'Hello',
            estimatedDuration: Duration(seconds: 3),
          ),
          PlanStep.wait(id: 'w1', duration: Duration(seconds: 30)),
          PlanStep.notify(id: 'n1', title: 'Halfway!', body: 'Keep going.'),
          PlanStep.play(id: 'p1', audioAssetKey: 'rain'),
          PlanStep.repeat(
            id: 'r1',
            count: 3,
            children: [
              PlanStep.wait(id: 'w2', duration: Duration(seconds: 10)),
            ],
          ),
          PlanStep.stopAudio(id: 'sa1'),
        ],
      );
      final roundTripped = Plan.fromJson(plan.toJson());
      expect(roundTripped, equals(plan));
      expect(roundTripped.steps.length, 6);
    });

    test('round-trips with 3-level nested RepeatStep', () {
      final plan = makePlan(
        id: 'plan-99',
        name: 'Triple Nested',
        steps: const [
          PlanStep.repeat(
            id: 'outer',
            count: 2,
            children: [
              PlanStep.repeat(
                id: 'middle',
                count: 3,
                children: [
                  PlanStep.repeat(
                    id: 'inner',
                    count: 4,
                    children: [
                      PlanStep.say(id: 's1', text: 'Breathe in'),
                      PlanStep.wait(id: 'w1', duration: Duration(seconds: 5)),
                    ],
                  ),
                ],
              ),
              PlanStep.notify(id: 'n1', title: 'Lap done', body: 'Keep going'),
            ],
          ),
          PlanStep.stopAudio(id: 'sa1'),
        ],
      );
      final roundTripped = Plan.fromJson(plan.toJson());
      expect(roundTripped, equals(plan));

      // Verify outer repeat
      final outer = roundTripped.steps[0] as RepeatStep;
      expect(outer.id, 'outer');
      expect(outer.count, 2);
      expect(outer.children.length, 2);

      // Verify middle repeat
      final middle = outer.children[0] as RepeatStep;
      expect(middle.id, 'middle');
      expect(middle.count, 3);
      expect(middle.children.length, 1);

      // Verify inner repeat
      final inner = middle.children[0] as RepeatStep;
      expect(inner.id, 'inner');
      expect(inner.count, 4);
      expect(inner.children.length, 2);

      // Verify inner children
      final innerSay = inner.children[0] as SayStep;
      expect(innerSay.text, 'Breathe in');
      final innerWait = inner.children[1] as WaitStep;
      expect(innerWait.duration, const Duration(seconds: 5));
    });
  });
}
