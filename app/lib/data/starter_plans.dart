import 'package:instructor/data/audio_assets.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/repositories/plan_repository.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Seeds the Plan Library with 15 pre-built starter Plans on a fresh install.
///
/// Checks whether the Plans table is empty before inserting. If at least one
/// Plan already exists the function returns immediately, preserving any
/// user-created Plans and preventing duplicates on subsequent launches.
///
/// Intended to be called once from [main] (or an app initialisation hook)
/// after the database has been opened:
/// ```dart
/// await initDatabase();
/// final repo = ref.read(planRepositoryProvider);
/// await seedStarterPlans(repo);
/// ```
Future<void> seedStarterPlans(PlanRepository repository) async {
  final existing = await repository.watchAllPlans().first;
  if (existing.isNotEmpty) return;

  final now = DateTime.now();
  for (final plan in _buildStarterPlans(now)) {
    await repository.createPlan(plan);
  }
}

// ---------------------------------------------------------------------------
// Starter plan list
// ---------------------------------------------------------------------------

List<Plan> _buildStarterPlans(DateTime now) => [
      // ── Yoga ──────────────────────────────────────────────────────────────
      _sunSalutationFlow(now),
      _morningStretch(now),
      _eveningWindDown(now),
      // ── Meditation ────────────────────────────────────────────────────────
      _fiveMinuteBreathing(now),
      _tenMinuteBodyScan(now),
      // ── Workout ───────────────────────────────────────────────────────────
      _sevenMinuteHiit(now),
      _tabataTimer(now),
      _strengthCircuit(now),
      // ── Cooking ───────────────────────────────────────────────────────────
      _pastaTimer(now),
      _teaStepingGuide(now),
      // ── Routine ───────────────────────────────────────────────────────────
      _morningRoutine(now),
      _eveningRoutine(now),
      _bedtimeWindDown(now),
      // ── Focus ─────────────────────────────────────────────────────────────
      _twentyFiveMinutePomodoro(now),
      _fiftyTenDeepWork(now),
    ];

// ---------------------------------------------------------------------------
// ── YOGA ─────────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 1. Sun Salutation Flow (~12 min) ─────────────────────────────────────────

