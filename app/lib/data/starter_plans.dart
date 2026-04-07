import 'package:instructor/data/audio_assets.dart';
import 'package:instructor/models/enums.dart';
import 'package:instructor/models/plan.dart';
import 'package:instructor/models/plan_step.dart';
import 'package:instructor/repositories/plan_repository.dart';

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns the seeded [Plan] that best matches [templateName], or `null` if no
/// match exists.
///
/// Used by [TemplatePickerSheet] so that selecting a built-in template
/// produces a fully-stepped plan instead of an empty one.
Plan? buildStarterPlanForTemplate(String templateName, DateTime now) {
  return switch (templateName) {
    // ── Yoga ─────────────────────────────────────────────────────────────
    '108 Surya Namaskar' => _oneHundredEightSuryaNamaskar(now),
    // ── Meditation ───────────────────────────────────────────────────────
    'Yoga Nidra' => _yogaNidra(now),
    // ── Workout ──────────────────────────────────────────────────────────
    'Full Body Strength Circuit' => _fullBodyStrengthCircuit(now),
    // ── Routine ──────────────────────────────────────────────────────────
    'Morning Routine' => _morningRoutine(now),
    // ── Focus ────────────────────────────────────────────────────────────
    'Deep Work Session' => _deepWorkSession(now),
    // No match — user builds from scratch
    _ => null,
  };
}

/// Seeds the Plan Library with pre-built starter Plans on a fresh install.
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
      _oneHundredEightSuryaNamaskar(now),
      _yogaNidra(now),
      _fullBodyStrengthCircuit(now),
      _morningRoutine(now),
      _deepWorkSession(now),
    ];

// ---------------------------------------------------------------------------
// ── YOGA ─────────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── 108 Surya Namaskar Series (~90 min) ──────────────────────────────────────

Plan _oneHundredEightSuryaNamaskar(DateTime now) => Plan(
      id: 0,
      name: '108 Surya Namaskar Series',
      description:
          'The complete 108 Surya Namaskar practice. First 5 rounds are fully '
          'guided with every pose cued. Remaining 103 rounds are paced with '
          'chime markers and periodic encouragement.',
      category: PlanCategory.yoga,
      tags: const ['yoga', 'surya namaskar', '108', 'advanced', 'endurance'],
      defaultVoice: PlanVoice.leda.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // ── Setup ────────────────────────────────────────────────────────────
        PlanStep.play(
          id: 'sn108_p1',
          audioAssetKey: kAmbientForest,
          loop: true,
          fadeInMs: 3000,
          volume: 0.4,
        ),
        PlanStep.notify(
          id: 'sn108_n1',
          title: '108 Surya Namaskar',
          body: 'Unroll your mat — your 108 round journey begins now',
        ),
        PlanStep.say(
          id: 'sn108_s_welcome',
          text:
              'Welcome to the 108 Surya Namaskar practice. This is a sacred, '
              'endurance-building sequence. We will move through one hundred and eight '
              'rounds of Sun Salutation together. The first five rounds are fully guided '
              'so you can settle into the rhythm. After that, I will sound a chime at the '
              'start of each round and you will move at your own pace. '
              'Stand at the front of your mat. Close your eyes. Take three deep breaths '
              'to set your intention.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'sn108_w_setup', duration: Duration(seconds: 20)),

        // ── ROUND 1 (Right leg leads — fully guided) ─────────────────────────
        PlanStep.play(id: 'sn108_r1_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'sn108_r1_s0',
          text: 'Round one. Right leg leads.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'sn108_r1_w0', duration: Duration(seconds: 3)),
        // 1. Pranamasana
        PlanStep.say(
          id: 'sn108_r1_s1',
          text:
              'Pranamasana — Prayer Pose. Stand tall, feet together. '
              'Bring your palms together at heart center. Close your eyes. Exhale completely.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w1', duration: Duration(seconds: 8)),
        // 2. Hasta Uttanasana
        PlanStep.say(
          id: 'sn108_r1_s2',
          text:
              'Hasta Uttanasana — Raised Arms. Inhale, sweep your arms overhead. '
              'Arch your back gently. Push your pelvis forward. Biceps beside your ears.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w2', duration: Duration(seconds: 8)),
        // 3. Hastapadasana
        PlanStep.say(
          id: 'sn108_r1_s3',
          text:
              'Hastapadasana — Standing Forward Bend. Exhale, fold forward from the hips. '
              'Keep your spine long. Bring your hands to the floor beside your feet. '
              'Soften your knees if needed.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w3', duration: Duration(seconds: 8)),
        // 4. Ashwa Sanchalanasana (right leg back)
        PlanStep.say(
          id: 'sn108_r1_s4',
          text:
              'Ashwa Sanchalanasana — Equestrian Pose. Inhale, step your right leg far back. '
              'Right knee to the floor. Left knee bends at ninety degrees. '
              'Chest open, look up.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w4', duration: Duration(seconds: 8)),
        // 5. Dandasana
        PlanStep.say(
          id: 'sn108_r1_s5',
          text:
              'Dandasana — Plank Pose. Breathe in, step your left foot back. '
              'Body forms one straight line from head to heels. '
              'Arms perpendicular to the floor. Core engaged.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w5', duration: Duration(seconds: 8)),
        // 6. Ashtanga Namaskara
        PlanStep.say(
          id: 'sn108_r1_s6',
          text:
              'Ashtanga Namaskara — Eight Limbed Salute. Exhale, gently lower your knees, '
              'then chest, then chin to the floor. Hips stay slightly lifted. '
              'Eight points touch the ground — two palms, two knees, chest, chin, two feet.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'sn108_r1_w6', duration: Duration(seconds: 6)),
        // 7. Bhujangasana
        PlanStep.say(
          id: 'sn108_r1_s7',
          text:
              'Bhujangasana — Cobra Pose. Inhale, slide forward and raise your chest. '
              'Elbows slightly bent, shoulders away from ears. '
              'Open your heart. Look gently upward.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w7', duration: Duration(seconds: 8)),
        // 8. Adho Mukha Svanasana
        PlanStep.say(
          id: 'sn108_r1_s8',
          text:
              'Adho Mukha Svanasana — Downward Facing Dog. Exhale, lift your hips high. '
              'Push the floor away. Spread your fingers wide. '
              'Press your heels toward the mat. Hold for five breaths.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'sn108_r1_w8', duration: Duration(seconds: 20)),
        // 9. Ashwa Sanchalanasana (right foot forward)
        PlanStep.say(
          id: 'sn108_r1_s9',
          text:
              'Ashwa Sanchalanasana — Equestrian Pose. Inhale, step your right foot forward '
              'between your hands. Left knee rests on the floor. Chest lifts, gaze up.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_r1_w9', duration: Duration(seconds: 8)),
        // 10. Hastapadasana
        PlanStep.say(
          id: 'sn108_r1_s10',
          text:
              'Hastapadasana — Standing Forward Bend. Exhale, step your left foot forward '
              'to meet your right. Fold from the hips. Hands beside your feet.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_r1_w10', duration: Duration(seconds: 6)),
        // 11. Hasta Uttanasana
        PlanStep.say(
          id: 'sn108_r1_s11',
          text:
              'Hasta Uttanasana — Raised Arms. Inhale, rise with a flat back. '
              'Arms sweep overhead. Gentle back bend.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'sn108_r1_w11', duration: Duration(seconds: 6)),
        // 12. Pranamasana
        PlanStep.say(
          id: 'sn108_r1_s12',
          text:
              'Pranamasana — Prayer Pose. Exhale, stand tall. '
              'Palms together at heart center. Round one complete.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'sn108_r1_w12', duration: Duration(seconds: 5)),

        // ── ROUND 2 (Left leg leads — fully guided) ──────────────────────────
        PlanStep.play(id: 'sn108_r2_chime', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'sn108_r2_s0',
          text: 'Round two. Left leg leads this time.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'sn108_r2_w0', duration: Duration(seconds: 3)),
        PlanStep.say(
          id: 'sn108_r2_s1',
          text: 'Pranamasana. Palms at heart. Exhale.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w1', duration: Duration(seconds: 6)),
        PlanStep.say(
          id: 'sn108_r2_s2',
          text: 'Hasta Uttanasana. Inhale, arms up, arch back.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w2', duration: Duration(seconds: 6)),
        PlanStep.say(
          id: 'sn108_r2_s3',
          text: 'Hastapadasana. Exhale, fold forward. Hands beside feet.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w3', duration: Duration(seconds: 6)),
        PlanStep.say(
          id: 'sn108_r2_s4',
          text:
              'Ashwa Sanchalanasana. Inhale, step your left leg far back this time. '
              'Left knee to the floor. Right knee bends. Look up.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_r2_w4', duration: Duration(seconds: 7)),
        PlanStep.say(
          id: 'sn108_r2_s5',
          text: 'Dandasana. Step back to Plank. One strong line.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w5', duration: Duration(seconds: 7)),
        PlanStep.say(
          id: 'sn108_r2_s6',
          text:
              'Ashtanga Namaskara. Lower knees, chest, chin. Hips lifted.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w6', duration: Duration(seconds: 5)),
        PlanStep.say(
          id: 'sn108_r2_s7',
          text: 'Bhujangasana. Slide forward, lift chest. Cobra.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w7', duration: Duration(seconds: 7)),
        PlanStep.say(
          id: 'sn108_r2_s8',
          text: 'Adho Mukha Svanasana. Hips up, Downward Dog. Five breaths.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w8', duration: Duration(seconds: 18)),
        PlanStep.say(
          id: 'sn108_r2_s9',
          text: 'Ashwa Sanchalanasana. Left foot forward between your hands. Right knee down.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'sn108_r2_w9', duration: Duration(seconds: 7)),
        PlanStep.say(
          id: 'sn108_r2_s10',
          text: 'Hastapadasana. Step forward and fold.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'sn108_r2_w10', duration: Duration(seconds: 5)),
        PlanStep.say(
          id: 'sn108_r2_s11',
          text: 'Hasta Uttanasana. Rise up, arms overhead, gentle back bend.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w11', duration: Duration(seconds: 5)),
        PlanStep.say(
          id: 'sn108_r2_s12',
          text: 'Pranamasana. Exhale, palms to heart. Round two complete.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'sn108_r2_w12', duration: Duration(seconds: 5)),

        // ── ROUNDS 3–5 (Fully guided, repeated) ─────────────────────────────
        PlanStep.repeat(
          id: 'sn108_r3to5',
          count: 3,
          children: [
            PlanStep.play(id: 'sn108_r3to5_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.say(
              id: 'sn108_r3to5_s0',
              text: 'Next round. Alternate your leading leg.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w0', duration: Duration(seconds: 2)),
            PlanStep.say(
              id: 'sn108_r3to5_s1',
              text: 'Pranamasana. Palms together, exhale.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w1', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'sn108_r3to5_s2',
              text: 'Hasta Uttanasana. Inhale, arms up and back.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w2', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'sn108_r3to5_s3',
              text: 'Hastapadasana. Exhale, fold forward.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w3', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'sn108_r3to5_s4',
              text: 'Ashwa Sanchalanasana. Step one leg back, lunge. Inhale.',
              estimatedDuration: Duration(seconds: 4),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w4', duration: Duration(seconds: 6)),
            PlanStep.say(
              id: 'sn108_r3to5_s5',
              text: 'Dandasana. Step back, plank.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w5', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'sn108_r3to5_s6',
              text: 'Ashtanga Namaskara. Knees, chest, chin down.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w6', duration: Duration(seconds: 4)),
            PlanStep.say(
              id: 'sn108_r3to5_s7',
              text: 'Bhujangasana. Cobra. Lift your chest.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w7', duration: Duration(seconds: 6)),
            PlanStep.say(
              id: 'sn108_r3to5_s8',
              text: 'Adho Mukha Svanasana. Downward Dog. Three breaths.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w8', duration: Duration(seconds: 15)),
            PlanStep.say(
              id: 'sn108_r3to5_s9',
              text: 'Ashwa Sanchalanasana. Step forward into lunge.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w9', duration: Duration(seconds: 5)),
            PlanStep.say(
              id: 'sn108_r3to5_s10',
              text: 'Hastapadasana. Step forward and fold.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w10', duration: Duration(seconds: 4)),
            PlanStep.say(
              id: 'sn108_r3to5_s11',
              text: 'Hasta Uttanasana. Rise, arms up.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w11', duration: Duration(seconds: 4)),
            PlanStep.say(
              id: 'sn108_r3to5_s12',
              text: 'Pranamasana. Palms to heart. Round complete.',
              estimatedDuration: Duration(seconds: 3),
            ),
            PlanStep.wait(id: 'sn108_r3to5_w12', duration: Duration(seconds: 4)),
          ],
        ),

        // ── TRANSITION TO SELF-PACED ─────────────────────────────────────────
        PlanStep.say(
          id: 'sn108_s_trans',
          text:
              'Excellent. You have completed five guided rounds and know the flow. '
              'From now on, move at your own steady pace. I will sound a chime at the '
              'start of each round and give you time cues along the way. '
              'Keep your breathing synchronized with the movement. Let us continue.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'sn108_w_trans', duration: Duration(seconds: 8)),

        // ── ROUNDS 6–18 (13 rounds x 50s) ───────────────────────────────────
        PlanStep.say(
          id: 'sn108_b1_intro',
          text: 'Rounds six through eighteen. Thirteen rounds. Find your rhythm.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'sn108_b1_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b1',
          count: 13,
          children: [
            PlanStep.play(id: 'sn108_b1_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.wait(id: 'sn108_b1_w', duration: Duration(seconds: 50)),
          ],
        ),
        // Brief rest
        PlanStep.say(
          id: 'sn108_b1_rest',
          text:
              'Eighteen rounds done. Stay standing. Shake out your wrists. '
              'Roll your shoulders. A few deep breaths.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_b1_restw', duration: Duration(seconds: 30)),

        // ── ROUNDS 19–36 (18 rounds x 45s) ──────────────────────────────────
        PlanStep.say(
          id: 'sn108_b2_intro',
          text: 'Rounds nineteen through thirty-six. Eighteen rounds. Your body is warm now — let the movement flow.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_b2_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b2',
          count: 18,
          children: [
            PlanStep.play(id: 'sn108_b2_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.wait(id: 'sn108_b2_w', duration: Duration(seconds: 45)),
          ],
        ),
        // Hydration break
        PlanStep.say(
          id: 'sn108_b2_rest',
          text:
              'Thirty-six rounds complete — one third done. Take a sip of water. '
              'Stay on your feet. Breathe deeply.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_b2_restw', duration: Duration(seconds: 45)),

        // ── ROUNDS 37–54 (18 rounds x 45s) — MIDPOINT ───────────────────────
        PlanStep.say(
          id: 'sn108_b3_intro',
          text:
              'Rounds thirty-seven through fifty-four. Approaching the halfway mark. '
              'Stay steady. Breathe with every pose.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_b3_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b3',
          count: 18,
          children: [
            PlanStep.play(id: 'sn108_b3_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.wait(id: 'sn108_b3_w', duration: Duration(seconds: 45)),
          ],
        ),
        PlanStep.play(id: 'sn108_mid_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'sn108_b3_rest',
          text:
              'Halfway — fifty-four rounds complete. You are doing beautifully. '
              'Hydrate. Wipe your brow. Let your heart rate settle for a moment.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_b3_restw', duration: Duration(seconds: 45)),

        // ── ROUNDS 55–72 (18 rounds x 40s) ──────────────────────────────────
        PlanStep.say(
          id: 'sn108_b4_intro',
          text: 'Rounds fifty-five through seventy-two. Second half. You may notice the pace feels easier — your body knows the way.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_b4_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b4',
          count: 18,
          children: [
            PlanStep.play(id: 'sn108_b4_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.wait(id: 'sn108_b4_w', duration: Duration(seconds: 40)),
          ],
        ),
        PlanStep.say(
          id: 'sn108_b4_rest',
          text:
              'Seventy-two rounds. Two thirds complete. Brief pause. Shake out your hands. '
              'Sip water if you need it.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'sn108_b4_restw', duration: Duration(seconds: 40)),

        // ── ROUNDS 73–90 (18 rounds x 40s) ──────────────────────────────────
        PlanStep.say(
          id: 'sn108_b5_intro',
          text: 'Rounds seventy-three through ninety. The home stretch approaches. Stay focused. Every round is an offering.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_b5_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b5',
          count: 18,
          children: [
            PlanStep.play(id: 'sn108_b5_chime', audioAssetKey: kEffectChime, loop: false),
            PlanStep.wait(id: 'sn108_b5_w', duration: Duration(seconds: 40)),
          ],
        ),
        PlanStep.say(
          id: 'sn108_b5_rest',
          text:
              'Ninety rounds. Just eighteen more. You have come so far. '
              'Take a moment. Breathe. Gather yourself for the final set.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_b5_restw', duration: Duration(seconds: 30)),

        // ── ROUNDS 91–108 (18 rounds x 35s) — FINAL SET ─────────────────────
        PlanStep.say(
          id: 'sn108_b6_intro',
          text:
              'The final eighteen rounds. Ninety-one through one hundred and eight. '
              'Let each round be filled with gratitude. Finish strong.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'sn108_b6_pre', duration: Duration(seconds: 3)),
        PlanStep.repeat(
          id: 'sn108_b6',
          count: 18,
          children: [
            PlanStep.play(id: 'sn108_b6_bell', audioAssetKey: kEffectBell, loop: false),
            PlanStep.wait(id: 'sn108_b6_w', duration: Duration(seconds: 35)),
          ],
        ),

        // ── COMPLETION & COOL DOWN ───────────────────────────────────────────
        PlanStep.play(id: 'sn108_final_gong', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'sn108_n2',
          title: '108 Surya Namaskar Complete!',
          body: 'You did it. Rest in Savasana.',
        ),
        PlanStep.say(
          id: 'sn108_s_done',
          text:
              'One hundred and eight rounds of Surya Namaskar — complete. '
              'That was extraordinary. Slowly come down to the mat. '
              'Lie in Savasana — arms by your sides, palms facing up. '
              'Close your eyes and let your body absorb everything you have given it.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'sn108_w_sav', duration: Duration(seconds: 180)),
        PlanStep.say(
          id: 'sn108_s_close',
          text:
              'Begin to deepen your breath. Wiggle your fingers and toes. '
              'Roll to your right side and gently sit up. '
              'Bring your palms together. Bow your head. '
              'Namaste. You have honoured a profound tradition today.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'sn108_w_close', duration: Duration(seconds: 15)),
        PlanStep.stopAudio(id: 'sn108_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── MEDITATION ───────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── Yoga Nidra (~30 min) ─────────────────────────────────────────────────────

Plan _yogaNidra(DateTime now) => Plan(
      id: 0,
      name: 'Yoga Nidra',
      description:
          'A guided Yoga Nidra — yogic sleep. A complete body-mind relaxation '
          'following the traditional Satyananda method with Sankalpa, rotation of '
          'consciousness, breath awareness, and visualization.',
      category: PlanCategory.meditation,
      tags: const ['meditation', 'yoga nidra', 'deep relaxation', 'sleep', 'traditional'],
      defaultVoice: PlanVoice.leda.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // ── Preparation ──────────────────────────────────────────────────────
        PlanStep.play(
          id: 'yn_p1',
          audioAssetKey: kAmbientOcean,
          loop: true,
          fadeInMs: 4000,
          volume: 0.3,
        ),
        PlanStep.notify(
          id: 'yn_n1',
          title: 'Yoga Nidra',
          body: 'Lie down in Savasana — your deep relaxation begins',
        ),
        PlanStep.say(
          id: 'yn_s1',
          text:
              'Welcome to Yoga Nidra — yogic sleep. Lie down in Savasana. '
              'Arms slightly away from your body, palms facing up. '
              'Feet fall open naturally. Close your eyes. '
              'Make sure you are warm and comfortable. '
              'You will not need to move again until the practice is over.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'yn_w1', duration: Duration(seconds: 20)),
        PlanStep.say(
          id: 'yn_s2',
          text:
              'Become aware of your body lying on the floor. '
              'Feel the weight of your body sinking into the surface beneath you. '
              'Become aware of the sounds around you. The sounds far away. '
              'The sounds nearby. The sound of my voice. '
              'Stay awake. Stay aware. Simply listen and follow.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'yn_w2', duration: Duration(seconds: 15)),

        // ── Sankalpa (Resolve) ───────────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_sank1',
          text:
              'Now it is time for your Sankalpa — your heartfelt resolve. '
              'Think of a short, positive statement in the present tense. '
              'Something deeply meaningful to you. '
              'Repeat it three times silently in your mind with full conviction.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'yn_w_sank1', duration: Duration(seconds: 30)),

        // ── Rotation of Consciousness ────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_rot_intro',
          text:
              'We will now rotate awareness through the body. '
              'As I name each part, simply bring your attention there. '
              'Do not move. Do not try to relax. Just be aware.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'yn_w_rot_intro', duration: Duration(seconds: 8)),
        // Right side
        PlanStep.say(
          id: 'yn_s_rot_r',
          text:
              'Right hand. Right thumb. Second finger. Third finger. Fourth finger. Little finger. '
              'Palm of the hand. Back of the hand. Right wrist. Right forearm. Right elbow. '
              'Right upper arm. Right shoulder. Right armpit. Right side of the waist. '
              'Right hip. Right thigh. Right kneecap. Right shin. Right calf. '
              'Right ankle. Right heel. Sole of the right foot. '
              'Top of the right foot. Right big toe. Second toe. Third toe. Fourth toe. Little toe.',
          estimatedDuration: Duration(seconds: 30),
        ),
        PlanStep.wait(id: 'yn_w_rot_r', duration: Duration(seconds: 10)),
        // Left side
        PlanStep.say(
          id: 'yn_s_rot_l',
          text:
              'Left hand. Left thumb. Second finger. Third finger. Fourth finger. Little finger. '
              'Palm of the hand. Back of the hand. Left wrist. Left forearm. Left elbow. '
              'Left upper arm. Left shoulder. Left armpit. Left side of the waist. '
              'Left hip. Left thigh. Left kneecap. Left shin. Left calf. '
              'Left ankle. Left heel. Sole of the left foot. '
              'Top of the left foot. Left big toe. Second toe. Third toe. Fourth toe. Little toe.',
          estimatedDuration: Duration(seconds: 30),
        ),
        PlanStep.wait(id: 'yn_w_rot_l', duration: Duration(seconds: 10)),
        // Back body
        PlanStep.say(
          id: 'yn_s_rot_back',
          text:
              'Now the back of the body. Right shoulder blade. Left shoulder blade. '
              'The whole upper back. The middle back. The lower back. '
              'The right buttock. The left buttock. The spine. The whole back together.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'yn_w_rot_back', duration: Duration(seconds: 10)),
        // Front body
        PlanStep.say(
          id: 'yn_s_rot_front',
          text:
              'The front of the body. The chest. The right side of the chest. '
              'The left side of the chest. The navel. The abdomen. '
              'The whole front of the body.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'yn_w_rot_front', duration: Duration(seconds: 8)),
        // Head and face
        PlanStep.say(
          id: 'yn_s_rot_head',
          text:
              'The top of the head. The forehead. The right eyebrow. The left eyebrow. '
              'The space between the eyebrows. The right eyelid. The left eyelid. '
              'The right eye. The left eye. The right ear. The left ear. '
              'The right cheek. The left cheek. The nose. The tip of the nose. '
              'The upper lip. The lower lip. The chin. The throat. The whole face. '
              'The whole head.',
          estimatedDuration: Duration(seconds: 22),
        ),
        PlanStep.wait(id: 'yn_w_rot_head', duration: Duration(seconds: 12)),
        // Whole body
        PlanStep.say(
          id: 'yn_s_rot_whole',
          text:
              'Now become aware of the whole body. The whole body lying still and relaxed. '
              'The whole body. Be aware of the whole body.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'yn_w_rot_whole', duration: Duration(seconds: 20)),

        // ── Breath Awareness ─────────────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_breath',
          text:
              'Now bring your awareness to your breath. Do not change it. '
              'Simply watch the natural flow of breath. '
              'Feel the breath at the nostrils — cool air flowing in, warm air flowing out. '
              'Begin to count your breaths backwards from twenty-seven. '
              'Breathing in, twenty-seven. Breathing out, twenty-seven. '
              'Breathing in, twenty-six. Breathing out, twenty-six. '
              'Continue counting on your own. If you lose count, start again from twenty-seven.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'yn_w_breath', duration: Duration(seconds: 120)),

        // ── Feelings and Sensations ──────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_feel1',
          text:
              'Now we explore opposite sensations. '
              'Bring to your body the feeling of heaviness. '
              'Your whole body is heavy — so heavy it is sinking into the floor. '
              'Heavy. Heavy. Heavy.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'yn_w_feel1', duration: Duration(seconds: 20)),
        PlanStep.say(
          id: 'yn_s_feel2',
          text:
              'Now lightness. Your body is so light it could float upward. '
              'Light. Weightless. As if you could drift away.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'yn_w_feel2', duration: Duration(seconds: 20)),
        PlanStep.say(
          id: 'yn_s_feel3',
          text: 'Now warmth. A gentle warmth spreading through your entire body.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'yn_w_feel3', duration: Duration(seconds: 15)),
        PlanStep.say(
          id: 'yn_s_feel4',
          text: 'And now coolness. A pleasant coolness. Like a gentle breeze.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'yn_w_feel4', duration: Duration(seconds: 15)),

        // ── Visualization ────────────────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_viz',
          text:
              'Now we enter the space of visualization. '
              'Imagine you are lying in a vast open meadow under a clear sky. '
              'The grass is soft beneath you. The sky above is a deep, endless blue. '
              'White clouds drift slowly overhead. A warm golden light surrounds you. '
              'You are completely safe. Completely at peace. '
              'Stay in this space. Watch the sky. Let thoughts pass like clouds.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'yn_w_viz', duration: Duration(seconds: 90)),

        // ── Sankalpa Repeat ──────────────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_sank2',
          text:
              'Now return to your Sankalpa — the same resolve you made at the beginning. '
              'Repeat it three times in your mind with deep feeling and conviction. '
              'The seed you plant in this relaxed state takes root deeply.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'yn_w_sank2', duration: Duration(seconds: 30)),

        // ── Externalization ──────────────────────────────────────────────────
        PlanStep.say(
          id: 'yn_s_ext1',
          text:
              'The practice of Yoga Nidra is now coming to a close. '
              'Become aware of your breath again. Become aware of the surface beneath you. '
              'Become aware of the room around you. The sounds nearby.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'yn_w_ext1', duration: Duration(seconds: 15)),
        PlanStep.say(
          id: 'yn_s_ext2',
          text:
              'Begin to move your fingers and toes gently. Rock your head side to side. '
              'Stretch your arms above your head. Take a long, deep breath.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'yn_w_ext2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'yn_p2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'yn_s_ext3',
          text:
              'Roll to your right side. Stay there for a few moments. '
              'When you are ready, slowly sit up. Keep your eyes soft. '
              'Yoga Nidra is complete. Hari Om.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'yn_w_ext3', duration: Duration(seconds: 20)),
        PlanStep.stopAudio(id: 'yn_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── WORKOUT ──────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── Full Body Strength Circuit (~35 min) ─────────────────────────────────────

Plan _fullBodyStrengthCircuit(DateTime now) => Plan(
      id: 0,
      name: 'Full Body Strength Circuit',
      description:
          'A complete 35-minute bodyweight session: 5-minute dynamic warmup with '
          'joint mobilization, 6 compound exercises with 3 sets each and detailed '
          'form cues, plus a 5-minute guided cooldown stretch.',
      category: PlanCategory.workout,
      tags: const ['workout', 'strength', 'circuit', 'bodyweight', 'full body'],
      defaultVoice: PlanVoice.charon.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // ── Setup ────────────────────────────────────────────────────────────
        PlanStep.notify(
          id: 'fbs_n1',
          title: 'Full Body Strength Circuit',
          body: '35 minutes — warmup, 6 exercises, cooldown',
        ),
        PlanStep.say(
          id: 'fbs_s_intro',
          text:
              'Full Body Strength Circuit. Thirty-five minutes of focused work. '
              'We will start with a five-minute dynamic warmup to prepare your joints and muscles. '
              'Then six compound exercises — three sets of forty-five seconds each — with '
              'fifteen seconds rest between sets and thirty seconds between exercises. '
              'We finish with a five-minute guided cooldown. '
              'Clear some floor space. Have water nearby. Let us begin.',
          estimatedDuration: Duration(seconds: 16),
        ),
        PlanStep.wait(id: 'fbs_w_intro', duration: Duration(seconds: 10)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 1: DYNAMIC WARMUP (5 min) ─────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(id: 'fbs_bell_wu', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_wu_intro',
          text:
              'Phase one — dynamic warmup. Five movements, one minute each. '
              'The goal is to raise your heart rate, warm the synovial fluid in your joints, '
              'and activate the muscles we are about to work.',
          estimatedDuration: Duration(seconds: 9),
        ),
        PlanStep.wait(id: 'fbs_w_wu_intro', duration: Duration(seconds: 5)),

        // Warmup 1: Neck circles
        PlanStep.say(
          id: 'fbs_s_wu1',
          text:
              'Neck circles. Stand tall, feet hip-width apart. '
              'Drop your chin to your chest. Slowly roll your head to the right, '
              'back, left, and forward in a full circle. Do five slow circles in each direction. '
              'Keep your shoulders relaxed and down. '
              'If you feel any crunching, slow down and make the circles smaller.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'fbs_w_wu1', duration: Duration(seconds: 50)),

        // Warmup 2: Arm circles & shoulder rolls
        PlanStep.play(id: 'fbs_bell_wu2', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_wu2',
          text:
              'Arm circles. Extend both arms straight out to the sides at shoulder height. '
              'Make small circles forward — gradually making them bigger. '
              'After fifteen seconds, reverse direction. '
              'Then drop your arms and do ten shoulder rolls — five forward, five backward. '
              'Roll them up to your ears, back, and down. Feel the blades glide.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'fbs_w_wu2', duration: Duration(seconds: 50)),

        // Warmup 3: Hip circles
        PlanStep.play(id: 'fbs_bell_wu3', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_wu3',
          text:
              'Hip circles. Place your hands on your hips, feet shoulder-width apart. '
              'Push your hips forward, then rotate them in a wide circle to the right, '
              'back, left, and forward. Big, smooth circles. '
              'Ten circles clockwise, then ten counterclockwise. '
              'Keep your upper body relatively still — isolate the hips.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'fbs_w_wu3', duration: Duration(seconds: 50)),

        // Warmup 4: Leg swings
        PlanStep.play(id: 'fbs_bell_wu4', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_wu4',
          text:
              'Leg swings. Hold a wall or chair for balance if needed. '
              'Swing your right leg forward and backward like a pendulum. '
              'Keep it relaxed — let momentum do the work. Ten swings. '
              'Then switch to the left leg. Ten swings. '
              'Next, face the wall and swing each leg side to side — ten per leg. '
              'This opens up the hip flexors and adductors.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'fbs_w_wu4', duration: Duration(seconds: 50)),

        // Warmup 5: Bodyweight squats (easy pace)
        PlanStep.play(id: 'fbs_bell_wu5', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_wu5',
          text:
              'Easy bodyweight squats to finish the warmup. '
              'Feet shoulder-width apart, toes pointing slightly out. '
              'Sit your hips back and down as if you are lowering into a chair. '
              'Go at a comfortable pace — no rushing. Focus on getting full depth. '
              'Thighs parallel to the floor or below if your mobility allows. '
              'Keep your chest lifted and your weight in your heels. '
              'About fifteen reps at an easy pace.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'fbs_w_wu5', duration: Duration(seconds: 50)),

        PlanStep.say(
          id: 'fbs_s_wu_done',
          text:
              'Warmup complete. Your body is ready. '
              'Grab a sip of water. We start the main circuit in fifteen seconds.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'fbs_w_wu_done', duration: Duration(seconds: 15)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 2: MAIN CIRCUIT (6 exercises x 3 sets) ────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(id: 'fbs_gong_main', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'fbs_s_main_intro',
          text:
              'Phase two — main circuit. Six exercises. Three sets of forty-five seconds '
              'for each exercise, with fifteen seconds rest between sets and thirty seconds '
              'rest between exercises. I will guide your form on the first set of each exercise. '
              'Move with control — quality over speed.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'fbs_w_main_intro', duration: Duration(seconds: 8)),

        // ── Exercise 1: Push-ups ─────────────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex1_intro',
          text:
              'Exercise one — Push-ups. Three sets. '
              'Hands slightly wider than shoulder-width, fingers spread. '
              'Body in a straight line from head to heels — do not let your hips sag or pike up. '
              'Lower your chest until it hovers two inches from the floor. '
              'Elbows track at about forty-five degrees from your torso, not flared straight out. '
              'Push through your palms to full extension at the top. Exhale on the push, inhale on the way down. '
              'If full push-ups are too challenging, drop to your knees — same form, shorter lever.',
          estimatedDuration: Duration(seconds: 20),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_intro', duration: Duration(seconds: 5)),
        // Set 1
        PlanStep.play(id: 'fbs_ex1_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex1_s1',
          text: 'Set one — go. Chest to the floor. Full extension. Breathe.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_s1', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex1_r1',
          text: 'Rest. Shake out your arms. Fifteen seconds.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_r1', duration: Duration(seconds: 15)),
        // Set 2
        PlanStep.play(id: 'fbs_ex1_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex1_s2',
          text: 'Set two — go. Keep your core braced. Steady tempo.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_s2', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex1_r2',
          text: 'Rest. Good work. One more set.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_r2', duration: Duration(seconds: 15)),
        // Set 3
        PlanStep.play(id: 'fbs_ex1_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex1_s3',
          text: 'Final set — push-ups. Give it everything. Controlled descent, explosive push.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_s3', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex1_done',
          text: 'Push-ups done. Transition in thirty seconds.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex1_trans', duration: Duration(seconds: 30)),

        // ── Exercise 2: Bodyweight Squats ────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex2_intro',
          text:
              'Exercise two — Bodyweight Squats. Three sets. '
              'Feet shoulder-width apart, toes turned out slightly — about fifteen to thirty degrees. '
              'Initiate by pushing your hips back, then bending your knees. '
              'Descend until your hip crease drops below your kneecap — that is full depth. '
              'Your knees should track over your toes, not cave inward. '
              'Drive through your entire foot to stand — squeeze your glutes at the top. '
              'Arms can extend forward for counterbalance. Breathe in on the way down, out on the way up.',
          estimatedDuration: Duration(seconds: 20),
        ),
        PlanStep.wait(id: 'fbs_w_ex2_intro', duration: Duration(seconds: 5)),
        PlanStep.play(id: 'fbs_ex2_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex2_s1',
          text: 'Set one — go. Sit deep. Chest up. Drive through your heels.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex2_s1', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex2_r1', text: 'Rest. Fifteen seconds.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex2_r1', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex2_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex2_s2',
          text: 'Set two — go. Full depth every rep. No half squats.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex2_s2', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex2_r2', text: 'Rest. One more.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex2_r2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex2_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex2_s3',
          text: 'Final set — squats. Try to add a one-second pause at the bottom of each rep. Earn it.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex2_s3', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex2_done',
          text: 'Squats complete. Thirty-second transition.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex2_trans', duration: Duration(seconds: 30)),

        // ── Exercise 3: Glute Bridges ────────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex3_intro',
          text:
              'Exercise three — Glute Bridges. Lie on your back. Three sets. '
              'Bend your knees so your feet are flat on the floor, hip-width apart, '
              'about six inches from your glutes. Arms at your sides, palms down. '
              'Press through your heels and lift your hips until your body forms a straight line '
              'from shoulders to knees. Squeeze your glutes hard at the top for a full second. '
              'Lower slowly — do not just drop. '
              'Keep your ribs down — do not hyperextend your lower back. '
              'Your core should stay engaged throughout.',
          estimatedDuration: Duration(seconds: 20),
        ),
        PlanStep.wait(id: 'fbs_w_ex3_intro', duration: Duration(seconds: 8)),
        PlanStep.play(id: 'fbs_ex3_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex3_s1',
          text: 'Set one — go. Drive hips up. Squeeze at the top. Control the descent.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex3_s1', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex3_r1', text: 'Rest. Stay on the floor. Fifteen seconds.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'fbs_w_ex3_r1', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex3_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex3_s2',
          text: 'Set two — go. Two-second squeeze at the top this time.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex3_s2', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex3_r2', text: 'Rest.', estimatedDuration: Duration(seconds: 1)),
        PlanStep.wait(id: 'fbs_w_ex3_r2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex3_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex3_s3',
          text: 'Final set — glute bridges. Slow three-second lowering on each rep. Feel the burn.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex3_s3', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex3_done',
          text: 'Glute bridges done. Stand up for the next exercise. Thirty-second break.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex3_trans', duration: Duration(seconds: 30)),

        // ── Exercise 4: Plank Hold ───────────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex4_intro',
          text:
              'Exercise four — Plank Hold. Three sets. '
              'Get into a forearm plank position. Elbows directly under your shoulders. '
              'Forearms parallel, or clasp your hands if that feels more stable. '
              'Your body should form a rigid straight line from the crown of your head to your heels. '
              'Tuck your pelvis slightly to flatten your lower back — no sag, no pike. '
              'Push the floor away with your forearms so your upper back is not sagging between your shoulder blades. '
              'Breathe steadily — do not hold your breath. Squeeze your quads and glutes. '
              'If you start to shake, that is your body building strength. Hold through it.',
          estimatedDuration: Duration(seconds: 22),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_intro', duration: Duration(seconds: 5)),
        PlanStep.play(id: 'fbs_ex4_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex4_s1',
          text: 'Set one — hold. Lock in your position. Breathe.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_s1', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex4_r1',
          text: 'Release. Drop to your knees. Breathe. Fifteen seconds.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_r1', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex4_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex4_s2',
          text: 'Set two — hold. Hips level. Core braced. Eyes on the floor just ahead of your hands.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_s2', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex4_r2', text: 'Release. Rest.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex4_r2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex4_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex4_s3',
          text: 'Final set — plank. Forty-five seconds. This is mental now. You are stronger than the discomfort.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_s3', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex4_done',
          text: 'Planks done. Stand up. Shake it out. Thirty-second break.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex4_trans', duration: Duration(seconds: 30)),

        // ── Exercise 5: Reverse Lunges ───────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex5_intro',
          text:
              'Exercise five — Alternating Reverse Lunges. Three sets. '
              'Stand tall, hands on your hips or arms at your sides. '
              'Step your right foot straight back about two to three feet. '
              'Lower your right knee until it hovers one inch above the floor. '
              'Your front shin should be vertical — left knee directly above your left ankle. '
              'Push through the heel of your front foot to return to standing. '
              'Alternate legs each rep. Keep your torso upright — do not lean forward. '
              'Reverse lunges are easier on the knees than forward lunges because the deceleration '
              'happens on the back leg instead of the front.',
          estimatedDuration: Duration(seconds: 22),
        ),
        PlanStep.wait(id: 'fbs_w_ex5_intro', duration: Duration(seconds: 5)),
        PlanStep.play(id: 'fbs_ex5_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex5_s1',
          text: 'Set one — go. Step back, drop low, drive up. Alternate.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex5_s1', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex5_r1', text: 'Rest. Fifteen seconds.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex5_r1', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex5_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex5_s2',
          text: 'Set two — go. Keep your torso tall. No wobbling. Own the movement.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex5_s2', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex5_r2', text: 'Rest. One more.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex5_r2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex5_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex5_s3',
          text: 'Final set — lunges. Slow descent, explosive return. Every rep counts.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex5_s3', duration: Duration(seconds: 45)),
        PlanStep.say(
          id: 'fbs_s_ex5_done',
          text: 'Lunges complete. One exercise left. Thirty seconds.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'fbs_w_ex5_trans', duration: Duration(seconds: 30)),

        // ── Exercise 6: Tricep Dips ──────────────────────────────────────────
        PlanStep.say(
          id: 'fbs_s_ex6_intro',
          text:
              'Exercise six — Tricep Dips. Final exercise. Three sets. '
              'Sit on the edge of a sturdy chair, bench, or low table. '
              'Place your hands on the edge beside your hips, fingers wrapping over the front. '
              'Walk your feet out so your hips are off the seat, knees bent at about ninety degrees. '
              'For more challenge, extend your legs straight out. '
              'Lower your body by bending your elbows straight back — not flared out to the sides. '
              'Go down until your upper arms are parallel to the floor, then press back up. '
              'Keep your back close to the chair — do not drift forward. '
              'Shoulders stay down and away from your ears.',
          estimatedDuration: Duration(seconds: 22),
        ),
        PlanStep.wait(id: 'fbs_w_ex6_intro', duration: Duration(seconds: 5)),
        PlanStep.play(id: 'fbs_ex6_s1_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex6_s1',
          text: 'Set one — go. Elbows back. Lower with control. Press up strong.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'fbs_w_ex6_s1', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex6_r1', text: 'Rest. Fifteen seconds.', estimatedDuration: Duration(seconds: 2)),
        PlanStep.wait(id: 'fbs_w_ex6_r1', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex6_s2_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex6_s2',
          text: 'Set two — go. Steady pace. Full range of motion.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'fbs_w_ex6_s2', duration: Duration(seconds: 45)),
        PlanStep.say(id: 'fbs_s_ex6_r2', text: 'Rest. Last set coming up.', estimatedDuration: Duration(seconds: 3)),
        PlanStep.wait(id: 'fbs_w_ex6_r2', duration: Duration(seconds: 15)),
        PlanStep.play(id: 'fbs_ex6_s3_bell', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'fbs_s_ex6_s3',
          text: 'Final set — tricep dips. Last forty-five seconds of the circuit. Leave nothing in the tank.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'fbs_w_ex6_s3', duration: Duration(seconds: 45)),

        PlanStep.play(id: 'fbs_gong_circuit', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'fbs_s_circuit_done',
          text:
              'Circuit complete. Eighteen sets. Outstanding work. '
              'Grab some water. We move into the cooldown in thirty seconds.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'fbs_w_circuit_trans', duration: Duration(seconds: 30)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 3: GUIDED COOLDOWN STRETCH (5 min) ────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(
          id: 'fbs_p_cd',
          audioAssetKey: kAmbientForest,
          loop: true,
          fadeInMs: 2000,
          volume: 0.35,
        ),
        PlanStep.say(
          id: 'fbs_s_cd_intro',
          text:
              'Phase three — cooldown. Five minutes of static stretching to bring your heart rate down '
              'and start recovery. Hold each stretch for thirty seconds. Breathe deeply into each position. '
              'No bouncing — just a steady, gentle pull.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'fbs_w_cd_intro', duration: Duration(seconds: 5)),

        // Stretch 1: Standing quad stretch
        PlanStep.say(
          id: 'fbs_s_cd1',
          text:
              'Standing quad stretch. Stand on your left leg. '
              'Grab your right ankle behind you with your right hand. '
              'Pull your heel toward your glute. Keep your knees together. '
              'Stand tall — push your hips slightly forward to deepen the stretch. '
              'Hold for thirty seconds, then switch legs.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'fbs_w_cd1', duration: Duration(seconds: 60)),

        // Stretch 2: Standing hamstring fold
        PlanStep.play(id: 'fbs_cd2_chime', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_cd2',
          text:
              'Standing forward fold. Feet hip-width apart. '
              'Bend forward from your hips. Let your head and arms hang heavy. '
              'Soften your knees slightly. Feel the stretch along the back of your legs. '
              'Let gravity do the work. Breathe into your hamstrings.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'fbs_w_cd2', duration: Duration(seconds: 35)),

        // Stretch 3: Chest doorway stretch
        PlanStep.play(id: 'fbs_cd3_chime', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_cd3',
          text:
              'Chest and shoulder stretch. Stand in a doorway or extend your right arm against a wall. '
              'Place your forearm flat against the wall at shoulder height. '
              'Rotate your body away until you feel a deep stretch across your chest and front shoulder. '
              'Thirty seconds each side.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'fbs_w_cd3', duration: Duration(seconds: 65)),

        // Stretch 4: Hip flexor lunge stretch
        PlanStep.play(id: 'fbs_cd4_chime', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_cd4',
          text:
              'Hip flexor stretch. Drop into a low lunge — right foot forward, left knee on the ground. '
              'Tuck your pelvis under and lean forward slightly until you feel a deep stretch in the front of your left hip. '
              'Raise your left arm overhead and lean gently to the right to intensify the stretch. '
              'Hold for thirty seconds, then switch sides.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'fbs_w_cd4', duration: Duration(seconds: 65)),

        // Stretch 5: Child's pose
        PlanStep.play(id: 'fbs_cd5_chime', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'fbs_s_cd5',
          text:
              'Finally, Child\'s Pose. Kneel on the floor. Sit your hips back onto your heels. '
              'Walk your hands forward and lower your forehead to the ground. '
              'Arms extended, shoulders relaxed. Breathe deeply into your lower back. '
              'This is your reward. Rest here.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'fbs_w_cd5', duration: Duration(seconds: 40)),

        // ── Session Complete ─────────────────────────────────────────────────
        PlanStep.play(id: 'fbs_gong_end', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'fbs_n2',
          title: 'Strength Circuit Complete!',
          body: 'Eighteen sets done. Strong work today.',
        ),
        PlanStep.say(
          id: 'fbs_s_end',
          text:
              'Full Body Strength Circuit complete. You warmed up properly, '
              'moved through eighteen working sets of six compound exercises, '
              'and cooled down with targeted stretches. '
              'Your muscles will thank you tomorrow. Rest well and stay hydrated.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'fbs_w_end', duration: Duration(seconds: 10)),
        PlanStep.stopAudio(id: 'fbs_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── ROUTINE ──────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── Morning Routine (~45 min) ────────────────────────────────────────────────

Plan _morningRoutine(DateTime now) => Plan(
      id: 0,
      name: 'Morning Routine',
      description:
          'A structured 45-minute morning ritual: hydration, gentle movement, '
          'cold-water face wash, mindful breakfast, journaling, and daily intention '
          'setting — with guided prompts throughout.',
      category: PlanCategory.routine,
      tags: const ['routine', 'morning', 'productivity', 'wellbeing', 'mindfulness'],
      defaultVoice: PlanVoice.aoede.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // ── Wake Up ──────────────────────────────────────────────────────────
        PlanStep.play(
          id: 'mr_p1',
          audioAssetKey: kAmbientForest,
          loop: true,
          fadeInMs: 5000,
          volume: 0.3,
        ),
        PlanStep.notify(
          id: 'mr_n1',
          title: 'Good Morning',
          body: 'Your 45-minute morning routine is starting',
        ),
        PlanStep.say(
          id: 'mr_s_welcome',
          text:
              'Good morning. This is your guided morning routine — forty-five minutes '
              'of deliberate actions to set the tone for your entire day. '
              'Each step is timed, so you never need to check the clock. '
              'Just follow my voice and move through each phase with intention. '
              'Let us begin.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'mr_w_welcome', duration: Duration(seconds: 8)),

        // ── Step 1: Hydration (2 min) ────────────────────────────────────────
        PlanStep.play(id: 'mr_bell_s1', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'mr_s_hydrate',
          text:
              'Step one — hydrate. Before anything else, drink a full glass of water. '
              'Your body has been fasting and dehydrating for seven to eight hours. '
              'Room temperature water is ideal — it is absorbed faster than cold water. '
              'If you have a lemon, squeeze half of it into the glass. '
              'The vitamin C and citric acid help kick-start your digestion. '
              'Take your time — drink the whole glass, not just a few sips.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_hydrate', duration: Duration(seconds: 90)),
        PlanStep.say(
          id: 'mr_s_hydrate_done',
          text: 'Glass finished. Good. You have already done more for yourself than most people do before noon.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'mr_w_hydrate_done', duration: Duration(seconds: 5)),

        // ── Step 2: Gentle Movement (7 min) ──────────────────────────────────
        PlanStep.play(id: 'mr_bell_s2', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n2',
          title: 'Step 2: Movement',
          body: '7 minutes of gentle stretching and mobility',
        ),
        PlanStep.say(
          id: 'mr_s_move_intro',
          text:
              'Step two — gentle movement. Seven minutes. '
              'This is not a workout — the goal is to wake up your body and undo the stiffness of sleep. '
              'We will do some simple stretches and mobility work. Stand up.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'mr_w_move_intro', duration: Duration(seconds: 10)),

        // Move: Neck & shoulders
        PlanStep.say(
          id: 'mr_s_move1',
          text:
              'Start with your neck. Drop your right ear toward your right shoulder. '
              'Hold for five breaths. You should feel a gentle stretch on the left side of your neck. '
              'Now the other side — left ear toward left shoulder. Five breaths. '
              'Then roll your shoulders — five big circles forward, five backward. '
              'Let the tension melt away.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_move1', duration: Duration(seconds: 60)),

        // Move: Spine
        PlanStep.play(id: 'mr_chime_m2', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'mr_s_move2',
          text:
              'Now your spine. Stand with feet hip-width apart. '
              'Place your hands on your lower back. Gently arch backward — '
              'open your chest to the ceiling. Hold for three breaths. '
              'Then fold forward — let your head and arms hang. '
              'Bend your knees as much as you need. Breathe into your lower back. '
              'Slowly roll back up, one vertebra at a time, head comes up last.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_move2', duration: Duration(seconds: 60)),

        // Move: Hips & legs
        PlanStep.play(id: 'mr_chime_m3', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'mr_s_move3',
          text:
              'Hip and leg mobility. Do five slow bodyweight squats — go as deep as comfortable. '
              'Then stand on one leg and swing the other forward and back ten times. Switch legs. '
              'Finally, do a standing figure-four stretch — cross your right ankle over your left knee, '
              'sit back into a half-squat and hold for five breaths. Switch sides. '
              'This opens up the glutes and piriformis.',
          estimatedDuration: Duration(seconds: 16),
        ),
        PlanStep.wait(id: 'mr_w_move3', duration: Duration(seconds: 90)),

        // Move: Deep breathing
        PlanStep.play(id: 'mr_chime_m4', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'mr_s_move4',
          text:
              'Stand tall. Feet grounded. Take five deep breaths. '
              'Inhale through your nose for four counts. Hold for four counts. '
              'Exhale through your mouth for six counts. '
              'Let each exhale be longer and slower than the last. '
              'This activates your parasympathetic nervous system and sets a calm, focused tone.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'mr_w_move4', duration: Duration(seconds: 70)),

        PlanStep.say(
          id: 'mr_s_move_done',
          text: 'Movement done. Your body is awake. You should feel looser, warmer, and more alert.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'mr_w_move_done', duration: Duration(seconds: 5)),

        // ── Step 3: Cold Water & Hygiene (8 min) ─────────────────────────────
        PlanStep.play(id: 'mr_bell_s3', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n3',
          title: 'Step 3: Freshen Up',
          body: '8 minutes — cold water splash, brush, and get ready',
        ),
        PlanStep.say(
          id: 'mr_s_hygiene',
          text:
              'Step three — freshen up. Head to the bathroom. '
              'Start by splashing cold water on your face — ten to fifteen splashes. '
              'Cold water increases alertness, constricts blood vessels to reduce puffiness, '
              'and triggers the dive reflex which calms your nervous system. '
              'Then brush your teeth thoroughly for two minutes — '
              'thirty seconds per quadrant. Use your non-dominant hand if you want a cognitive challenge. '
              'Shower if you like, or save it for later. '
              'You have eight minutes total for this step.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'mr_w_hygiene', duration: Duration(minutes: 8)),

        PlanStep.play(id: 'mr_bell_s3_done', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'mr_s_hygiene_done',
          text: 'Hygiene done. You are fresh. On to breakfast.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'mr_w_hygiene_done', duration: Duration(seconds: 5)),

        // ── Step 4: Mindful Breakfast (15 min) ───────────────────────────────
        PlanStep.play(id: 'mr_bell_s4', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n4',
          title: 'Step 4: Breakfast',
          body: '15 minutes — prepare and eat mindfully',
        ),
        PlanStep.say(
          id: 'mr_s_food_intro',
          text:
              'Step four — mindful breakfast. Fifteen minutes. '
              'This is not about speed — it is about nourishment and presence. '
              'Choose something with protein, healthy fat, and complex carbohydrates. '
              'Eggs with whole grain toast and avocado. Greek yogurt with nuts and berries. '
              'Oatmeal with banana and peanut butter. Whatever works for you. '
              'Avoid scrolling your phone while eating. '
              'Focus on the taste, the texture, and the act of chewing. '
              'Eating without distraction improves digestion and satisfaction.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'mr_w_food_prep', duration: Duration(minutes: 5)),

        PlanStep.say(
          id: 'mr_s_food_mid',
          text:
              'Five minutes in. You should be eating by now. '
              'Chew slowly. Put your fork down between bites. '
              'Notice the flavors. This is a small act of mindfulness that compounds over time.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'mr_w_food_mid', duration: Duration(minutes: 5)),

        PlanStep.say(
          id: 'mr_s_food_wrap',
          text:
              'Five more minutes. Finish eating and clean up your plate and utensils. '
              'A clean kitchen sets a clean mental state.',
          estimatedDuration: Duration(seconds: 6),
        ),
        PlanStep.wait(id: 'mr_w_food_wrap', duration: Duration(minutes: 5)),

        PlanStep.say(
          id: 'mr_s_food_done',
          text: 'Breakfast complete. You are fueled.',
          estimatedDuration: Duration(seconds: 3),
        ),
        PlanStep.wait(id: 'mr_w_food_done', duration: Duration(seconds: 5)),

        // ── Step 5: Journaling (8 min) ───────────────────────────────────────
        PlanStep.play(id: 'mr_bell_s5', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n5',
          title: 'Step 5: Journal',
          body: '8 minutes of freewriting and gratitude',
        ),
        PlanStep.say(
          id: 'mr_s_journal_intro',
          text:
              'Step five — journaling. Eight minutes. Grab a notebook or open a notes app. '
              'We will do two short exercises.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'mr_w_journal_intro', duration: Duration(seconds: 10)),

        // Journal: Gratitude
        PlanStep.say(
          id: 'mr_s_journal1',
          text:
              'First — gratitude. Write down three things you are genuinely grateful for right now. '
              'They do not need to be grand — a good night\'s sleep, a friend who checked in, '
              'the fact that you are alive and choosing to invest in yourself this morning. '
              'Be specific. Instead of just writing "my health", write exactly what about your health '
              'you are grateful for today. Specificity is where the power lives. '
              'Take three minutes.',
          estimatedDuration: Duration(seconds: 16),
        ),
        PlanStep.wait(id: 'mr_w_journal1', duration: Duration(minutes: 3)),

        // Journal: Free write
        PlanStep.play(id: 'mr_chime_j2', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'mr_s_journal2',
          text:
              'Now — freewriting. For four minutes, write whatever comes to mind. '
              'Stream of consciousness. Do not edit, do not judge, do not stop writing. '
              'If you run out of things to say, write "I don\'t know what to write" until something comes. '
              'This practice clears mental fog, surfaces hidden anxieties, and often produces '
              'surprisingly useful insights. Pen moving. Go.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_journal2', duration: Duration(minutes: 4)),

        PlanStep.play(id: 'mr_chime_j3', audioAssetKey: kEffectChime, loop: false),
        PlanStep.say(
          id: 'mr_s_journal_done',
          text: 'Pens down. Close the notebook. That reflection is now working in the background of your mind.',
          estimatedDuration: Duration(seconds: 5),
        ),
        PlanStep.wait(id: 'mr_w_journal_done', duration: Duration(seconds: 8)),

        // ── Step 6: Daily Intention (5 min) ──────────────────────────────────
        PlanStep.play(id: 'mr_bell_s6', audioAssetKey: kEffectBell, loop: false),
        PlanStep.notify(
          id: 'mr_n6',
          title: 'Step 6: Set Your Intention',
          body: 'What is the one thing that matters most today?',
        ),
        PlanStep.say(
          id: 'mr_s_intent_intro',
          text:
              'Final step — set your daily intention. Five minutes. '
              'This is the most important part of the routine. '
              'Ask yourself: what is the single most important thing I can accomplish today? '
              'Not a to-do list — one thing. The one thing that, if done, would make today a success '
              'even if nothing else got done.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_intent1', duration: Duration(seconds: 60)),

        PlanStep.say(
          id: 'mr_s_intent2',
          text:
              'Write it down. One sentence. Make it specific and actionable. '
              'Not "work on the project" — instead, "finish the draft of section three and send it for review." '
              'Clear targets drive clear action.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'mr_w_intent2', duration: Duration(seconds: 60)),

        PlanStep.say(
          id: 'mr_s_intent3',
          text:
              'Now close your eyes for a moment. Visualize yourself completing that one thing. '
              'See yourself sitting down, doing the work, finishing it. '
              'Feel the satisfaction of crossing it off. '
              'Open your eyes. You know what today is about.',
          estimatedDuration: Duration(seconds: 10),
        ),
        PlanStep.wait(id: 'mr_w_intent3', duration: Duration(seconds: 60)),

        // ── Routine Complete ─────────────────────────────────────────────────
        PlanStep.play(id: 'mr_gong_end', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'mr_n7',
          title: 'Morning Routine Complete!',
          body: 'Hydrated, moved, clean, fed, journaled, focused. Go get it.',
        ),
        PlanStep.say(
          id: 'mr_s_end',
          text:
              'Morning routine complete. In forty-five minutes you have hydrated your body, '
              'woken up your muscles and joints, freshened up, eaten a proper breakfast, '
              'cleared your mind through writing, and set a focused intention for the day. '
              'You are prepared. You are present. Go make today count.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'mr_w_end', duration: Duration(seconds: 10)),
        PlanStep.stopAudio(id: 'mr_sa1'),
      ],
    );

// ---------------------------------------------------------------------------
// ── FOCUS ────────────────────────────────────────────────────────────────────
// ---------------------------------------------------------------------------

// ── Deep Work Session (~2 hours) ─────────────────────────────────────────────

Plan _deepWorkSession(DateTime now) => Plan(
      id: 0,
      name: 'Deep Work Session',
      description:
          'A guided 2-hour deep work session: environment setup ritual, '
          'two 50-minute focus blocks with a 10-minute active recovery break, '
          'progress check-ins, and a closing reflection.',
      category: PlanCategory.focus,
      tags: const ['focus', 'deep work', 'productivity', 'flow', 'work'],
      defaultVoice: PlanVoice.puck.name,
      createdAt: now,
      updatedAt: now,
      steps: const [
        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 0: ENVIRONMENT SETUP RITUAL (3 min) ───────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.notify(
          id: 'dw_n1',
          title: 'Deep Work Session',
          body: '2 hours of guided focus — prepare your environment',
        ),
        PlanStep.say(
          id: 'dw_s_welcome',
          text:
              'Deep work session. Two hours. Two blocks of fifty minutes separated by '
              'a ten-minute active recovery break. Before we start the clock, '
              'we will spend three minutes preparing your environment. '
              'Research shows that a deliberate setup ritual signals your brain to transition into focus mode. '
              'Let us begin.',
          estimatedDuration: Duration(seconds: 14),
        ),
        PlanStep.wait(id: 'dw_w_welcome', duration: Duration(seconds: 8)),

        // Setup: Digital
        PlanStep.say(
          id: 'dw_s_setup1',
          text:
              'First — digital environment. Put your phone on Do Not Disturb or, even better, '
              'leave it in another room entirely. Close every browser tab that is not directly '
              'related to the task you are about to do. Close Slack, email, social media — all of it. '
              'If you need any of those for your work, keep only the specific tab you need. '
              'Every open tab is a potential interruption. Every notification is a context switch '
              'that costs you fifteen to twenty minutes of refocusing time.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'dw_w_setup1', duration: Duration(seconds: 30)),

        // Setup: Physical
        PlanStep.say(
          id: 'dw_s_setup2',
          text:
              'Now — physical environment. Fill a water bottle and place it within arm\'s reach '
              'so you will not need to get up for hydration. '
              'Clear your desk of anything unrelated to the work. '
              'Clutter creates cognitive overhead even when you think you are ignoring it. '
              'If you use noise-cancelling headphones, put them on now. '
              'Adjust your chair height so your feet are flat on the floor and your eyes '
              'are level with the top third of your screen.',
          estimatedDuration: Duration(seconds: 16),
        ),
        PlanStep.wait(id: 'dw_w_setup2', duration: Duration(seconds: 30)),

        // Setup: Task clarity
        PlanStep.say(
          id: 'dw_s_setup3',
          text:
              'Finally — task clarity. In your head or on paper, answer this question: '
              'What specifically will I have produced by the end of these two hours? '
              'Not "work on the report" — instead, "complete the first draft of sections two and three." '
              'Not "study" — instead, "work through problems one through fifteen in chapter four." '
              'A clear target eliminates decision fatigue during the session. '
              'Take fifteen seconds to define your target now.',
          estimatedDuration: Duration(seconds: 18),
        ),
        PlanStep.wait(id: 'dw_w_setup3', duration: Duration(seconds: 20)),

        PlanStep.say(
          id: 'dw_s_setup_done',
          text: 'Environment is set. Target is clear. The session begins now.',
          estimatedDuration: Duration(seconds: 4),
        ),
        PlanStep.wait(id: 'dw_w_setup_done', duration: Duration(seconds: 5)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 1: FOCUS BLOCK 1 (50 min) ─────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(
          id: 'dw_p1',
          audioAssetKey: kAmbientWhiteNoise,
          loop: true,
          fadeInMs: 2000,
          volume: 0.3,
        ),
        PlanStep.play(id: 'dw_gong1', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'dw_n2',
          title: 'Block 1 — Go',
          body: '50 minutes of uninterrupted focus',
        ),
        PlanStep.say(
          id: 'dw_s_b1_start',
          text:
              'Block one. Fifty minutes. The white noise will stay in the background to mask distractions. '
              'If your mind wanders — and it will — just notice it and gently return to the task. '
              'Do not judge the wandering. The return is the practice. Begin working now.',
          estimatedDuration: Duration(seconds: 12),
        ),

        // 15 min in — check-in
        PlanStep.wait(id: 'dw_w_b1_1', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b1_check1',
          text:
              'Fifteen minutes in. Quick check — are you still on your primary task? '
              'If you have drifted to something else, gently redirect now. '
              'No guilt, just redirect. Keep going.',
          estimatedDuration: Duration(seconds: 8),
        ),

        // 30 min in — check-in
        PlanStep.wait(id: 'dw_w_b1_2', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b1_check2',
          text:
              'Thirty minutes. You are past the halfway point of block one. '
              'Take three slow, deep breaths without stopping your work. '
              'In through your nose, out through your mouth. '
              'This resets your nervous system without breaking flow.',
          estimatedDuration: Duration(seconds: 10),
        ),

        // 45 min in — nearly done
        PlanStep.wait(id: 'dw_w_b1_3', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b1_check3',
          text: 'Forty-five minutes. Five more minutes in this block. Finish your current thought.',
          estimatedDuration: Duration(seconds: 5),
        ),

        // Block 1 complete
        PlanStep.wait(id: 'dw_w_b1_4', duration: Duration(minutes: 5)),
        PlanStep.play(id: 'dw_gong_b1_end', audioAssetKey: kEffectGong, loop: false),
        PlanStep.stopAudio(id: 'dw_sa1'),
        PlanStep.notify(
          id: 'dw_n3',
          title: 'Block 1 Complete — Break Time',
          body: '10-minute active recovery. Step away from your screen.',
        ),
        PlanStep.say(
          id: 'dw_s_b1_end',
          text:
              'Block one complete. Fifty minutes of focused work. Well done. '
              'Now — a ten-minute active recovery break. This is not optional. '
              'Your brain consolidates and processes information during rest periods. '
              'Skipping the break actually makes the second block worse, not better.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'dw_w_b1_end', duration: Duration(seconds: 5)),

        // ══════════════════════════════════════════════════════════════════════
        // ── BREAK (10 min) ──────────────────────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.say(
          id: 'dw_s_break_intro',
          text:
              'Stand up now. Step away from your desk completely. '
              'Here is what to do during this break: '
              'First two minutes — walk around. Get your blood flowing. '
              'If you can step outside for fresh air, even better. '
              'Minutes three through six — do some light stretching. '
              'Roll your neck, stretch your wrists, open your chest. '
              'Minutes seven through ten — refill your water. '
              'Use the bathroom if needed. '
              'Do not check your phone. Do not check email. '
              'Let your brain idle — that is when the best connections form.',
          estimatedDuration: Duration(seconds: 22),
        ),

        // Break: walk reminder
        PlanStep.wait(id: 'dw_w_break1', duration: Duration(minutes: 2)),
        PlanStep.say(
          id: 'dw_s_break_walk',
          text: 'Two minutes of walking done. Start your stretches. Wrists, neck, shoulders, chest.',
          estimatedDuration: Duration(seconds: 5),
        ),

        // Break: stretch reminder
        PlanStep.wait(id: 'dw_w_break2', duration: Duration(minutes: 4)),
        PlanStep.say(
          id: 'dw_s_break_stretch',
          text: 'Good stretching. Refill your water. Use the bathroom if needed. Two minutes left.',
          estimatedDuration: Duration(seconds: 5),
        ),

        // Break ending
        PlanStep.wait(id: 'dw_w_break3', duration: Duration(minutes: 2)),
        PlanStep.play(id: 'dw_bell_break_end', audioAssetKey: kEffectBell, loop: false),
        PlanStep.say(
          id: 'dw_s_break_warn',
          text: 'Two minutes left in the break. Start heading back to your desk.',
          estimatedDuration: Duration(seconds: 4),
        ),

        PlanStep.wait(id: 'dw_w_break4', duration: Duration(minutes: 2)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 2: FOCUS BLOCK 2 (50 min) ─────────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(
          id: 'dw_p2',
          audioAssetKey: kAmbientWhiteNoise,
          loop: true,
          fadeInMs: 2000,
          volume: 0.3,
        ),
        PlanStep.play(id: 'dw_gong2', audioAssetKey: kEffectGong, loop: false),
        PlanStep.notify(
          id: 'dw_n4',
          title: 'Block 2 — Go',
          body: '50 more minutes of deep focus',
        ),
        PlanStep.say(
          id: 'dw_s_b2_start',
          text:
              'Block two. Fifty minutes. Your brain is rested and primed. '
              'The second block often feels easier because your mind is already warmed up. '
              'Pick up exactly where you left off. Same target, same intensity. Begin.',
          estimatedDuration: Duration(seconds: 10),
        ),

        // 15 min in — check-in
        PlanStep.wait(id: 'dw_w_b2_1', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b2_check1',
          text: 'Fifteen minutes into block two. Sixty-five minutes of total focus today. Impressive. Keep going.',
          estimatedDuration: Duration(seconds: 6),
        ),

        // 30 min in — check-in
        PlanStep.wait(id: 'dw_w_b2_2', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b2_check2',
          text:
              'Thirty minutes. Eighty minutes of focused work today. '
              'You are in the final stretch. Sip some water if you haven\'t already.',
          estimatedDuration: Duration(seconds: 7),
        ),

        // 45 min in — nearly done
        PlanStep.wait(id: 'dw_w_b2_3', duration: Duration(minutes: 15)),
        PlanStep.say(
          id: 'dw_s_b2_check3',
          text: 'Forty-five minutes. Five more minutes. Finish strong. Wrap up your current task.',
          estimatedDuration: Duration(seconds: 5),
        ),

        // Block 2 complete
        PlanStep.wait(id: 'dw_w_b2_4', duration: Duration(minutes: 5)),

        // ══════════════════════════════════════════════════════════════════════
        // ── PHASE 3: CLOSING REFLECTION (3 min) ─────────────────────────────
        // ══════════════════════════════════════════════════════════════════════
        PlanStep.play(id: 'dw_gong_end', audioAssetKey: kEffectGong, loop: false),
        PlanStep.stopAudio(id: 'dw_sa2'),
        PlanStep.notify(
          id: 'dw_n5',
          title: 'Deep Work Session Complete!',
          body: '100 minutes of focused work. Time for reflection.',
        ),
        PlanStep.say(
          id: 'dw_s_reflect_intro',
          text:
              'One hundred minutes of deep, focused work. The session is over. '
              'Before you jump back into the noise, take three minutes to reflect. '
              'This is not a luxury — research shows that workers who reflect on their work '
              'perform twenty-three percent better than those who just move on.',
          estimatedDuration: Duration(seconds: 12),
        ),
        PlanStep.wait(id: 'dw_w_reflect_intro', duration: Duration(seconds: 5)),

        PlanStep.say(
          id: 'dw_s_reflect1',
          text:
              'First — what did you accomplish? Jot down a one-sentence summary of what you produced. '
              'This creates a record of progress and makes future planning more accurate.',
          estimatedDuration: Duration(seconds: 8),
        ),
        PlanStep.wait(id: 'dw_w_reflect1', duration: Duration(seconds: 40)),

        PlanStep.say(
          id: 'dw_s_reflect2',
          text:
              'Second — what was the hardest part? Where did you get stuck? '
              'Naming the friction point helps you prepare for it next time.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'dw_w_reflect2', duration: Duration(seconds: 40)),

        PlanStep.say(
          id: 'dw_s_reflect3',
          text:
              'Third — what is the very next action to continue this work? '
              'Write it down so that the next session can start immediately without re-orienting.',
          estimatedDuration: Duration(seconds: 7),
        ),
        PlanStep.wait(id: 'dw_w_reflect3', duration: Duration(seconds: 40)),

        // ── Session Complete ─────────────────────────────────────────────────
        PlanStep.play(id: 'dw_gong_final', audioAssetKey: kEffectGong, loop: false),
        PlanStep.say(
          id: 'dw_s_end',
          text:
              'Deep work session complete. One hundred minutes of concentrated, '
              'uninterrupted effort. That is more focused work than most people achieve '
              'in an entire day of distracted multitasking. '
              'You should feel proud of that. Rest your eyes, stretch, and take a proper break. '
              'You have earned it.',
          estimatedDuration: Duration(seconds: 14),
        ),
      ],
    );