Plan _sunSalutationFlow(DateTime now) => Plan(
      id: 0,
      name: 'Sun Salutation Flow',
      description:
          'Three rounds of classical Surya Namaskar with guided pose cues and timed holds.',
      category: PlanCategory.yoga,
      tags: const ['yoga', 'morning', 'flow'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // Start ambient forest audio
        PlanStep.play(
          id: 'ssf_p1',
          audioAssetKey: kAmbientForest,
          loop: true,
          fadeInMs: 2000,
        ),
        // Opening notification
        PlanStep.notify(
          id: 'ssf_n1',
          title: 'Sun Salutation Flow',
          body: 'Starting your 12-minute yoga session',
        ),
        // Welcome
        PlanStep.say(
          id: 'ssf_s1',
          text:
              'Welcome to Sun Salutation Flow. We will move through three complete rounds together. '
              'Unroll your mat and stand at the front edge.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'ssf_w1', duration: Duration(seconds: 10)),
        // Three rounds of Sun Salutation
        PlanStep.repeat(
          id: 'ssf_r1',
          count: 3,
          children: [
            PlanStep.say(
              id: 'ssf_r_s1',
              text:
                  'Mountain Pose. Feet together, palms pressed at heart center. '
                  'Ground down through all four corners of your feet.',
              estimatedDuration: Duration(seconds: 6),
            ),
            PlanStep.wait(id: 'ssf_r_w1', duration: Duration(seconds: 12)),
            PlanStep.say(
              id: 'ssf_r_s2',
              text:
                  'Inhale — sweep your arms wide and up into Upward Salute. '
                  'Lift through the crown, find a gentle back bend.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w2', duration: Duration(seconds: 8)),
            PlanStep.say(
              id: 'ssf_r_s3',
              text:
                  'Exhale — swan dive forward into Standing Forward Fold. '
                  'Soften your knees if needed. Let your head hang heavy.',
              estimatedDuration: Duration(seconds: 6),
            ),
            PlanStep.wait(id: 'ssf_r_w3', duration: Duration(seconds: 10)),
            PlanStep.say(
              id: 'ssf_r_s4',
              text: 'Inhale — Flat Back. Fingertips to shins, spine long, gaze forward.',
              estimatedDuration: Duration(seconds: 4),
            ),
            PlanStep.wait(id: 'ssf_r_w4', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'ssf_r_s5',
              text:
                  'Exhale — step back to Plank Pose. Shoulders stack over wrists. '
                  'Body forms one strong line.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w5', duration: Duration(seconds: 15)),
            PlanStep.say(
              id: 'ssf_r_s6',
              text: 'Lower with control through Chaturanga. Elbows graze your ribs.',
              estimatedDuration: Duration(seconds: 4),
            ),
            PlanStep.wait(id: 'ssf_r_w6', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'ssf_r_s7',
              text:
                  'Inhale into Upward Facing Dog. Press the tops of your feet down, '
                  'lift your thighs, open your chest.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w7', duration: Duration(seconds: 12)),
            PlanStep.say(
              id: 'ssf_r_s8',
              text:
                  'Exhale — press back into Downward Facing Dog. '
                  'Spread your fingers wide. Take five slow breaths here.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w8', duration: Duration(seconds: 35)),
            PlanStep.say(
              id: 'ssf_r_s9',
              text:
                  'Step your right foot forward to Low Lunge. '
                  'Back knee floats or rests on the mat.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w9', duration: Duration(seconds: 12)),
            PlanStep.say(
              id: 'ssf_r_s10',
              text: 'Rise into Warrior One. Arms reach high, front knee bends to ninety degrees.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w10', duration: Duration(seconds: 12)),
            PlanStep.say(
              id: 'ssf_r_s11',
              text:
                  'Open into Warrior Two. Arms extend wide, gaze over your front fingertips.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w11', duration: Duration(seconds: 12)),
            PlanStep.say(
              id: 'ssf_r_s12',
              text:
                  'Windmill your hands to the mat, step back to Plank. '
                  'Then press to Downward Dog for three breaths.',
              estimatedDuration: Duration(seconds: 6),
            ),
            PlanStep.wait(id: 'ssf_r_w12', duration: Duration(seconds: 20)),
            PlanStep.say(
              id: 'ssf_r_s13',
              text:
                  'Walk your feet to your hands. Roll slowly up to standing. '
                  'Pause in Mountain Pose.',
              estimatedDuration: Duration(seconds: 5),
            ),
            PlanStep.wait(id: 'ssf_r_w13', duration: Duration(seconds: 10)),
          ],
        ),
        // Closing bell + cool-down
        PlanStep.play(id: 'ssf_p2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'ssf_s2',
          text:
              'Wonderful practice. Bring your palms together at your heart. '
              'Close your eyes and feel the warmth you have generated. Namaste.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ssf_w2', duration: Duration(seconds: 15)),
        PlanStep.stopAudio(id: 'ssf_sa1'),
      ],
    );

// ── 2. Morning Stretch (~8 min) ───────────────────────────────────────────────

Plan _morningStretch(DateTime now) => Plan(
      id: 0,
      name: 'Morning Stretch',
      description: 'A gentle full-body stretch to wake up your muscles and joints.',
      category: PlanCategory.yoga,
      tags: const ['yoga', 'morning', 'stretch', 'gentle'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'ms_p1',
          audioAssetKey: kAmbientForest,
          loop: true,
          fadeInMs: 1500,
        ),
        PlanStep.notify(
          id: 'ms_n1',
          title: 'Morning Stretch',
          body: 'Time to wake up your body',
        ),
        PlanStep.say(
          id: 'ms_s1',
          text:
              'Good morning. Let\'s gently wake up every part of your body. '
              'Move slowly and never force a stretch.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ms_w1', duration: Duration(seconds: 8)),
        // Neck rolls
        PlanStep.say(
          id: 'ms_s2',
          text:
              'Start with slow neck rolls. Drop your right ear to your right shoulder '
              'and breathe into the stretch.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'ms_w2', duration: Duration(seconds: 20)),
        PlanStep.say(
          id: 'ms_s3',
          text: 'Roll your head forward and then to the left side. Hold here.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'ms_w3', duration: Duration(seconds: 20)),
        // Shoulder opener
        PlanStep.say(
          id: 'ms_s4',
          text:
              'Clasp your hands behind your back. Squeeze your shoulder blades together '
              'and lift your hands slightly. Open your chest.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'ms_w4', duration: Duration(seconds: 20)),
        // Side stretch
        PlanStep.say(
          id: 'ms_s5',
          text:
              'Standing or seated, reach your right arm overhead and lean gently to the left. '
              'Feel the long stretch through your right side.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'ms_w5', duration: Duration(seconds: 20)),
        PlanStep.say(
          id: 'ms_s6',
          text: 'Switch sides. Left arm overhead, lean gently to the right.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'ms_w6', duration: Duration(seconds: 20)),
        // Forward fold
        PlanStep.say(
          id: 'ms_s7',
          text:
              'Standing forward fold. Bend your knees generously, '
              'fold your torso over your thighs and let your arms dangle.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'ms_w7', duration: Duration(seconds: 25)),
        // Low lunge hip flexor
        PlanStep.say(
          id: 'ms_s8',
          text:
              'Step your right foot back into a Low Lunge. '
              'Sink your hips toward the mat and feel the hip flexor open.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'ms_w8', duration: Duration(seconds: 25)),
        PlanStep.say(
          id: 'ms_s9',
          text: 'Switch sides. Step your left foot back into Low Lunge.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'ms_w9', duration: Duration(seconds: 25)),
        // Child's pose
        PlanStep.say(
          id: 'ms_s10',
          text:
              'Come down to Child\'s Pose. Arms extended or resting alongside your body. '
              'Breathe into your back. Rest here.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'ms_w10', duration: Duration(seconds: 30)),
        // Close
        PlanStep.play(id: 'ms_p2', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'ms_s11',
          text:
              'Slowly rise. Take a moment to appreciate your body. '
              'You are ready to start your day.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'ms_w11', duration: Duration(seconds: 10)),
        PlanStep.stopAudio(id: 'ms_sa1'),
      ],
    );

// ── 3. Evening Wind Down (~15 min) ────────────────────────────────────────────

Plan _eveningWindDown(DateTime now) => Plan(
      id: 0,
      name: 'Evening Wind Down',
      description: 'Restorative yoga poses held for longer durations to release the day\'s tension.',
      category: PlanCategory.yoga,
      tags: const ['yoga', 'evening', 'restorative', 'relaxation'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'ewd_p1',
          audioAssetKey: kAmbientOcean,
          loop: true,
          fadeInMs: 3000,
          volume: 0.6,
        ),
        PlanStep.notify(
          id: 'ewd_n1',
          title: 'Evening Wind Down',
          body: 'Time to release the day and restore your body',
        ),
        PlanStep.say(
          id: 'ewd_s1',
          text:
              'Welcome to your evening wind-down. Find a quiet, comfortable space. '
              'We will move slowly tonight — no effort, only release.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'ewd_w1', duration: Duration(seconds: 12)),
        // Supine twist
        PlanStep.say(
          id: 'ewd_s2',
          text:
              'Lie on your back. Hug your right knee into your chest, '
              'then let it fall across your body to the left. '
              'Extend your right arm to the right. Breathe and soften.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ewd_w2', duration: Duration(seconds: 60)),
        PlanStep.say(
          id: 'ewd_s3',
          text: 'Slowly return to center. Switch sides. Left knee crosses to the right.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'ewd_w3', duration: Duration(seconds: 60)),
        // Happy baby
        PlanStep.say(
          id: 'ewd_s4',
          text:
              'Hug both knees in. Take hold of the outer edges of your feet '
              'and open your knees wider than your torso — Happy Baby pose. '
              'Rock gently if that feels good.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ewd_w4', duration: Duration(seconds: 60)),
        // Legs up the wall / reclined butterfly
        PlanStep.say(
          id: 'ewd_s5',
          text:
              'Release your feet. Bring the soles of your feet together '
              'into Reclined Butterfly. Let your knees fall open. '
              'Place hands on your belly and feel it rise and fall.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ewd_w5', duration: Duration(seconds: 90)),
        // Legs up
        PlanStep.say(
          id: 'ewd_s6',
          text:
              'Bring your feet back together and gently lift your legs toward the ceiling — '
              'or rest them against a wall. Close your eyes.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'ewd_w6', duration: Duration(seconds: 120)),
        // Savasana
        PlanStep.say(
          id: 'ewd_s7',
          text:
              'Slowly lower your legs to the mat. Extend fully into Savasana. '
              'Arms at your sides, palms up. Let your whole body melt into the floor.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ewd_w7', duration: Duration(seconds: 180)),
        // Close
        PlanStep.play(id: 'ewd_p2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'ewd_s8',
          text:
              'Begin to deepen your breath. Wiggle your fingers and toes. '
              'Roll to your right side before sitting up slowly. Rest well tonight.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'ewd_w8', duration: Duration(seconds: 20)),
        PlanStep.stopAudio(id: 'ewd_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── MEDITATION ────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 4. 5-Minute Breathing (~5 min) ────────────────────────────────────────────

Plan _fiveMinuteBreathing(DateTime now) => Plan(
      id: 0,
      name: '5-Minute Breathing',
      description: 'Guided box-breathing cycles to calm the nervous system in just five minutes.',
      category: PlanCategory.meditation,
      tags: const ['meditation', 'breathing', 'stress', 'quick'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'fmb_p1',
          audioAssetKey: kAmbientTibetanBowls,
          loop: true,
          fadeInMs: 2000,
          volume: 0.5,
        ),
        PlanStep.notify(
          id: 'fmb_n1',
          title: '5-Minute Breathing',
          body: 'Find a comfortable seat and close your eyes',
        ),
        PlanStep.say(
          id: 'fmb_s1',
          text:
              'Find a comfortable seat. Close your eyes and relax your jaw. '
              'We will breathe together for five minutes using a simple four-count rhythm.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'fmb_w1', duration: Duration(seconds: 8)),
        // 12 breathing cycles × ~20s each ≈ 240s = 4min
        PlanStep.repeat(
          id: 'fmb_r1',
          count: 12,
          children: [
            PlanStep.say(
              id: 'fmb_r_s1',
              text: 'Inhale slowly for four counts.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'fmb_r_w1', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'fmb_r_s2',
              text: 'Hold for four counts.',
              estimatedDuration: Duration(seconds: 2),
            ),
            PlanStep.wait(id: 'fmb_r_w2', duration: Duration(seconds: 4)),
            PlanStep.say(
              id: 'fmb_r_s3',
              text: 'Exhale gently for four counts.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'fmb_r_w3', duration: Duration(seconds: 5)),
          ],
        ),
        // Close
        PlanStep.play(id: 'fmb_p2', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fmb_s2',
          text:
              'Let your breath return to its natural rhythm. '
              'Notice the stillness you have created. '
              'When you\'re ready, gently open your eyes.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'fmb_w2', duration: Duration(seconds: 15)),
        PlanStep.stopAudio(id: 'fmb_sa1'),
      ],
    );

// ── 5. 10-Minute Body Scan (~10 min) ──────────────────────────────────────────

Plan _tenMinuteBodyScan(DateTime now) => Plan(
      id: 0,
      name: '10-Minute Body Scan',
      description:
          'A progressive body-scan meditation moving awareness from feet to crown.',
      category: PlanCategory.meditation,
      tags: const ['meditation', 'body scan', 'relaxation', 'mindfulness'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'tbs_p1',
          audioAssetKey: kAmbientRain,
          loop: true,
          fadeInMs: 3000,
          volume: 0.45,
        ),
        PlanStep.notify(
          id: 'tbs_n1',
          title: '10-Minute Body Scan',
          body: 'Lie down and prepare to relax',
        ),
        PlanStep.say(
          id: 'tbs_s1',
          text:
              'Lie down in a comfortable position. Close your eyes. '
              'Let your arms rest by your sides, palms facing up. '
              'We will slowly move our awareness through the body, releasing tension as we go.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'tbs_w1', duration: Duration(seconds: 15)),
        // Feet and legs
        PlanStep.say(
          id: 'tbs_s2',
          text:
              'Bring your attention to your feet. Notice any sensations — warmth, tingling, pressure. '
              'With your next exhale, let your feet completely soften.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'tbs_w2', duration: Duration(seconds: 30)),
        PlanStep.say(
          id: 'tbs_s3',
          text:
              'Move your awareness up to your calves, shins, and knees. '
              'Notice any tightness and breathe it away.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'tbs_w3', duration: Duration(seconds: 30)),
        PlanStep.say(
          id: 'tbs_s4',
          text:
              'Now your thighs and hips. '
              'This area holds a lot of tension. Give yourself permission to let go completely.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'tbs_w4', duration: Duration(seconds: 35)),
        // Abdomen and back
        PlanStep.say(
          id: 'tbs_s5',
          text:
              'Move into your abdomen. Let it be soft. '
              'Feel it rise as you inhale and fall as you exhale.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'tbs_w5', duration: Duration(seconds: 30)),
        PlanStep.say(
          id: 'tbs_s6',
          text:
              'Your lower back, middle back, and upper back. '
              'Imagine the floor supporting every inch of your spine.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'tbs_w6', duration: Duration(seconds: 30)),
        // Chest and arms
        PlanStep.say(
          id: 'tbs_s7',
          text:
              'Your chest and heart. Notice the gentle rise and fall with each breath. '
              'Now your shoulders, arms, and hands. Release any grip.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'tbs_w7', duration: Duration(seconds: 35)),
        // Neck and face
        PlanStep.say(
          id: 'tbs_s8',
          text:
              'Your neck and throat. Soften. '
              'Your face — jaw unclenched, tongue off the roof of the mouth, '
              'space between your eyebrows.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'tbs_w8', duration: Duration(seconds: 35)),
        // Crown
        PlanStep.say(
          id: 'tbs_s9',
          text:
              'Finally, the crown of your head. '
              'Your whole body is now heavy and relaxed. '
              'Rest in this stillness for a few more moments.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'tbs_w9', duration: Duration(seconds: 60)),
        // Return
        PlanStep.play(id: 'tbs_p2', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'tbs_s10',
          text:
              'Begin to deepen your breath. Bring gentle movement back into your fingers and toes. '
              'When you\'re ready, slowly open your eyes.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'tbs_w10', duration: Duration(seconds: 20)),
        PlanStep.stopAudio(id: 'tbs_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── WORKOUT ───────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 6. 7-Minute HIIT (~7 min) ─────────────────────────────────────────────────

Plan _sevenMinuteHiit(DateTime now) => Plan(
      id: 0,
      name: '7-Minute HIIT',
      description:
          'Seven classic bodyweight exercises, 30 seconds each with 10-second rests.',
      category: PlanCategory.workout,
      tags: const ['workout', 'hiit', 'bodyweight', 'quick'],
      defaultVoice: PlanVoice.onyx.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'smh_n1',
          title: '7-Minute HIIT',
          body: 'Get ready — workout starts in 10 seconds',
        ),
        PlanStep.say(
          id: 'smh_s1',
          text:
              'Seven minutes, seven exercises, thirty seconds each. '
              'Push hard during each interval. Let\'s go!',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'smh_w_pre', duration: Duration(seconds: 5)),
        // Exercise 1: Jumping Jacks
        PlanStep.play(id: 'smh_bell1', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s2',
          text: 'Jumping Jacks — go!',
          estimatedDuration: Duration(seconds: 2),
        ),
        PlanStep.wait(id: 'smh_w1', duration: Duration(seconds: 30)),
        PlanStep.say(
          id: 'smh_s3',
          text: 'Rest. Great start.',
          estimatedDuration: Duration(seconds: 2),
        ),
        PlanStep.wait(id: 'smh_w1r', duration: Duration(seconds: 10)),
        // Exercise 2: Wall Sit
        PlanStep.play(id: 'smh_bell2', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s4',
          text: 'Wall Sit — find your wall and lower down. Hold it!',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'smh_w2', duration: Duration(seconds: 30)),
        PlanStep.say(id: 'smh_s5', text: 'Rest. Stand up.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'smh_w2r', duration: Duration(seconds: 10)),
        // Exercise 3: Push-ups
        PlanStep.play(id: 'smh_bell3', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s6',
          text: 'Push-ups. Get on the floor — go!',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'smh_w3', duration: Duration(seconds: 30)),
        PlanStep.say(id: 'smh_s7', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'smh_w3r', duration: Duration(seconds: 10)),
        // Exercise 4: Crunches
        PlanStep.play(id: 'smh_bell4', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s8',
          text: 'Crunches — on your back, hands behind your head. Go!',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'smh_w4', duration: Duration(seconds: 30)),
        PlanStep.say(id: 'smh_s9', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'smh_w4r', duration: Duration(seconds: 10)),
        // Exercise 5: Step-ups
        PlanStep.play(id: 'smh_bell5', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s10',
          text: 'Step-ups onto a chair or stairs — alternating legs. Go!',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'smh_w5', duration: Duration(seconds: 30)),
        PlanStep.say(id: 'smh_s11', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'smh_w5r', duration: Duration(seconds: 10)),
        // Exercise 6: Squats
        PlanStep.play(id: 'smh_bell6', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s12',
          text: 'Squats — feet shoulder-width apart. Drive through your heels. Go!',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'smh_w6', duration: Duration(seconds: 30)),
        PlanStep.say(id: 'smh_s13', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'smh_w6r', duration: Duration(seconds: 10)),
        // Exercise 7: Plank
        PlanStep.play(id: 'smh_bell7', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'smh_s14',
          text: 'Final exercise — Plank. Hold tight. Thirty seconds!',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'smh_w7', duration: Duration(seconds: 30)),
        // Done
        PlanStep.play(id: 'smh_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'smh_n2',
          title: '7-Minute HIIT Complete!',
          body: 'You crushed it 🎉',
        ),
        PlanStep.say(
          id: 'smh_s15',
          text: 'Seven minutes done! Excellent work. Take a moment to stretch and catch your breath.',
          estimatedDuration: Duration(seconds: 6),
        ),
      ],
    );

// ── 7. Tabata Timer (~16 min) ─────────────────────────────────────────────────

Plan _tabataTimer(DateTime now) => Plan(
      id: 0,
      name: 'Tabata Timer',
      description:
          '4 exercises × 8 rounds of 20 seconds on and 10 seconds off for '
          'maximum intensity in minimum time.',
      category: PlanCategory.workout,
      tags: const ['workout', 'tabata', 'hiit', 'interval'],
      defaultVoice: PlanVoice.onyx.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'tab_n1',
          title: 'Tabata Timer',
          body: '4 exercises × 8 rounds — 16 minutes total',
        ),
        PlanStep.say(
          id: 'tab_s1',
          text:
              'Tabata protocol: twenty seconds of maximum effort, ten seconds of rest. '
              'Eight rounds per exercise, four exercises total. Give everything you have.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'tab_wpre', duration: Duration(seconds: 8)),
        // ── Exercise 1: Burpees ──────────────────────────────────────────────
        PlanStep.say(id: 'tab_s2', text: 'Exercise one: Burpees.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'tab_w_ex1_pre', duration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'tab_r1',
          count: 8,
          children: [
            PlanStep.play(id: 'tab_r1_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'tab_r1_s1', text: 'Go!', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r1_w1', duration: Duration(seconds: 20)),
            PlanStep.play(id: 'tab_r1_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.say(id: 'tab_r1_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r1_w2', duration: Duration(seconds: 9)),
          ],
        ),
        // ── Exercise 2: Jump Squats ──────────────────────────────────────────
        PlanStep.say(id: 'tab_s3', text: 'Next: Jump Squats. Thirty seconds.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'tab_w_ex2_pre', duration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'tab_r2',
          count: 8,
          children: [
            PlanStep.play(id: 'tab_r2_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'tab_r2_s1', text: 'Go!', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r2_w1', duration: Duration(seconds: 20)),
            PlanStep.play(id: 'tab_r2_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.say(id: 'tab_r2_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r2_w2', duration: Duration(seconds: 9)),
          ],
        ),
        // ── Exercise 3: Mountain Climbers ────────────────────────────────────
        PlanStep.say(id: 'tab_s4', text: 'Next: Mountain Climbers. Fast feet!', estimatedDuration: Duration(seconds: 4)),
        PlanStep.wait(id: 'tab_w_ex3_pre', duration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'tab_r3',
          count: 8,
          children: [
            PlanStep.play(id: 'tab_r3_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'tab_r3_s1', text: 'Go!', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r3_w1', duration: Duration(seconds: 20)),
            PlanStep.play(id: 'tab_r3_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.say(id: 'tab_r3_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r3_w2', duration: Duration(seconds: 9)),
          ],
        ),
        // ── Exercise 4: High Knees ───────────────────────────────────────────
        PlanStep.say(id: 'tab_s5', text: 'Last exercise: High Knees. Finish strong!', estimatedDuration: Duration(seconds: 4)),
        PlanStep.wait(id: 'tab_w_ex4_pre', duration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'tab_r4',
          count: 8,
          children: [
            PlanStep.play(id: 'tab_r4_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'tab_r4_s1', text: 'Go!', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r4_w1', duration: Duration(seconds: 20)),
            PlanStep.play(id: 'tab_r4_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.say(id: 'tab_r4_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'tab_r4_w2', duration: Duration(seconds: 9)),
          ],
        ),
        // Done
        PlanStep.play(id: 'tab_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'tab_n2',
          title: 'Tabata Complete!',
          body: 'Sixteen minutes of pure effort. Excellent work.',
        ),
        PlanStep.say(
          id: 'tab_s6',
          text: 'Tabata complete. That was thirty-two rounds of pure effort. Take a walk and cool down.',
          estimatedDuration: Duration(seconds: 7),
        ),
      ],
    );

// ── 8. Strength Circuit (~20 min) ─────────────────────────────────────────────

Plan _strengthCircuit(DateTime now) => Plan(
      id: 0,
      name: 'Strength Circuit',
      description: '6 compound strength exercises, 3 sets each with guided rest periods.',
      category: PlanCategory.workout,
      tags: const ['workout', 'strength', 'circuit', 'bodyweight'],
      defaultVoice: PlanVoice.onyx.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'sc_n1',
          title: 'Strength Circuit',
          body: '6 exercises × 3 sets — 20 minutes',
        ),
        PlanStep.say(
          id: 'sc_s1',
          text:
              'Strength circuit. Six compound movements, three sets each. '
              'Forty-five seconds of work, fifteen seconds of rest between sets, '
              'thirty seconds between exercises. Move with control.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'sc_wpre', duration: Duration(seconds: 10)),
        // ── Push-ups ─────────────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s2', text: 'Push-ups. Three sets.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sc_r1',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r1_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r1_s1', text: 'Push-ups — go. Chest to floor, full extension.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'sc_r1_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r1_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r1_w2', duration: Duration(seconds: 15)),
          ],
        ),
        PlanStep.wait(id: 'sc_wt1', duration: Duration(seconds: 30)),
        // ── Bodyweight Squats ─────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s3', text: 'Bodyweight Squats. Three sets.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sc_r2',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r2_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r2_s1', text: 'Squats — go. Drive through your heels, keep your chest up.', estimatedDuration: Duration(seconds: 5)),
            PlanStep.wait(id: 'sc_r2_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r2_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r2_w2', duration: Duration(seconds: 15)),
          ],
        ),
        PlanStep.wait(id: 'sc_wt2', duration: Duration(seconds: 30)),
        // ── Glute Bridges ─────────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s4', text: 'Glute Bridges. Lie on your back. Three sets.', estimatedDuration: Duration(seconds: 4)),
        PlanStep.repeat(
          id: 'sc_r3',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r3_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r3_s1', text: 'Glute bridges — go. Squeeze at the top.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'sc_r3_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r3_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r3_w2', duration: Duration(seconds: 15)),
          ],
        ),
        PlanStep.wait(id: 'sc_wt3', duration: Duration(seconds: 30)),
        // ── Plank ─────────────────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s5', text: 'Plank holds. Three sets.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sc_r4',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r4_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r4_s1', text: 'Plank — hold. Core tight, hips level.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'sc_r4_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r4_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r4_w2', duration: Duration(seconds: 15)),
          ],
        ),
        PlanStep.wait(id: 'sc_wt4', duration: Duration(seconds: 30)),
        // ── Reverse Lunges ─────────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s6', text: 'Reverse Lunges, alternating legs. Three sets.', estimatedDuration: Duration(seconds: 4)),
        PlanStep.repeat(
          id: 'sc_r5',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r5_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r5_s1', text: 'Reverse lunges — go. Step back, knee hovers above the floor.', estimatedDuration: Duration(seconds: 5)),
            PlanStep.wait(id: 'sc_r5_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r5_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r5_w2', duration: Duration(seconds: 15)),
          ],
        ),
        PlanStep.wait(id: 'sc_wt5', duration: Duration(seconds: 30)),
        // ── Tricep Dips ───────────────────────────────────────────────────────
        PlanStep.say(id: 'sc_s7', text: 'Tricep Dips on a chair. Final exercise. Three sets.', estimatedDuration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'sc_r6',
          count: 3,
          children: [
            PlanStep.play(id: 'sc_r6_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.say(id: 'sc_r6_s1', text: 'Tricep dips — go. Lower with control.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'sc_r6_w1', duration: Duration(seconds: 45)),
            PlanStep.say(id: 'sc_r6_s2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
            PlanStep.wait(id: 'sc_r6_w2', duration: Duration(seconds: 15)),
          ],
        ),
        // Done
        PlanStep.play(id: 'sc_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'sc_n2',
          title: 'Strength Circuit Complete!',
          body: 'Strong work today.',
        ),
        PlanStep.say(
          id: 'sc_s8',
          text:
              'Circuit complete. Eighteen sets done. Spend the next few minutes '
              'stretching your major muscle groups. Great work today.',
          estimatedDuration: Duration(seconds: 7),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// ── COOKING ───────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 9. Pasta Timer (~12 min) ──────────────────────────────────────────────────

Plan _pastaTimer(DateTime now) => Plan(
      id: 0,
      name: 'Pasta Timer',
      description:
          'Step-by-step pasta cooking guide with timed notifications at each key stage.',
      category: PlanCategory.cooking,
      tags: const ['cooking', 'pasta', 'dinner', 'timer'],
      defaultVoice: PlanVoice.nova.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'pt_n1',
          title: 'Pasta Timer',
          body: 'Fill your pot and put it on high heat',
        ),
        PlanStep.say(
          id: 'pt_s1',
          text:
              'Pasta timer started. Fill a large pot with four to six litres of water '
              'and place it on your highest burner. We\'ll time every step from here.',
          estimatedDuration: Duration(seconds: 8),
        ),
        // Wait for boil (~5 min)
        PlanStep.wait(id: 'pt_w1', duration: Duration(minutes: 5)),
        PlanStep.notify(
          id: 'pt_n2',
          title: 'Add Salt & Pasta',
          body: 'Your water should be boiling — salt generously and add pasta',
        ),
        PlanStep.say(
          id: 'pt_s2',
          text:
              'Time to add salt. Add at least a tablespoon of salt — the water should taste '
              'like the sea. Then add your pasta and stir immediately to prevent sticking.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'pt_w2', duration: Duration(minutes: 1)),
        PlanStep.say(
          id: 'pt_s3',
          text:
              'Give the pasta another stir. Reduce heat slightly if it\'s boiling too vigorously.',
          estimatedDuration: Duration(seconds: 5),
        ),
        // Cook time (~8 min for most pasta)
        PlanStep.wait(id: 'pt_w3', duration: Duration(minutes: 6)),
        PlanStep.notify(
          id: 'pt_n3',
          title: 'Check Pasta — 2 Minutes Left',
          body: 'Fish out a piece and taste it',
        ),
        PlanStep.say(
          id: 'pt_s4',
          text:
              'Two minutes remaining. Pull out one piece of pasta and taste it. '
              'It should have a tiny bit of resistance — al dente. '
              'If it\'s there, drain now. Otherwise give it the last two minutes.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'pt_w4', duration: Duration(minutes: 2)),
        PlanStep.notify(
          id: 'pt_n4',
          title: 'Drain Your Pasta!',
          body: 'Reserve a cup of pasta water first',
        ),
        PlanStep.say(
          id: 'pt_s5',
          text:
              'Before you drain — scoop out a cup of starchy pasta water. '
              'It\'s liquid gold for finishing your sauce. Now drain the pasta. Buon appetito!',
          estimatedDuration: Duration(seconds: 8),
        ),
      ],
    );

// ── 10. Tea Steeping Guide (~5 min) ───────────────────────────────────────────

Plan _teaStepingGuide(DateTime now) => Plan(
      id: 0,
      name: 'Tea Steeping Guide',
      description:
          'Perfect brewing times and temperature reminders for black, green, and herbal teas.',
      category: PlanCategory.cooking,
      tags: const ['cooking', 'tea', 'brewing', 'drink'],
      defaultVoice: PlanVoice.nova.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'tsg_n1',
          title: 'Tea Steeping Guide',
          body: 'Boil your water and choose your tea',
        ),
        PlanStep.say(
          id: 'tsg_s1',
          text:
              'Welcome to the tea steeping guide. '
              'Boil your water — black tea needs one hundred degrees, '
              'green or white tea works better at eighty degrees. '
              'Pre-warm your cup with a splash of hot water while you wait.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'tsg_w1', duration: Duration(minutes: 2)),
        PlanStep.notify(
          id: 'tsg_n2',
          title: 'Add Your Tea',
          body: 'Pour water over your teabag or loose leaf',
        ),
        PlanStep.say(
          id: 'tsg_s2',
          text:
              'Empty the pre-warm water from your cup. '
              'Add your teabag or one teaspoon of loose leaf per cup. '
              'Pour the water over the tea — never squeeze a teabag.',
          estimatedDuration: Duration(seconds: 8),
        ),
        // Steeping time for black tea: 3-5 min
        PlanStep.wait(id: 'tsg_w2', duration: Duration(minutes: 3)),
        PlanStep.notify(
          id: 'tsg_n3',
          title: 'Check Your Tea',
          body: 'Remove the tea now for black or herbal, or wait 1 more minute for a bolder brew',
        ),
        PlanStep.say(
          id: 'tsg_s3',
          text:
              'Three minutes. Your tea is ready for most black and herbal blends. '
              'Remove your tea bag or strain now for a light brew. '
              'For a bolder cup, steep one more minute.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'tsg_w3', duration: Duration(minutes: 1)),
        PlanStep.notify(
          id: 'tsg_n4',
          title: 'Tea Ready!',
          body: 'Remove tea now to prevent bitterness',
        ),
        PlanStep.say(
          id: 'tsg_s4',
          text:
              'Remove your tea now to avoid bitterness. '
              'Add milk, honey, or lemon to taste. '
              'Allow to cool for a minute before your first sip. Enjoy.',
          estimatedDuration: Duration(seconds: 7),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// ── ROUTINE ───────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 11. Morning Routine (~30 min) ─────────────────────────────────────────────

Plan _morningRoutine(DateTime now) => Plan(
      id: 0,
      name: 'Morning Routine',
      description:
          'A structured 30-minute morning routine to start the day with intention.',
      category: PlanCategory.routine,
      tags: const ['routine', 'morning', 'productivity', 'wellbeing'],
      defaultVoice: PlanVoice.nova.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.notify(
          id: 'mr_n1',
          title: 'Good Morning',
          body: 'Your 30-minute morning routine is starting',
        ),
        PlanStep.say(
          id: 'mr_s1',
          text:
              'Good morning. Your day starts now. '
              'This routine will take thirty minutes. '
              'Follow the cues and begin each activity when prompted.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'mr_w1', duration: Duration(seconds: 15)),
        // Hydrate
        PlanStep.say(
          id: 'mr_s2',
          text: 'Step one: Hydrate. Drink a full glass of water right now before anything else.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'mr_w2', duration: Duration(minutes: 1)),
        // Movement — 5 min
        PlanStep.say(
          id: 'mr_s3',
          text:
              'Step two: Move your body for five minutes. '
              'A quick walk outside, jumping jacks, or light stretching. '
              'Get your blood flowing.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'mr_w3', duration: Duration(minutes: 5)),
        PlanStep.notify(
          id: 'mr_n2',
          title: 'Movement Done ✓',
          body: 'Time to clean up — shower or wash your face',
        ),
        // Hygiene — 10 min
        PlanStep.say(
          id: 'mr_s4',
          text: 'Movement done. Take your shower or wash your face and brush your teeth. You have ten minutes.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'mr_w4', duration: Duration(minutes: 10)),
        PlanStep.notify(
          id: 'mr_n3',
          title: 'Hygiene Done ✓',
          body: 'Time for breakfast',
        ),
        // Breakfast — 10 min
        PlanStep.say(
          id: 'mr_s5',
          text:
              'Hygiene done. Prepare and eat a nourishing breakfast. '
              'Aim for protein and complex carbohydrates. '
              'Put your phone down and eat mindfully. Ten minutes.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'mr_w5', duration: Duration(minutes: 10)),
        PlanStep.notify(
          id: 'mr_n4',
          title: 'Breakfast Done ✓',
          body: 'Set your intention for the day',
        ),
        // Intention — 3 min
        PlanStep.say(
          id: 'mr_s6',
          text:
              'Breakfast done. Spend three minutes setting your intention. '
              'What is the single most important thing you want to accomplish today? '
              'Write it down.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'mr_w6', duration: Duration(minutes: 3)),
        // Done
        PlanStep.play(id: 'mr_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n5',
          title: 'Morning Routine Complete!',
          body: 'You are ready for the day. Go get it.',
        ),
        PlanStep.say(
          id: 'mr_s7',
          text:
              'Morning routine complete. You are hydrated, moved, clean, fed, and focused. '
              'Go make today great.',
          estimatedDuration: Duration(seconds: 7),
        ),
      ],
    );

// ── 12. Evening Routine (~20 min) ─────────────────────────────────────────────

Plan _eveningRoutine(DateTime now) => Plan(
      id: 0,
      name: 'Evening Routine',
      description:
          'A 20-minute evening wind-down to process the day and prepare for restful sleep.',
      category: PlanCategory.routine,
      tags: const ['routine', 'evening', 'wind-down', 'sleep prep'],
      defaultVoice: PlanVoice.nova.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'er_p1',
          audioAssetKey: kAmbientRain,
          loop: true,
          fadeInMs: 2000,
          volume: 0.4,
        ),
        PlanStep.notify(
          id: 'er_n1',
          title: 'Evening Routine',
          body: 'Time to wind down for the night',
        ),
        PlanStep.say(
          id: 'er_s1',
          text:
              'Good evening. Work is done. This is your time to close out the day '
              'and prepare your mind and body for rest.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'er_w1', duration: Duration(seconds: 10)),
        // Tidy up — 5 min
        PlanStep.say(
          id: 'er_s2',
          text:
              'Step one: Tidy your main space. '
              'Spend five minutes clearing surfaces so you wake up to a clean environment. '
              'Tomorrow-you will be grateful.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'er_w2', duration: Duration(minutes: 5)),
        PlanStep.notify(id: 'er_n2', title: 'Tidy Done ✓', body: 'Hygiene time'),
        // Hygiene — 5 min
        PlanStep.say(
          id: 'er_s3',
          text:
              'Tidy done. Evening hygiene — wash your face, brush and floss your teeth. '
              'Skincare if that\'s your routine. Five minutes.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'er_w3', duration: Duration(minutes: 5)),
        PlanStep.notify(id: 'er_n3', title: 'Hygiene Done ✓', body: 'Time to reflect'),
        // Journal / reflect — 5 min
        PlanStep.say(
          id: 'er_s4',
          text:
              'Hygiene done. Spend five minutes in reflection. '
              'Write down three things that went well today and one thing you\'d do differently. '
              'No screens during this time.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'er_w4', duration: Duration(minutes: 5)),
        PlanStep.notify(id: 'er_n4', title: 'Reflection Done ✓', body: 'Prepare for tomorrow'),
        // Prep for tomorrow — 5 min
        PlanStep.say(
          id: 'er_s5',
          text:
              'Final step: Set up for tomorrow. '
              'Lay out your clothes, pack your bag, and write your top three priorities for tomorrow. '
              'Five minutes.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'er_w5', duration: Duration(minutes: 5)),
        // Done
        PlanStep.play(id: 'er_p2', audioAssetKey: kEffectChime, loop: false),
        PlanStep.notify(
          id: 'er_n5',
          title: 'Evening Routine Complete',
          body: 'You\'ve earned your rest. Sleep well.',
        ),
        PlanStep.say(
          id: 'er_s6',
          text:
              'Evening routine complete. You are clean, tidied, reflected, and prepared. '
              'Put down your screens and sleep well.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'er_w6', duration: Duration(seconds: 20)),
        PlanStep.stopAudio(id: 'er_sa1'),
      ],
    );

// ── 13. Bedtime Wind Down (~15 min) ───────────────────────────────────────────

Plan _bedtimeWindDown(DateTime now) => Plan(
      id: 0,
      name: 'Bedtime Wind Down',
      description: 'A soothing 15-minute sequence of breathing and gentle movement to ease into sleep.',
      category: PlanCategory.routine,
      tags: const ['routine', 'bedtime', 'sleep', 'relaxation'],
      defaultVoice: PlanVoice.shimmer.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'bwd_p1',
          audioAssetKey: kAmbientOcean,
          loop: true,
          fadeInMs: 3000,
          volume: 0.4,
        ),
        PlanStep.notify(
          id: 'bwd_n1',
          title: 'Bedtime Wind Down',
          body: 'Dim your lights and get comfortable',
        ),
        PlanStep.say(
          id: 'bwd_s1',
          text:
              'Bedtime wind-down. Dim your lights. Put your phone face-down after this. '
              'Lie in bed or on your yoga mat and follow my voice.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'bwd_w1', duration: Duration(seconds: 15)),
        // Progressive muscle relaxation
        PlanStep.say(
          id: 'bwd_s2',
          text:
              'We\'ll begin with a short progressive muscle relaxation. '
              'Squeeze your feet and toes tightly for five seconds.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'bwd_w2', duration: Duration(seconds: 5)),
        PlanStep.say(id: 'bwd_s3', text: 'Release and let go.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'bwd_w3', duration: Duration(seconds: 10)),
        PlanStep.say(
          id: 'bwd_s4',
          text: 'Now your calves and thighs. Squeeze for five seconds.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'bwd_w4', duration: Duration(seconds: 5)),
        PlanStep.say(id: 'bwd_s5', text: 'Release.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'bwd_w5', duration: Duration(seconds: 10)),
        PlanStep.say(
          id: 'bwd_s6',
          text: 'Your core and glutes. Squeeze everything for five seconds.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'bwd_w6', duration: Duration(seconds: 5)),
        PlanStep.say(id: 'bwd_s7', text: 'Release. Sink deeper into the mattress.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'bwd_w7', duration: Duration(seconds: 10)),
        PlanStep.say(
          id: 'bwd_s8',
          text: 'Your hands and arms. Make fists, squeeze your biceps, hold it.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'bwd_w8', duration: Duration(seconds: 5)),
        PlanStep.say(id: 'bwd_s9', text: 'Let go. Arms completely heavy.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'bwd_w9', duration: Duration(seconds: 10)),
        PlanStep.say(
          id: 'bwd_s10',
          text: 'Scrunch your face — eyes, nose, and jaw. Squeeze.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'bwd_w10', duration: Duration(seconds: 5)),
        PlanStep.say(id: 'bwd_s11', text: 'Release. Jaw unclenched, face soft.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'bwd_w11', duration: Duration(seconds: 15)),
        // 4-7-8 breathing for sleep
        PlanStep.say(
          id: 'bwd_s12',
          text:
              'Now we\'ll do four rounds of sleep breathing. '
              'Inhale for four counts, hold for seven, exhale for eight. '
              'This activates your parasympathetic nervous system.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'bwd_w12', duration: Duration(seconds: 5)),
        PlanStep.repeat(
          id: 'bwd_r1',
          count: 4,
          children: [
            PlanStep.say(id: 'bwd_r_s1', text: 'Inhale through your nose for four.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'bwd_r_w1', duration: Duration(seconds: 5)),
            PlanStep.say(id: 'bwd_r_s2', text: 'Hold for seven.', estimatedDuration: Duration(seconds: 2)),
            PlanStep.wait(id: 'bwd_r_w2', duration: Duration(seconds: 7)),
            PlanStep.say(id: 'bwd_r_s3', text: 'Exhale slowly through your mouth for eight.', estimatedDuration: Duration(seconds: 4)),
            PlanStep.wait(id: 'bwd_r_w3', duration: Duration(seconds: 9)),
          ],
        ),
        // Drift to sleep
        PlanStep.say(
          id: 'bwd_s13',
          text:
              'Your body is heavy and warm. Your mind is quiet. '
              'Let sleep come to you naturally. Good night.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'bwd_w13', duration: Duration(minutes: 3)),
        PlanStep.stopAudio(id: 'bwd_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── FOCUS ─────────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 14. 25-Minute Pomodoro (~25 min) ──────────────────────────────────────────

Plan _twentyFiveMinutePomodoro(DateTime now) => Plan(
      id: 0,
      name: '25-Minute Pomodoro',
      description: 'A classic Pomodoro session: 25 minutes of deep focus followed by a break cue.',
      category: PlanCategory.focus,
      tags: const ['focus', 'pomodoro', 'productivity', 'work'],
      defaultVoice: PlanVoice.alloy.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'pom_p1',
          audioAssetKey: kAmbientWhiteNoise,
          loop: true,
          fadeInMs: 1000,
          volume: 0.35,
        ),
        PlanStep.notify(
          id: 'pom_n1',
          title: 'Pomodoro Starting',
          body: '25 minutes of deep focus — silence your distractions',
        ),
        PlanStep.say(
          id: 'pom_s1',
          text:
              'Pomodoro session starting. Twenty-five minutes of uninterrupted focus. '
              'Close unnecessary apps, silence notifications, and begin your task.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'pom_w1', duration: Duration(minutes: 25)),
        // Break time
        PlanStep.play(id: 'pom_p2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'pom_n2',
          title: 'Pomodoro Complete! 🍅',
          body: 'Take a 5-minute break — stand up and move',
        ),
        PlanStep.say(
          id: 'pom_s2',
          text:
              'Pomodoro complete! That\'s twenty-five minutes of focused work. '
              'Step away from your desk. Stretch, refill your water, rest your eyes. '
              'Your five-minute break starts now.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.stopAudio(id: 'pom_sa1'),
      ],
    );

// ── 15. 50/10 Deep Work (~60 min) ─────────────────────────────────────────────

Plan _fiftyTenDeepWork(DateTime now) => Plan(
      id: 0,
      name: '50/10 Deep Work',
      description:
          'Two rounds of 50 minutes of deep work with 10-minute active recovery breaks.',
      category: PlanCategory.focus,
      tags: const ['focus', 'deep work', 'productivity', 'flow'],
      defaultVoice: PlanVoice.alloy.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        PlanStep.play(
          id: 'dw_p1',
          audioAssetKey: kAmbientWhiteNoise,
          loop: true,
          fadeInMs: 1500,
          volume: 0.3,
        ),
        PlanStep.notify(
          id: 'dw_n1',
          title: 'Deep Work Session',
          body: '50 minutes of focus, then a 10-minute break — 2 rounds',
        ),
        PlanStep.say(
          id: 'dw_s1',
          text:
              'Deep work session beginning. Two rounds of fifty minutes on, ten minutes off. '
              'Choose your single most important task and work on nothing else. '
              'Begin now.',
          estimatedDuration: Duration(seconds: 9),
        ),
        // Round 1 — 50 min focus
        PlanStep.wait(id: 'dw_w1', duration: Duration(minutes: 50)),
        PlanStep.play(id: 'dw_p2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'dw_n2',
          title: 'Round 1 Complete — Take a Break',
          body: '10-minute active recovery: walk, stretch, breathe',
        ),
        PlanStep.say(
          id: 'dw_s2',
          text:
              'Round one complete. Fifty minutes done. '
              'Stand up now. Take a ten-minute active break — '
              'walk around, stretch, get outside if you can. '
              'No screens during the break.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.stopAudio(id: 'dw_sa1'),
        // Break
        PlanStep.wait(id: 'dw_w2', duration: Duration(minutes: 10)),
        // Round 2 — 50 min focus
        PlanStep.play(
          id: 'dw_p3',
          audioAssetKey: kAmbientWhiteNoise,
          loop: true,
          fadeInMs: 1500,
          volume: 0.3,
        ),
        PlanStep.notify(
          id: 'dw_n3',
          title: 'Round 2 — Back to Work',
          body: '50 more minutes of deep focus',
        ),
        PlanStep.say(
          id: 'dw_s3',
          text: 'Break over. Back to deep work for fifty more minutes. Resume your task. Begin.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'dw_w3', duration: Duration(minutes: 50)),
        // Session complete
        PlanStep.play(id: 'dw_p4', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'dw_n4',
          title: 'Deep Work Session Complete! ✓',
          body: 'One hundred minutes of focused work done today',
        ),
        PlanStep.say(
          id: 'dw_s4',
          text:
              'Deep work session complete. One hundred minutes of focused work. '
              'That is more concentrated effort than most people manage in an entire day. '
              'Rest well — you\'ve earned it.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.stopAudio(id: 'dw_sa2'),
      ],
    );
