/**
 * Seed script — inserts 5 curated starter plans into the library_plans table.
 *
 * Usage (from /server):
 *   pnpm seed:library-plans
 *   # or directly:
 *   ts-node -r tsconfig-paths/register scripts/seed-library-plans.ts
 *
 * Safe to run multiple times: exits early if rows already exist.
 */

import 'dotenv/config';
import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { sql } from 'drizzle-orm';
import { libraryPlans } from '../src/database/schema';

// ---------------------------------------------------------------------------
// DB connection
// ---------------------------------------------------------------------------

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  console.error('ERROR: DATABASE_URL environment variable is not set.');
  process.exit(1);
}

const sqlClient = neon(databaseUrl);
const db = drizzle(sqlClient);

// ---------------------------------------------------------------------------
// Step type helpers
// ---------------------------------------------------------------------------

const S = 1_000_000; // 1 second in microseconds

function say(
  id: string,
  text: string,
  estimatedDurationSeconds: number | null = null,
): object {
  return {
    runtimeType: 'say',
    id,
    text,
    voiceId: null,
    estimatedDuration: estimatedDurationSeconds !== null ? estimatedDurationSeconds * S : null,
  };
}

function wait(id: string, durationSeconds: number): object {
  return { runtimeType: 'wait', id, duration: durationSeconds * S };
}

function play(
  id: string,
  audioAssetKey: string,
  loop: boolean,
  volume: number = 1.0,
  fadeInMs: number = 0,
  fadeOutMs: number = 0,
): object {
  return { runtimeType: 'play', id, audioAssetKey, loop, volume, fadeInMs, fadeOutMs };
}

function notify(id: string, title: string, body: string): object {
  return { runtimeType: 'notify', id, title, body };
}

function repeat(id: string, count: number, children: object[]): object {
  return { runtimeType: 'repeat', id, count, children };
}

function stopAudio(id: string): object {
  return { runtimeType: 'stopAudio', id };
}

// ---------------------------------------------------------------------------
// Audio asset keys (matches app/lib/data/audio_assets.dart)
// ---------------------------------------------------------------------------

const kAmbientForest = 'forest';
const kAmbientOcean = 'ocean';
const kAmbientWhiteNoise = 'white_noise';
const kEffectBell = 'bell';
const kEffectChime = 'chime';
const kEffectGong = 'gong';

// ---------------------------------------------------------------------------
// Plan 1 — 108 Surya Namaskar Series (~90 min, yoga)
// ---------------------------------------------------------------------------

const plan1Steps: object[] = [
  // Setup
  play('sn108_p1', kAmbientForest, true, 0.4, 3000),
  notify('sn108_n1', '108 Surya Namaskar', 'Unroll your mat — your 108 round journey begins now'),
  say(
    'sn108_s_welcome',
    'Welcome to the 108 Surya Namaskar practice. This is a sacred, ' +
      'endurance-building sequence. We will move through one hundred and eight ' +
      'rounds of Sun Salutation together. The first five rounds are fully guided ' +
      'so you can settle into the rhythm. After that, I will sound a chime at the ' +
      'start of each round and you will move at your own pace. ' +
      'Stand at the front of your mat. Close your eyes. Take three deep breaths ' +
      'to set your intention.',
    18,
  ),
  wait('sn108_w_setup', 20),

  // ROUND 1 (Right leg leads — fully guided)
  play('sn108_r1_gong', kEffectGong, false),
  say('sn108_r1_s0', 'Round one. Right leg leads.', 3),
  wait('sn108_r1_w0', 3),
  say(
    'sn108_r1_s1',
    'Pranamasana — Prayer Pose. Stand tall, feet together. ' +
      'Bring your palms together at heart center. Close your eyes. Exhale completely.',
    7,
  ),
  wait('sn108_r1_w1', 8),
  say(
    'sn108_r1_s2',
    'Hasta Uttanasana — Raised Arms. Inhale, sweep your arms overhead. ' +
      'Arch your back gently. Push your pelvis forward. Biceps beside your ears.',
    7,
  ),
  wait('sn108_r1_w2', 8),
  say(
    'sn108_r1_s3',
    'Hastapadasana — Standing Forward Bend. Exhale, fold forward from the hips. ' +
      'Keep your spine long. Bring your hands to the floor beside your feet. ' +
      'Soften your knees if needed.',
    7,
  ),
  wait('sn108_r1_w3', 8),
  say(
    'sn108_r1_s4',
    'Ashwa Sanchalanasana — Equestrian Pose. Inhale, step your right leg far back. ' +
      'Right knee to the floor. Left knee bends at ninety degrees. ' +
      'Chest open, look up.',
    7,
  ),
  wait('sn108_r1_w4', 8),
  say(
    'sn108_r1_s5',
    'Dandasana — Plank Pose. Breathe in, step your left foot back. ' +
      'Body forms one straight line from head to heels. ' +
      'Arms perpendicular to the floor. Core engaged.',
    7,
  ),
  wait('sn108_r1_w5', 8),
  say(
    'sn108_r1_s6',
    'Ashtanga Namaskara — Eight Limbed Salute. Exhale, gently lower your knees, ' +
      'then chest, then chin to the floor. Hips stay slightly lifted. ' +
      'Eight points touch the ground — two palms, two knees, chest, chin, two feet.',
    9,
  ),
  wait('sn108_r1_w6', 6),
  say(
    'sn108_r1_s7',
    'Bhujangasana — Cobra Pose. Inhale, slide forward and raise your chest. ' +
      'Elbows slightly bent, shoulders away from ears. ' +
      'Open your heart. Look gently upward.',
    7,
  ),
  wait('sn108_r1_w7', 8),
  say(
    'sn108_r1_s8',
    'Adho Mukha Svanasana — Downward Facing Dog. Exhale, lift your hips high. ' +
      'Push the floor away. Spread your fingers wide. ' +
      'Press your heels toward the mat. Hold for five breaths.',
    8,
  ),
  wait('sn108_r1_w8', 20),
  say(
    'sn108_r1_s9',
    'Ashwa Sanchalanasana — Equestrian Pose. Inhale, step your right foot forward ' +
      'between your hands. Left knee rests on the floor. Chest lifts, gaze up.',
    7,
  ),
  wait('sn108_r1_w9', 8),
  say(
    'sn108_r1_s10',
    'Hastapadasana — Standing Forward Bend. Exhale, step your left foot forward ' +
      'to meet your right. Fold from the hips. Hands beside your feet.',
    6,
  ),
  wait('sn108_r1_w10', 6),
  say(
    'sn108_r1_s11',
    'Hasta Uttanasana — Raised Arms. Inhale, rise with a flat back. ' +
      'Arms sweep overhead. Gentle back bend.',
    5,
  ),
  wait('sn108_r1_w11', 6),
  say(
    'sn108_r1_s12',
    'Pranamasana — Prayer Pose. Exhale, stand tall. ' +
      'Palms together at heart center. Round one complete.',
    5,
  ),
  wait('sn108_r1_w12', 5),

  // ROUND 2 (Left leg leads — fully guided)
  play('sn108_r2_chime', kEffectChime, false),
  say('sn108_r2_s0', 'Round two. Left leg leads this time.', 3),
  wait('sn108_r2_w0', 3),
  say('sn108_r2_s1', 'Pranamasana. Palms at heart. Exhale.', 4),
  wait('sn108_r2_w1', 6),
  say('sn108_r2_s2', 'Hasta Uttanasana. Inhale, arms up, arch back.', 4),
  wait('sn108_r2_w2', 6),
  say('sn108_r2_s3', 'Hastapadasana. Exhale, fold forward. Hands beside feet.', 4),
  wait('sn108_r2_w3', 6),
  say(
    'sn108_r2_s4',
    'Ashwa Sanchalanasana. Inhale, step your left leg far back this time. ' +
      'Left knee to the floor. Right knee bends. Look up.',
    6,
  ),
  wait('sn108_r2_w4', 7),
  say('sn108_r2_s5', 'Dandasana. Step back to Plank. One strong line.', 4),
  wait('sn108_r2_w5', 7),
  say('sn108_r2_s6', 'Ashtanga Namaskara. Lower knees, chest, chin. Hips lifted.', 4),
  wait('sn108_r2_w6', 5),
  say('sn108_r2_s7', 'Bhujangasana. Slide forward, lift chest. Cobra.', 4),
  wait('sn108_r2_w7', 7),
  say('sn108_r2_s8', 'Adho Mukha Svanasana. Hips up, Downward Dog. Five breaths.', 4),
  wait('sn108_r2_w8', 18),
  say('sn108_r2_s9', 'Ashwa Sanchalanasana. Left foot forward between your hands. Right knee down.', 5),
  wait('sn108_r2_w9', 7),
  say('sn108_r2_s10', 'Hastapadasana. Step forward and fold.', 3),
  wait('sn108_r2_w10', 5),
  say('sn108_r2_s11', 'Hasta Uttanasana. Rise up, arms overhead, gentle back bend.', 4),
  wait('sn108_r2_w11', 5),
  say('sn108_r2_s12', 'Pranamasana. Exhale, palms to heart. Round two complete.', 4),
  wait('sn108_r2_w12', 5),

  // ROUNDS 3–5 (Fully guided, repeated x3)
  repeat('sn108_r3to5', 3, [
    play('sn108_r3to5_chime', kEffectChime, false),
    say('sn108_r3to5_s0', 'Next round. Alternate your leading leg.', 3),
    wait('sn108_r3to5_w0', 2),
    say('sn108_r3to5_s1', 'Pranamasana. Palms together, exhale.', 3),
    wait('sn108_r3to5_w1', 5),
    say('sn108_r3to5_s2', 'Hasta Uttanasana. Inhale, arms up and back.', 3),
    wait('sn108_r3to5_w2', 5),
    say('sn108_r3to5_s3', 'Hastapadasana. Exhale, fold forward.', 3),
    wait('sn108_r3to5_w3', 5),
    say('sn108_r3to5_s4', 'Ashwa Sanchalanasana. Step one leg back, lunge. Inhale.', 4),
    wait('sn108_r3to5_w4', 6),
    say('sn108_r3to5_s5', 'Dandasana. Step back, plank.', 3),
    wait('sn108_r3to5_w5', 5),
    say('sn108_r3to5_s6', 'Ashtanga Namaskara. Knees, chest, chin down.', 3),
    wait('sn108_r3to5_w6', 4),
    say('sn108_r3to5_s7', 'Bhujangasana. Cobra. Lift your chest.', 3),
    wait('sn108_r3to5_w7', 6),
    say('sn108_r3to5_s8', 'Adho Mukha Svanasana. Downward Dog. Three breaths.', 3),
    wait('sn108_r3to5_w8', 15),
    say('sn108_r3to5_s9', 'Ashwa Sanchalanasana. Step forward into lunge.', 3),
    wait('sn108_r3to5_w9', 5),
    say('sn108_r3to5_s10', 'Hastapadasana. Step forward and fold.', 3),
    wait('sn108_r3to5_w10', 4),
    say('sn108_r3to5_s11', 'Hasta Uttanasana. Rise, arms up.', 3),
    wait('sn108_r3to5_w11', 4),
    say('sn108_r3to5_s12', 'Pranamasana. Palms to heart. Round complete.', 3),
    wait('sn108_r3to5_w12', 4),
  ]),

  // Transition to self-paced
  say(
    'sn108_s_trans',
    'Excellent. You have completed five guided rounds and know the flow. ' +
      'From now on, move at your own steady pace. I will sound a chime at the ' +
      'start of each round and give you time cues along the way. ' +
      'Keep your breathing synchronized with the movement. Let us continue.',
    12,
  ),
  wait('sn108_w_trans', 8),

  // ROUNDS 6–18 (13 rounds x 50s)
  say('sn108_b1_intro', 'Rounds six through eighteen. Thirteen rounds. Find your rhythm.', 5),
  wait('sn108_b1_pre', 3),
  repeat('sn108_b1', 13, [
    play('sn108_b1_chime', kEffectChime, false),
    wait('sn108_b1_w', 50),
  ]),
  say(
    'sn108_b1_rest',
    'Eighteen rounds done. Stay standing. Shake out your wrists. ' +
      'Roll your shoulders. A few deep breaths.',
    6,
  ),
  wait('sn108_b1_restw', 30),

  // ROUNDS 19–36 (18 rounds x 45s)
  say(
    'sn108_b2_intro',
    'Rounds nineteen through thirty-six. Eighteen rounds. Your body is warm now — let the movement flow.',
    6,
  ),
  wait('sn108_b2_pre', 3),
  repeat('sn108_b2', 18, [
    play('sn108_b2_chime', kEffectChime, false),
    wait('sn108_b2_w', 45),
  ]),
  say(
    'sn108_b2_rest',
    'Thirty-six rounds complete — one third done. Take a sip of water. ' +
      'Stay on your feet. Breathe deeply.',
    6,
  ),
  wait('sn108_b2_restw', 45),

  // ROUNDS 37–54 (18 rounds x 45s) — MIDPOINT
  say(
    'sn108_b3_intro',
    'Rounds thirty-seven through fifty-four. Approaching the halfway mark. ' +
      'Stay steady. Breathe with every pose.',
    6,
  ),
  wait('sn108_b3_pre', 3),
  repeat('sn108_b3', 18, [
    play('sn108_b3_chime', kEffectChime, false),
    wait('sn108_b3_w', 45),
  ]),
  play('sn108_mid_gong', kEffectGong, false),
  say(
    'sn108_b3_rest',
    'Halfway — fifty-four rounds complete. You are doing beautifully. ' +
      'Hydrate. Wipe your brow. Let your heart rate settle for a moment.',
    7,
  ),
  wait('sn108_b3_restw', 45),

  // ROUNDS 55–72 (18 rounds x 40s)
  say(
    'sn108_b4_intro',
    'Rounds fifty-five through seventy-two. Second half. You may notice the pace feels easier — your body knows the way.',
    7,
  ),
  wait('sn108_b4_pre', 3),
  repeat('sn108_b4', 18, [
    play('sn108_b4_chime', kEffectChime, false),
    wait('sn108_b4_w', 40),
  ]),
  say(
    'sn108_b4_rest',
    'Seventy-two rounds. Two thirds complete. Brief pause. Shake out your hands. ' +
      'Sip water if you need it.',
    6,
  ),
  wait('sn108_b4_restw', 40),

  // ROUNDS 73–90 (18 rounds x 40s)
  say(
    'sn108_b5_intro',
    'Rounds seventy-three through ninety. The home stretch approaches. Stay focused. Every round is an offering.',
    7,
  ),
  wait('sn108_b5_pre', 3),
  repeat('sn108_b5', 18, [
    play('sn108_b5_chime', kEffectChime, false),
    wait('sn108_b5_w', 40),
  ]),
  say(
    'sn108_b5_rest',
    'Ninety rounds. Just eighteen more. You have come so far. ' +
      'Take a moment. Breathe. Gather yourself for the final set.',
    7,
  ),
  wait('sn108_b5_restw', 30),

  // ROUNDS 91–108 (18 rounds x 35s) — FINAL SET
  say(
    'sn108_b6_intro',
    'The final eighteen rounds. Ninety-one through one hundred and eight. ' +
      'Let each round be filled with gratitude. Finish strong.',
    7,
  ),
  wait('sn108_b6_pre', 3),
  repeat('sn108_b6', 18, [
    play('sn108_b6_bell', kEffectBell, false),
    wait('sn108_b6_w', 35),
  ]),

  // Completion & Cool Down
  play('sn108_final_gong', kEffectGong, false),
  notify('sn108_n2', '108 Surya Namaskar Complete!', 'You did it. Rest in Savasana.'),
  say(
    'sn108_s_done',
    'One hundred and eight rounds of Surya Namaskar — complete. ' +
      'That was extraordinary. Slowly come down to the mat. ' +
      'Lie in Savasana — arms by your sides, palms facing up. ' +
      'Close your eyes and let your body absorb everything you have given it.',
    12,
  ),
  wait('sn108_w_sav', 180),
  say(
    'sn108_s_close',
    'Begin to deepen your breath. Wiggle your fingers and toes. ' +
      'Roll to your right side and gently sit up. ' +
      'Bring your palms together. Bow your head. ' +
      'Namaste. You have honoured a profound tradition today.',
    10,
  ),
  wait('sn108_w_close', 15),
  stopAudio('sn108_sa1'),
];

// ---------------------------------------------------------------------------
// Plan 2 — Yoga Nidra (~30 min, meditation)
// ---------------------------------------------------------------------------

const plan2Steps: object[] = [
  // Preparation
  play('yn_p1', kAmbientOcean, true, 0.3, 4000),
  notify('yn_n1', 'Yoga Nidra', 'Lie down in Savasana — your deep relaxation begins'),
  say(
    'yn_s1',
    'Welcome to Yoga Nidra — yogic sleep. Lie down in Savasana. ' +
      'Arms slightly away from your body, palms facing up. ' +
      'Feet fall open naturally. Close your eyes. ' +
      'Make sure you are warm and comfortable. ' +
      'You will not need to move again until the practice is over.',
    12,
  ),
  wait('yn_w1', 20),
  say(
    'yn_s2',
    'Become aware of your body lying on the floor. ' +
      'Feel the weight of your body sinking into the surface beneath you. ' +
      'Become aware of the sounds around you. The sounds far away. ' +
      'The sounds nearby. The sound of my voice. ' +
      'Stay awake. Stay aware. Simply listen and follow.',
    12,
  ),
  wait('yn_w2', 15),

  // Sankalpa (Resolve)
  say(
    'yn_s_sank1',
    'Now it is time for your Sankalpa — your heartfelt resolve. ' +
      'Think of a short, positive statement in the present tense. ' +
      'Something deeply meaningful to you. ' +
      'Repeat it three times silently in your mind with full conviction.',
    10,
  ),
  wait('yn_w_sank1', 30),

  // Rotation of Consciousness
  say(
    'yn_s_rot_intro',
    'We will now rotate awareness through the body. ' +
      'As I name each part, simply bring your attention there. ' +
      'Do not move. Do not try to relax. Just be aware.',
    8,
  ),
  wait('yn_w_rot_intro', 8),
  // Right side
  say(
    'yn_s_rot_r',
    'Right hand. Right thumb. Second finger. Third finger. Fourth finger. Little finger. ' +
      'Palm of the hand. Back of the hand. Right wrist. Right forearm. Right elbow. ' +
      'Right upper arm. Right shoulder. Right armpit. Right side of the waist. ' +
      'Right hip. Right thigh. Right kneecap. Right shin. Right calf. ' +
      'Right ankle. Right heel. Sole of the right foot. ' +
      'Top of the right foot. Right big toe. Second toe. Third toe. Fourth toe. Little toe.',
    30,
  ),
  wait('yn_w_rot_r', 10),
  // Left side
  say(
    'yn_s_rot_l',
    'Left hand. Left thumb. Second finger. Third finger. Fourth finger. Little finger. ' +
      'Palm of the hand. Back of the hand. Left wrist. Left forearm. Left elbow. ' +
      'Left upper arm. Left shoulder. Left armpit. Left side of the waist. ' +
      'Left hip. Left thigh. Left kneecap. Left shin. Left calf. ' +
      'Left ankle. Left heel. Sole of the left foot. ' +
      'Top of the left foot. Left big toe. Second toe. Third toe. Fourth toe. Little toe.',
    30,
  ),
  wait('yn_w_rot_l', 10),
  // Back body
  say(
    'yn_s_rot_back',
    'Now the back of the body. Right shoulder blade. Left shoulder blade. ' +
      'The whole upper back. The middle back. The lower back. ' +
      'The right buttock. The left buttock. The spine. The whole back together.',
    12,
  ),
  wait('yn_w_rot_back', 10),
  // Front body
  say(
    'yn_s_rot_front',
    'The front of the body. The chest. The right side of the chest. ' +
      'The left side of the chest. The navel. The abdomen. ' +
      'The whole front of the body.',
    8,
  ),
  wait('yn_w_rot_front', 8),
  // Head and face
  say(
    'yn_s_rot_head',
    'The top of the head. The forehead. The right eyebrow. The left eyebrow. ' +
      'The space between the eyebrows. The right eyelid. The left eyelid. ' +
      'The right eye. The left eye. The right ear. The left ear. ' +
      'The right cheek. The left cheek. The nose. The tip of the nose. ' +
      'The upper lip. The lower lip. The chin. The throat. The whole face. ' +
      'The whole head.',
    22,
  ),
  wait('yn_w_rot_head', 12),
  // Whole body
  say(
    'yn_s_rot_whole',
    'Now become aware of the whole body. The whole body lying still and relaxed. ' +
      'The whole body. Be aware of the whole body.',
    7,
  ),
  wait('yn_w_rot_whole', 20),

  // Breath Awareness
  say(
    'yn_s_breath',
    'Now bring your awareness to your breath. Do not change it. ' +
      'Simply watch the natural flow of breath. ' +
      'Feel the breath at the nostrils — cool air flowing in, warm air flowing out. ' +
      'Begin to count your breaths backwards from twenty-seven. ' +
      'Breathing in, twenty-seven. Breathing out, twenty-seven. ' +
      'Breathing in, twenty-six. Breathing out, twenty-six. ' +
      'Continue counting on your own. If you lose count, start again from twenty-seven.',
    18,
  ),
  wait('yn_w_breath', 120),

  // Feelings and Sensations
  say(
    'yn_s_feel1',
    'Now we explore opposite sensations. ' +
      'Bring to your body the feeling of heaviness. ' +
      'Your whole body is heavy — so heavy it is sinking into the floor. ' +
      'Heavy. Heavy. Heavy.',
    9,
  ),
  wait('yn_w_feel1', 20),
  say(
    'yn_s_feel2',
    'Now lightness. Your body is so light it could float upward. ' +
      'Light. Weightless. As if you could drift away.',
    6,
  ),
  wait('yn_w_feel2', 20),
  say('yn_s_feel3', 'Now warmth. A gentle warmth spreading through your entire body.', 4),
  wait('yn_w_feel3', 15),
  say('yn_s_feel4', 'And now coolness. A pleasant coolness. Like a gentle breeze.', 4),
  wait('yn_w_feel4', 15),

  // Visualization
  say(
    'yn_s_viz',
    'Now we enter the space of visualization. ' +
      'Imagine you are lying in a vast open meadow under a clear sky. ' +
      'The grass is soft beneath you. The sky above is a deep, endless blue. ' +
      'White clouds drift slowly overhead. A warm golden light surrounds you. ' +
      'You are completely safe. Completely at peace. ' +
      'Stay in this space. Watch the sky. Let thoughts pass like clouds.',
    18,
  ),
  wait('yn_w_viz', 90),

  // Sankalpa Repeat
  say(
    'yn_s_sank2',
    'Now return to your Sankalpa — the same resolve you made at the beginning. ' +
      'Repeat it three times in your mind with deep feeling and conviction. ' +
      'The seed you plant in this relaxed state takes root deeply.',
    9,
  ),
  wait('yn_w_sank2', 30),

  // Externalization
  say(
    'yn_s_ext1',
    'The practice of Yoga Nidra is now coming to a close. ' +
      'Become aware of your breath again. Become aware of the surface beneath you. ' +
      'Become aware of the room around you. The sounds nearby.',
    8,
  ),
  wait('yn_w_ext1', 15),
  say(
    'yn_s_ext2',
    'Begin to move your fingers and toes gently. Rock your head side to side. ' +
      'Stretch your arms above your head. Take a long, deep breath.',
    7,
  ),
  wait('yn_w_ext2', 15),
  play('yn_p2', kEffectGong, false),
  say(
    'yn_s_ext3',
    'Roll to your right side. Stay there for a few moments. ' +
      'When you are ready, slowly sit up. Keep your eyes soft. ' +
      'Yoga Nidra is complete. Hari Om.',
    8,
  ),
  wait('yn_w_ext3', 20),
  stopAudio('yn_sa1'),
];

// ---------------------------------------------------------------------------
// Plan 3 — Full Body Strength Circuit (~35 min, workout)
// ---------------------------------------------------------------------------

const plan3Steps: object[] = [
  // Setup
  notify('fbs_n1', 'Full Body Strength Circuit', '35 minutes — warmup, 6 exercises, cooldown'),
  say(
    'fbs_s_intro',
    'Full Body Strength Circuit. Thirty-five minutes of focused work. ' +
      'We will start with a five-minute dynamic warmup to prepare your joints and muscles. ' +
      'Then six compound exercises — three sets of forty-five seconds each — with ' +
      'fifteen seconds rest between sets and thirty seconds between exercises. ' +
      'We finish with a five-minute guided cooldown. ' +
      'Clear some floor space. Have water nearby. Let us begin.',
    16,
  ),
  wait('fbs_w_intro', 10),

  // PHASE 1: DYNAMIC WARMUP (5 min)
  play('fbs_bell_wu', kEffectBell, false),
  say(
    'fbs_s_wu_intro',
    'Phase one — dynamic warmup. Five movements, one minute each. ' +
      'The goal is to raise your heart rate, warm the synovial fluid in your joints, ' +
      'and activate the muscles we are about to work.',
    9,
  ),
  wait('fbs_w_wu_intro', 5),

  // Warmup 1: Neck circles
  say(
    'fbs_s_wu1',
    'Neck circles. Stand tall, feet hip-width apart. ' +
      'Drop your chin to your chest. Slowly roll your head to the right, ' +
      'back, left, and forward in a full circle. Do five slow circles in each direction. ' +
      'Keep your shoulders relaxed and down. ' +
      'If you feel any crunching, slow down and make the circles smaller.',
    12,
  ),
  wait('fbs_w_wu1', 50),

  // Warmup 2: Arm circles & shoulder rolls
  play('fbs_bell_wu2', kEffectChime, false),
  say(
    'fbs_s_wu2',
    'Arm circles. Extend both arms straight out to the sides at shoulder height. ' +
      'Make small circles forward — gradually making them bigger. ' +
      'After fifteen seconds, reverse direction. ' +
      'Then drop your arms and do ten shoulder rolls — five forward, five backward. ' +
      'Roll them up to your ears, back, and down. Feel the blades glide.',
    14,
  ),
  wait('fbs_w_wu2', 50),

  // Warmup 3: Hip circles
  play('fbs_bell_wu3', kEffectChime, false),
  say(
    'fbs_s_wu3',
    'Hip circles. Place your hands on your hips, feet shoulder-width apart. ' +
      'Push your hips forward, then rotate them in a wide circle to the right, ' +
      'back, left, and forward. Big, smooth circles. ' +
      'Ten circles clockwise, then ten counterclockwise. ' +
      'Keep your upper body relatively still — isolate the hips.',
    12,
  ),
  wait('fbs_w_wu3', 50),

  // Warmup 4: Leg swings
  play('fbs_bell_wu4', kEffectChime, false),
  say(
    'fbs_s_wu4',
    'Leg swings. Hold a wall or chair for balance if needed. ' +
      'Swing your right leg forward and backward like a pendulum. ' +
      'Keep it relaxed — let momentum do the work. Ten swings. ' +
      'Then switch to the left leg. Ten swings. ' +
      'Next, face the wall and swing each leg side to side — ten per leg. ' +
      'This opens up the hip flexors and adductors.',
    14,
  ),
  wait('fbs_w_wu4', 50),

  // Warmup 5: Bodyweight squats (easy pace)
  play('fbs_bell_wu5', kEffectChime, false),
  say(
    'fbs_s_wu5',
    'Easy bodyweight squats to finish the warmup. ' +
      'Feet shoulder-width apart, toes pointing slightly out. ' +
      'Sit your hips back and down as if you are lowering into a chair. ' +
      'Go at a comfortable pace — no rushing. Focus on getting full depth. ' +
      'Thighs parallel to the floor or below if your mobility allows. ' +
      'Keep your chest lifted and your weight in your heels. ' +
      'About fifteen reps at an easy pace.',
    14,
  ),
  wait('fbs_w_wu5', 50),

  say(
    'fbs_s_wu_done',
    'Warmup complete. Your body is ready. ' +
      'Grab a sip of water. We start the main circuit in fifteen seconds.',
    6,
  ),
  wait('fbs_w_wu_done', 15),

  // PHASE 2: MAIN CIRCUIT (6 exercises x 3 sets)
  play('fbs_gong_main', kEffectGong, false),
  say(
    'fbs_s_main_intro',
    'Phase two — main circuit. Six exercises. Three sets of forty-five seconds ' +
      'for each exercise, with fifteen seconds rest between sets and thirty seconds ' +
      'rest between exercises. I will guide your form on the first set of each exercise. ' +
      'Move with control — quality over speed.',
    14,
  ),
  wait('fbs_w_main_intro', 8),

  // Exercise 1: Push-ups
  say(
    'fbs_s_ex1_intro',
    'Exercise one — Push-ups. Three sets. ' +
      'Hands slightly wider than shoulder-width, fingers spread. ' +
      'Body in a straight line from head to heels — do not let your hips sag or pike up. ' +
      'Lower your chest until it hovers two inches from the floor. ' +
      'Elbows track at about forty-five degrees from your torso, not flared straight out. ' +
      'Push through your palms to full extension at the top. Exhale on the push, inhale on the way down. ' +
      'If full push-ups are too challenging, drop to your knees — same form, shorter lever.',
    20,
  ),
  wait('fbs_w_ex1_intro', 5),
  play('fbs_ex1_s1_bell', kEffectBell, false),
  say('fbs_s_ex1_s1', 'Set one — go. Chest to the floor. Full extension. Breathe.', 4),
  wait('fbs_w_ex1_s1', 45),
  say('fbs_s_ex1_r1', 'Rest. Shake out your arms. Fifteen seconds.', 3),
  wait('fbs_w_ex1_r1', 15),
  play('fbs_ex1_s2_bell', kEffectBell, false),
  say('fbs_s_ex1_s2', 'Set two — go. Keep your core braced. Steady tempo.', 4),
  wait('fbs_w_ex1_s2', 45),
  say('fbs_s_ex1_r2', 'Rest. Good work. One more set.', 3),
  wait('fbs_w_ex1_r2', 15),
  play('fbs_ex1_s3_bell', kEffectBell, false),
  say('fbs_s_ex1_s3', 'Final set — push-ups. Give it everything. Controlled descent, explosive push.', 5),
  wait('fbs_w_ex1_s3', 45),
  say('fbs_s_ex1_done', 'Push-ups done. Transition in thirty seconds.', 3),
  wait('fbs_w_ex1_trans', 30),

  // Exercise 2: Bodyweight Squats
  say(
    'fbs_s_ex2_intro',
    'Exercise two — Bodyweight Squats. Three sets. ' +
      'Feet shoulder-width apart, toes turned out slightly — about fifteen to thirty degrees. ' +
      'Initiate by pushing your hips back, then bending your knees. ' +
      'Descend until your hip crease drops below your kneecap — that is full depth. ' +
      'Your knees should track over your toes, not cave inward. ' +
      'Drive through your entire foot to stand — squeeze your glutes at the top. ' +
      'Arms can extend forward for counterbalance. Breathe in on the way down, out on the way up.',
    20,
  ),
  wait('fbs_w_ex2_intro', 5),
  play('fbs_ex2_s1_bell', kEffectBell, false),
  say('fbs_s_ex2_s1', 'Set one — go. Sit deep. Chest up. Drive through your heels.', 5),
  wait('fbs_w_ex2_s1', 45),
  say('fbs_s_ex2_r1', 'Rest. Fifteen seconds.', 2),
  wait('fbs_w_ex2_r1', 15),
  play('fbs_ex2_s2_bell', kEffectBell, false),
  say('fbs_s_ex2_s2', 'Set two — go. Full depth every rep. No half squats.', 4),
  wait('fbs_w_ex2_s2', 45),
  say('fbs_s_ex2_r2', 'Rest. One more.', 2),
  wait('fbs_w_ex2_r2', 15),
  play('fbs_ex2_s3_bell', kEffectBell, false),
  say('fbs_s_ex2_s3', 'Final set — squats. Try to add a one-second pause at the bottom of each rep. Earn it.', 5),
  wait('fbs_w_ex2_s3', 45),
  say('fbs_s_ex2_done', 'Squats complete. Thirty-second transition.', 3),
  wait('fbs_w_ex2_trans', 30),

  // Exercise 3: Glute Bridges
  say(
    'fbs_s_ex3_intro',
    'Exercise three — Glute Bridges. Lie on your back. Three sets. ' +
      'Bend your knees so your feet are flat on the floor, hip-width apart, ' +
      'about six inches from your glutes. Arms at your sides, palms down. ' +
      'Press through your heels and lift your hips until your body forms a straight line ' +
      'from shoulders to knees. Squeeze your glutes hard at the top for a full second. ' +
      'Lower slowly — do not just drop. ' +
      'Keep your ribs down — do not hyperextend your lower back. ' +
      'Your core should stay engaged throughout.',
    20,
  ),
  wait('fbs_w_ex3_intro', 8),
  play('fbs_ex3_s1_bell', kEffectBell, false),
  say('fbs_s_ex3_s1', 'Set one — go. Drive hips up. Squeeze at the top. Control the descent.', 5),
  wait('fbs_w_ex3_s1', 45),
  say('fbs_s_ex3_r1', 'Rest. Stay on the floor. Fifteen seconds.', 3),
  wait('fbs_w_ex3_r1', 15),
  play('fbs_ex3_s2_bell', kEffectBell, false),
  say('fbs_s_ex3_s2', 'Set two — go. Two-second squeeze at the top this time.', 4),
  wait('fbs_w_ex3_s2', 45),
  say('fbs_s_ex3_r2', 'Rest.', 1),
  wait('fbs_w_ex3_r2', 15),
  play('fbs_ex3_s3_bell', kEffectBell, false),
  say('fbs_s_ex3_s3', 'Final set — glute bridges. Slow three-second lowering on each rep. Feel the burn.', 5),
  wait('fbs_w_ex3_s3', 45),
  say('fbs_s_ex3_done', 'Glute bridges done. Stand up for the next exercise. Thirty-second break.', 4),
  wait('fbs_w_ex3_trans', 30),

  // Exercise 4: Plank Hold
  say(
    'fbs_s_ex4_intro',
    'Exercise four — Plank Hold. Three sets. ' +
      'Get into a forearm plank position. Elbows directly under your shoulders. ' +
      'Forearms parallel, or clasp your hands if that feels more stable. ' +
      'Your body should form a rigid straight line from the crown of your head to your heels. ' +
      'Tuck your pelvis slightly to flatten your lower back — no sag, no pike. ' +
      'Push the floor away with your forearms so your upper back is not sagging between your shoulder blades. ' +
      'Breathe steadily — do not hold your breath. Squeeze your quads and glutes. ' +
      'If you start to shake, that is your body building strength. Hold through it.',
    22,
  ),
  wait('fbs_w_ex4_intro', 5),
  play('fbs_ex4_s1_bell', kEffectBell, false),
  say('fbs_s_ex4_s1', 'Set one — hold. Lock in your position. Breathe.', 4),
  wait('fbs_w_ex4_s1', 45),
  say('fbs_s_ex4_r1', 'Release. Drop to your knees. Breathe. Fifteen seconds.', 3),
  wait('fbs_w_ex4_r1', 15),
  play('fbs_ex4_s2_bell', kEffectBell, false),
  say('fbs_s_ex4_s2', 'Set two — hold. Hips level. Core braced. Eyes on the floor just ahead of your hands.', 5),
  wait('fbs_w_ex4_s2', 45),
  say('fbs_s_ex4_r2', 'Release. Rest.', 2),
  wait('fbs_w_ex4_r2', 15),
  play('fbs_ex4_s3_bell', kEffectBell, false),
  say('fbs_s_ex4_s3', 'Final set — plank. Forty-five seconds. This is mental now. You are stronger than the discomfort.', 5),
  wait('fbs_w_ex4_s3', 45),
  say('fbs_s_ex4_done', 'Planks done. Stand up. Shake it out. Thirty-second break.', 4),
  wait('fbs_w_ex4_trans', 30),

  // Exercise 5: Reverse Lunges
  say(
    'fbs_s_ex5_intro',
    'Exercise five — Alternating Reverse Lunges. Three sets. ' +
      'Stand tall, hands on your hips or arms at your sides. ' +
      'Step your right foot straight back about two to three feet. ' +
      'Lower your right knee until it hovers one inch above the floor. ' +
      'Your front shin should be vertical — left knee directly above your left ankle. ' +
      'Push through the heel of your front foot to return to standing. ' +
      'Alternate legs each rep. Keep your torso upright — do not lean forward. ' +
      'Reverse lunges are easier on the knees than forward lunges because the deceleration ' +
      'happens on the back leg instead of the front.',
    22,
  ),
  wait('fbs_w_ex5_intro', 5),
  play('fbs_ex5_s1_bell', kEffectBell, false),
  say('fbs_s_ex5_s1', 'Set one — go. Step back, drop low, drive up. Alternate.', 5),
  wait('fbs_w_ex5_s1', 45),
  say('fbs_s_ex5_r1', 'Rest. Fifteen seconds.', 2),
  wait('fbs_w_ex5_r1', 15),
  play('fbs_ex5_s2_bell', kEffectBell, false),
  say('fbs_s_ex5_s2', 'Set two — go. Keep your torso tall. No wobbling. Own the movement.', 5),
  wait('fbs_w_ex5_s2', 45),
  say('fbs_s_ex5_r2', 'Rest. One more.', 2),
  wait('fbs_w_ex5_r2', 15),
  play('fbs_ex5_s3_bell', kEffectBell, false),
  say('fbs_s_ex5_s3', 'Final set — lunges. Slow descent, explosive return. Every rep counts.', 5),
  wait('fbs_w_ex5_s3', 45),
  say('fbs_s_ex5_done', 'Lunges complete. One exercise left. Thirty seconds.', 3),
  wait('fbs_w_ex5_trans', 30),

  // Exercise 6: Tricep Dips
  say(
    'fbs_s_ex6_intro',
    'Exercise six — Tricep Dips. Final exercise. Three sets. ' +
      'Sit on the edge of a sturdy chair, bench, or low table. ' +
      'Place your hands on the edge beside your hips, fingers wrapping over the front. ' +
      'Walk your feet out so your hips are off the seat, knees bent at about ninety degrees. ' +
      'For more challenge, extend your legs straight out. ' +
      'Lower your body by bending your elbows straight back — not flared out to the sides. ' +
      'Go down until your upper arms are parallel to the floor, then press back up. ' +
      'Keep your back close to the chair — do not drift forward. ' +
      'Shoulders stay down and away from your ears.',
    22,
  ),
  wait('fbs_w_ex6_intro', 5),
  play('fbs_ex6_s1_bell', kEffectBell, false),
  say('fbs_s_ex6_s1', 'Set one — go. Elbows back. Lower with control. Press up strong.', 5),
  wait('fbs_w_ex6_s1', 45),
  say('fbs_s_ex6_r1', 'Rest. Fifteen seconds.', 2),
  wait('fbs_w_ex6_r1', 15),
  play('fbs_ex6_s2_bell', kEffectBell, false),
  say('fbs_s_ex6_s2', 'Set two — go. Steady pace. Full range of motion.', 4),
  wait('fbs_w_ex6_s2', 45),
  say('fbs_s_ex6_r2', 'Rest. Last set coming up.', 3),
  wait('fbs_w_ex6_r2', 15),
  play('fbs_ex6_s3_bell', kEffectBell, false),
  say('fbs_s_ex6_s3', 'Final set — tricep dips. Last forty-five seconds of the circuit. Leave nothing in the tank.', 6),
  wait('fbs_w_ex6_s3', 45),

  play('fbs_gong_circuit', kEffectGong, false),
  say(
    'fbs_s_circuit_done',
    'Circuit complete. Eighteen sets. Outstanding work. ' +
      'Grab some water. We move into the cooldown in thirty seconds.',
    7,
  ),
  wait('fbs_w_circuit_trans', 30),

  // PHASE 3: GUIDED COOLDOWN STRETCH (5 min)
  play('fbs_p_cd', kAmbientForest, true, 0.35, 2000),
  say(
    'fbs_s_cd_intro',
    'Phase three — cooldown. Five minutes of static stretching to bring your heart rate down ' +
      'and start recovery. Hold each stretch for thirty seconds. Breathe deeply into each position. ' +
      'No bouncing — just a steady, gentle pull.',
    10,
  ),
  wait('fbs_w_cd_intro', 5),

  // Stretch 1: Standing quad stretch
  say(
    'fbs_s_cd1',
    'Standing quad stretch. Stand on your left leg. ' +
      'Grab your right ankle behind you with your right hand. ' +
      'Pull your heel toward your glute. Keep your knees together. ' +
      'Stand tall — push your hips slightly forward to deepen the stretch. ' +
      'Hold for thirty seconds, then switch legs.',
    10,
  ),
  wait('fbs_w_cd1', 60),

  // Stretch 2: Standing hamstring fold
  play('fbs_cd2_chime', kEffectChime, false),
  say(
    'fbs_s_cd2',
    'Standing forward fold. Feet hip-width apart. ' +
      'Bend forward from your hips. Let your head and arms hang heavy. ' +
      'Soften your knees slightly. Feel the stretch along the back of your legs. ' +
      'Let gravity do the work. Breathe into your hamstrings.',
    10,
  ),
  wait('fbs_w_cd2', 35),

  // Stretch 3: Chest doorway stretch
  play('fbs_cd3_chime', kEffectChime, false),
  say(
    'fbs_s_cd3',
    'Chest and shoulder stretch. Stand in a doorway or extend your right arm against a wall. ' +
      'Place your forearm flat against the wall at shoulder height. ' +
      'Rotate your body away until you feel a deep stretch across your chest and front shoulder. ' +
      'Thirty seconds each side.',
    10,
  ),
  wait('fbs_w_cd3', 65),

  // Stretch 4: Hip flexor lunge stretch
  play('fbs_cd4_chime', kEffectChime, false),
  say(
    'fbs_s_cd4',
    'Hip flexor stretch. Drop into a low lunge — right foot forward, left knee on the ground. ' +
      'Tuck your pelvis under and lean forward slightly until you feel a deep stretch in the front of your left hip. ' +
      'Raise your left arm overhead and lean gently to the right to intensify the stretch. ' +
      'Hold for thirty seconds, then switch sides.',
    12,
  ),
  wait('fbs_w_cd4', 65),

  // Stretch 5: Child's pose
  play('fbs_cd5_chime', kEffectChime, false),
  say(
    'fbs_s_cd5',
    "Finally, Child's Pose. Kneel on the floor. Sit your hips back onto your heels. " +
      'Walk your hands forward and lower your forehead to the ground. ' +
      'Arms extended, shoulders relaxed. Breathe deeply into your lower back. ' +
      'This is your reward. Rest here.',
    10,
  ),
  wait('fbs_w_cd5', 40),

  // Session Complete
  play('fbs_gong_end', kEffectGong, false),
  notify('fbs_n2', 'Strength Circuit Complete!', 'Eighteen sets done. Strong work today.'),
  say(
    'fbs_s_end',
    'Full Body Strength Circuit complete. You warmed up properly, ' +
      'moved through eighteen working sets of six compound exercises, ' +
      'and cooled down with targeted stretches. ' +
      'Your muscles will thank you tomorrow. Rest well and stay hydrated.',
    12,
  ),
  wait('fbs_w_end', 10),
  stopAudio('fbs_sa1'),
];

// ---------------------------------------------------------------------------
// Plan 4 — Morning Routine (~45 min, routine)
// ---------------------------------------------------------------------------

const plan4Steps: object[] = [
  // Wake Up
  play('mr_p1', kAmbientForest, true, 0.3, 5000),
  notify('mr_n1', 'Good Morning', 'Your 45-minute morning routine is starting'),
  say(
    'mr_s_welcome',
    'Good morning. This is your guided morning routine — forty-five minutes ' +
      'of deliberate actions to set the tone for your entire day. ' +
      'Each step is timed, so you never need to check the clock. ' +
      'Just follow my voice and move through each phase with intention. ' +
      'Let us begin.',
    12,
  ),
  wait('mr_w_welcome', 8),

  // Step 1: Hydration (2 min)
  play('mr_bell_s1', kEffectBell, false),
  say(
    'mr_s_hydrate',
    'Step one — hydrate. Before anything else, drink a full glass of water. ' +
      'Your body has been fasting and dehydrating for seven to eight hours. ' +
      'Room temperature water is ideal — it is absorbed faster than cold water. ' +
      'If you have a lemon, squeeze half of it into the glass. ' +
      'The vitamin C and citric acid help kick-start your digestion. ' +
      'Take your time — drink the whole glass, not just a few sips.',
    14,
  ),
  wait('mr_w_hydrate', 90),
  say(
    'mr_s_hydrate_done',
    'Glass finished. Good. You have already done more for yourself than most people do before noon.',
    5,
  ),
  wait('mr_w_hydrate_done', 5),

  // Step 2: Gentle Movement (7 min)
  play('mr_bell_s2', kEffectBell, false),
  notify('mr_n2', 'Step 2: Movement', '7 minutes of gentle stretching and mobility'),
  say(
    'mr_s_move_intro',
    'Step two — gentle movement. Seven minutes. ' +
      'This is not a workout — the goal is to wake up your body and undo the stiffness of sleep. ' +
      'We will do some simple stretches and mobility work. Stand up.',
    10,
  ),
  wait('mr_w_move_intro', 10),

  // Move: Neck & shoulders
  say(
    'mr_s_move1',
    'Start with your neck. Drop your right ear toward your right shoulder. ' +
      'Hold for five breaths. You should feel a gentle stretch on the left side of your neck. ' +
      'Now the other side — left ear toward left shoulder. Five breaths. ' +
      'Then roll your shoulders — five big circles forward, five backward. ' +
      'Let the tension melt away.',
    14,
  ),
  wait('mr_w_move1', 60),

  // Move: Spine
  play('mr_chime_m2', kEffectChime, false),
  say(
    'mr_s_move2',
    'Now your spine. Stand with feet hip-width apart. ' +
      'Place your hands on your lower back. Gently arch backward — ' +
      'open your chest to the ceiling. Hold for three breaths. ' +
      'Then fold forward — let your head and arms hang. ' +
      'Bend your knees as much as you need. Breathe into your lower back. ' +
      'Slowly roll back up, one vertebra at a time, head comes up last.',
    14,
  ),
  wait('mr_w_move2', 60),

  // Move: Hips & legs
  play('mr_chime_m3', kEffectChime, false),
  say(
    'mr_s_move3',
    'Hip and leg mobility. Do five slow bodyweight squats — go as deep as comfortable. ' +
      'Then stand on one leg and swing the other forward and back ten times. Switch legs. ' +
      'Finally, do a standing figure-four stretch — cross your right ankle over your left knee, ' +
      'sit back into a half-squat and hold for five breaths. Switch sides. ' +
      'This opens up the glutes and piriformis.',
    16,
  ),
  wait('mr_w_move3', 90),

  // Move: Deep breathing
  play('mr_chime_m4', kEffectChime, false),
  say(
    'mr_s_move4',
    'Stand tall. Feet grounded. Take five deep breaths. ' +
      'Inhale through your nose for four counts. Hold for four counts. ' +
      'Exhale through your mouth for six counts. ' +
      'Let each exhale be longer and slower than the last. ' +
      'This activates your parasympathetic nervous system and sets a calm, focused tone.',
    12,
  ),
  wait('mr_w_move4', 70),

  say(
    'mr_s_move_done',
    'Movement done. Your body is awake. You should feel looser, warmer, and more alert.',
    5,
  ),
  wait('mr_w_move_done', 5),

  // Step 3: Cold Water & Hygiene (8 min)
  play('mr_bell_s3', kEffectBell, false),
  notify('mr_n3', 'Step 3: Freshen Up', '8 minutes — cold water splash, brush, and get ready'),
  say(
    'mr_s_hygiene',
    'Step three — freshen up. Head to the bathroom. ' +
      'Start by splashing cold water on your face — ten to fifteen splashes. ' +
      'Cold water increases alertness, constricts blood vessels to reduce puffiness, ' +
      'and triggers the dive reflex which calms your nervous system. ' +
      'Then brush your teeth thoroughly for two minutes — ' +
      'thirty seconds per quadrant. Use your non-dominant hand if you want a cognitive challenge. ' +
      'Shower if you like, or save it for later. ' +
      'You have eight minutes total for this step.',
    18,
  ),
  wait('mr_w_hygiene', 8 * 60),

  play('mr_bell_s3_done', kEffectBell, false),
  say('mr_s_hygiene_done', 'Hygiene done. You are fresh. On to breakfast.', 3),
  wait('mr_w_hygiene_done', 5),

  // Step 4: Mindful Breakfast (15 min)
  play('mr_bell_s4', kEffectBell, false),
  notify('mr_n4', 'Step 4: Breakfast', '15 minutes — prepare and eat mindfully'),
  say(
    'mr_s_food_intro',
    'Step four — mindful breakfast. Fifteen minutes. ' +
      'This is not about speed — it is about nourishment and presence. ' +
      'Choose something with protein, healthy fat, and complex carbohydrates. ' +
      'Eggs with whole grain toast and avocado. Greek yogurt with nuts and berries. ' +
      'Oatmeal with banana and peanut butter. Whatever works for you. ' +
      'Avoid scrolling your phone while eating. ' +
      'Focus on the taste, the texture, and the act of chewing. ' +
      'Eating without distraction improves digestion and satisfaction.',
    18,
  ),
  wait('mr_w_food_prep', 5 * 60),

  say(
    'mr_s_food_mid',
    'Five minutes in. You should be eating by now. ' +
      'Chew slowly. Put your fork down between bites. ' +
      'Notice the flavors. This is a small act of mindfulness that compounds over time.',
    8,
  ),
  wait('mr_w_food_mid', 5 * 60),

  say(
    'mr_s_food_wrap',
    'Five more minutes. Finish eating and clean up your plate and utensils. ' +
      'A clean kitchen sets a clean mental state.',
    6,
  ),
  wait('mr_w_food_wrap', 5 * 60),

  say('mr_s_food_done', 'Breakfast complete. You are fueled.', 3),
  wait('mr_w_food_done', 5),

  // Step 5: Journaling (8 min)
  play('mr_bell_s5', kEffectBell, false),
  notify('mr_n5', 'Step 5: Journal', '8 minutes of freewriting and gratitude'),
  say(
    'mr_s_journal_intro',
    'Step five — journaling. Eight minutes. Grab a notebook or open a notes app. ' +
      'We will do two short exercises.',
    7,
  ),
  wait('mr_w_journal_intro', 10),

  // Journal: Gratitude
  say(
    'mr_s_journal1',
    'First — gratitude. Write down three things you are genuinely grateful for right now. ' +
      "They do not need to be grand — a good night's sleep, a friend who checked in, " +
      'the fact that you are alive and choosing to invest in yourself this morning. ' +
      'Be specific. Instead of just writing "my health", write exactly what about your health ' +
      'you are grateful for today. Specificity is where the power lives. ' +
      'Take three minutes.',
    16,
  ),
  wait('mr_w_journal1', 3 * 60),

  // Journal: Free write
  play('mr_chime_j2', kEffectChime, false),
  say(
    'mr_s_journal2',
    'Now — freewriting. For four minutes, write whatever comes to mind. ' +
      'Stream of consciousness. Do not edit, do not judge, do not stop writing. ' +
      "If you run out of things to say, write \"I don't know what to write\" until something comes. " +
      'This practice clears mental fog, surfaces hidden anxieties, and often produces ' +
      'surprisingly useful insights. Pen moving. Go.',
    14,
  ),
  wait('mr_w_journal2', 4 * 60),

  play('mr_chime_j3', kEffectChime, false),
  say(
    'mr_s_journal_done',
    'Pens down. Close the notebook. That reflection is now working in the background of your mind.',
    5,
  ),
  wait('mr_w_journal_done', 8),

  // Step 6: Daily Intention (5 min)
  play('mr_bell_s6', kEffectBell, false),
  notify('mr_n6', 'Step 6: Set Your Intention', 'What is the one thing that matters most today?'),
  say(
    'mr_s_intent_intro',
    'Final step — set your daily intention. Five minutes. ' +
      'This is the most important part of the routine. ' +
      'Ask yourself: what is the single most important thing I can accomplish today? ' +
      'Not a to-do list — one thing. The one thing that, if done, would make today a success ' +
      'even if nothing else got done.',
    14,
  ),
  wait('mr_w_intent1', 60),

  say(
    'mr_s_intent2',
    'Write it down. One sentence. Make it specific and actionable. ' +
      'Not "work on the project" — instead, "finish the draft of section three and send it for review." ' +
      'Clear targets drive clear action.',
    10,
  ),
  wait('mr_w_intent2', 60),

  say(
    'mr_s_intent3',
    'Now close your eyes for a moment. Visualize yourself completing that one thing. ' +
      'See yourself sitting down, doing the work, finishing it. ' +
      'Feel the satisfaction of crossing it off. ' +
      'Open your eyes. You know what today is about.',
    10,
  ),
  wait('mr_w_intent3', 60),

  // Routine Complete
  play('mr_gong_end', kEffectGong, false),
  notify(
    'mr_n7',
    'Morning Routine Complete!',
    'Hydrated, moved, clean, fed, journaled, focused. Go get it.',
  ),
  say(
    'mr_s_end',
    'Morning routine complete. In forty-five minutes you have hydrated your body, ' +
      'woken up your muscles and joints, freshened up, eaten a proper breakfast, ' +
      'cleared your mind through writing, and set a focused intention for the day. ' +
      'You are prepared. You are present. Go make today count.',
    14,
  ),
  wait('mr_w_end', 10),
  stopAudio('mr_sa1'),
];

// ---------------------------------------------------------------------------
// Plan 5 — Deep Work Session (~2 hours, focus)
// ---------------------------------------------------------------------------

const plan5Steps: object[] = [
  // PHASE 0: ENVIRONMENT SETUP RITUAL (3 min)
  notify('dw_n1', 'Deep Work Session', '2 hours of guided focus — prepare your environment'),
  say(
    'dw_s_welcome',
    'Deep work session. Two hours. Two blocks of fifty minutes separated by ' +
      'a ten-minute active recovery break. Before we start the clock, ' +
      'we will spend three minutes preparing your environment. ' +
      'Research shows that a deliberate setup ritual signals your brain to transition into focus mode. ' +
      'Let us begin.',
    14,
  ),
  wait('dw_w_welcome', 8),

  // Setup: Digital
  say(
    'dw_s_setup1',
    'First — digital environment. Put your phone on Do Not Disturb or, even better, ' +
      'leave it in another room entirely. Close every browser tab that is not directly ' +
      'related to the task you are about to do. Close Slack, email, social media — all of it. ' +
      'If you need any of those for your work, keep only the specific tab you need. ' +
      'Every open tab is a potential interruption. Every notification is a context switch ' +
      'that costs you fifteen to twenty minutes of refocusing time.',
    18,
  ),
  wait('dw_w_setup1', 30),

  // Setup: Physical
  say(
    'dw_s_setup2',
    "Now — physical environment. Fill a water bottle and place it within arm's reach " +
      'so you will not need to get up for hydration. ' +
      'Clear your desk of anything unrelated to the work. ' +
      'Clutter creates cognitive overhead even when you think you are ignoring it. ' +
      'If you use noise-cancelling headphones, put them on now. ' +
      'Adjust your chair height so your feet are flat on the floor and your eyes ' +
      'are level with the top third of your screen.',
    16,
  ),
  wait('dw_w_setup2', 30),

  // Setup: Task clarity
  say(
    'dw_s_setup3',
    'Finally — task clarity. In your head or on paper, answer this question: ' +
      'What specifically will I have produced by the end of these two hours? ' +
      'Not "work on the report" — instead, "complete the first draft of sections two and three." ' +
      'Not "study" — instead, "work through problems one through fifteen in chapter four." ' +
      'A clear target eliminates decision fatigue during the session. ' +
      'Take fifteen seconds to define your target now.',
    18,
  ),
  wait('dw_w_setup3', 20),

  say('dw_s_setup_done', 'Environment is set. Target is clear. The session begins now.', 4),
  wait('dw_w_setup_done', 5),

  // PHASE 1: FOCUS BLOCK 1 (50 min)
  play('dw_p1', kAmbientWhiteNoise, true, 0.3, 2000),
  play('dw_gong1', kEffectGong, false),
  notify('dw_n2', 'Block 1 — Go', '50 minutes of uninterrupted focus'),
  say(
    'dw_s_b1_start',
    'Block one. Fifty minutes. The white noise will stay in the background to mask distractions. ' +
      'If your mind wanders — and it will — just notice it and gently return to the task. ' +
      'Do not judge the wandering. The return is the practice. Begin working now.',
    12,
  ),

  // 15 min in
  wait('dw_w_b1_1', 15 * 60),
  say(
    'dw_s_b1_check1',
    'Fifteen minutes in. Quick check — are you still on your primary task? ' +
      'If you have drifted to something else, gently redirect now. ' +
      'No guilt, just redirect. Keep going.',
    8,
  ),

  // 30 min in
  wait('dw_w_b1_2', 15 * 60),
  say(
    'dw_s_b1_check2',
    'Thirty minutes. You are past the halfway point of block one. ' +
      'Take three slow, deep breaths without stopping your work. ' +
      'In through your nose, out through your mouth. ' +
      'This resets your nervous system without breaking flow.',
    10,
  ),

  // 45 min in
  wait('dw_w_b1_3', 15 * 60),
  say('dw_s_b1_check3', 'Forty-five minutes. Five more minutes in this block. Finish your current thought.', 5),

  // Block 1 complete
  wait('dw_w_b1_4', 5 * 60),
  play('dw_gong_b1_end', kEffectGong, false),
  stopAudio('dw_sa1'),
  notify('dw_n3', 'Block 1 Complete — Break Time', '10-minute active recovery. Step away from your screen.'),
  say(
    'dw_s_b1_end',
    'Block one complete. Fifty minutes of focused work. Well done. ' +
      'Now — a ten-minute active recovery break. This is not optional. ' +
      'Your brain consolidates and processes information during rest periods. ' +
      'Skipping the break actually makes the second block worse, not better.',
    12,
  ),
  wait('dw_w_b1_end', 5),

  // BREAK (10 min)
  say(
    'dw_s_break_intro',
    'Stand up now. Step away from your desk completely. ' +
      'Here is what to do during this break: ' +
      'First two minutes — walk around. Get your blood flowing. ' +
      'If you can step outside for fresh air, even better. ' +
      'Minutes three through six — do some light stretching. ' +
      'Roll your neck, stretch your wrists, open your chest. ' +
      'Minutes seven through ten — refill your water. ' +
      'Use the bathroom if needed. ' +
      'Do not check your phone. Do not check email. ' +
      'Let your brain idle — that is when the best connections form.',
    22,
  ),

  // Break: walk reminder
  wait('dw_w_break1', 2 * 60),
  say('dw_s_break_walk', 'Two minutes of walking done. Start your stretches. Wrists, neck, shoulders, chest.', 5),

  // Break: stretch reminder
  wait('dw_w_break2', 4 * 60),
  say('dw_s_break_stretch', 'Good stretching. Refill your water. Use the bathroom if needed. Two minutes left.', 5),

  // Break ending
  wait('dw_w_break3', 2 * 60),
  play('dw_bell_break_end', kEffectBell, false),
  say('dw_s_break_warn', 'Two minutes left in the break. Start heading back to your desk.', 4),

  wait('dw_w_break4', 2 * 60),

  // PHASE 2: FOCUS BLOCK 2 (50 min)
  play('dw_p2', kAmbientWhiteNoise, true, 0.3, 2000),
  play('dw_gong2', kEffectGong, false),
  notify('dw_n4', 'Block 2 — Go', '50 more minutes of deep focus'),
  say(
    'dw_s_b2_start',
    'Block two. Fifty minutes. Your brain is rested and primed. ' +
      'The second block often feels easier because your mind is already warmed up. ' +
      'Pick up exactly where you left off. Same target, same intensity. Begin.',
    10,
  ),

  // 15 min in
  wait('dw_w_b2_1', 15 * 60),
  say('dw_s_b2_check1', 'Fifteen minutes into block two. Sixty-five minutes of total focus today. Impressive. Keep going.', 6),

  // 30 min in
  wait('dw_w_b2_2', 15 * 60),
  say(
    'dw_s_b2_check2',
    "Thirty minutes. Eighty minutes of focused work today. " +
      "You are in the final stretch. Sip some water if you haven't already.",
    7,
  ),

  // 45 min in
  wait('dw_w_b2_3', 15 * 60),
  say('dw_s_b2_check3', 'Forty-five minutes. Five more minutes. Finish strong. Wrap up your current task.', 5),

  // Block 2 complete
  wait('dw_w_b2_4', 5 * 60),

  // PHASE 3: CLOSING REFLECTION (3 min)
  play('dw_gong_end', kEffectGong, false),
  stopAudio('dw_sa2'),
  notify('dw_n5', 'Deep Work Session Complete!', '100 minutes of focused work. Time for reflection.'),
  say(
    'dw_s_reflect_intro',
    'One hundred minutes of deep, focused work. The session is over. ' +
      'Before you jump back into the noise, take three minutes to reflect. ' +
      'This is not a luxury — research shows that workers who reflect on their work ' +
      'perform twenty-three percent better than those who just move on.',
    12,
  ),
  wait('dw_w_reflect_intro', 5),

  say(
    'dw_s_reflect1',
    'First — what did you accomplish? Jot down a one-sentence summary of what you produced. ' +
      'This creates a record of progress and makes future planning more accurate.',
    8,
  ),
  wait('dw_w_reflect1', 40),

  say(
    'dw_s_reflect2',
    'Second — what was the hardest part? Where did you get stuck? ' +
      'Naming the friction point helps you prepare for it next time.',
    7,
  ),
  wait('dw_w_reflect2', 40),

  say(
    'dw_s_reflect3',
    'Third — what is the very next action to continue this work? ' +
      'Write it down so that the next session can start immediately without re-orienting.',
    7,
  ),
  wait('dw_w_reflect3', 40),

  // Session Complete
  play('dw_gong_final', kEffectGong, false),
  say(
    'dw_s_end',
    'Deep work session complete. One hundred minutes of concentrated, ' +
      'uninterrupted effort. That is more focused work than most people achieve ' +
      'in an entire day of distracted multitasking. ' +
      'You should feel proud of that. Rest your eyes, stretch, and take a proper break. ' +
      'You have earned it.',
    14,
  ),
];

// ---------------------------------------------------------------------------
// Build plan JSON objects
// ---------------------------------------------------------------------------

const FIXED_TS = '2024-01-01T00:00:00.000Z';

function buildPlanJson(
  id: string,
  name: string,
  description: string,
  category: string,
  tags: string[],
  defaultVoice: string,
  steps: object[],
): string {
  return JSON.stringify({
    id,
    name,
    description,
    category,
    tags,
    defaultVoice,
    steps,
    createdAt: FIXED_TS,
    updatedAt: FIXED_TS,
    lastUsedAt: null,
    isActive: false,
    ttsStatus: 'none',
    ttsTotal: 0,
    ttsCompleted: 0,
  });
}

// ---------------------------------------------------------------------------
// Seed data rows
// ---------------------------------------------------------------------------

const seedRows = [
  {
    name: '108 Surya Namaskar Series',
    description:
      'The complete 108 Surya Namaskar practice. First 5 rounds are fully ' +
      'guided with every pose cued. Remaining 103 rounds are paced with ' +
      'chime markers and periodic encouragement.',
    category: 'yoga',
    tags: 'yoga,surya namaskar,108,advanced,endurance',
    defaultVoice: 'af_bella',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 0,
    planJson: buildPlanJson(
      '00000000-0000-0000-0000-000000000001',
      '108 Surya Namaskar Series',
      'The complete 108 Surya Namaskar practice. First 5 rounds are fully ' +
        'guided with every pose cued. Remaining 103 rounds are paced with ' +
        'chime markers and periodic encouragement.',
      'yoga',
      ['yoga', 'surya namaskar', '108', 'advanced', 'endurance'],
      'af_bella',
      plan1Steps,
    ),
  },
  {
    name: 'Yoga Nidra',
    description:
      'A guided Yoga Nidra — yogic sleep. A complete body-mind relaxation ' +
      'following the traditional Satyananda method with Sankalpa, rotation of ' +
      'consciousness, breath awareness, and visualization.',
    category: 'meditation',
    tags: 'meditation,yoga nidra,deep relaxation,sleep,traditional',
    defaultVoice: 'af_bella',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 1,
    planJson: buildPlanJson(
      '00000000-0000-0000-0000-000000000002',
      'Yoga Nidra',
      'A guided Yoga Nidra — yogic sleep. A complete body-mind relaxation ' +
        'following the traditional Satyananda method with Sankalpa, rotation of ' +
        'consciousness, breath awareness, and visualization.',
      'meditation',
      ['meditation', 'yoga nidra', 'deep relaxation', 'sleep', 'traditional'],
      'af_bella',
      plan2Steps,
    ),
  },
  {
    name: 'Full Body Strength Circuit',
    description:
      'A complete 35-minute bodyweight session: 5-minute dynamic warmup with ' +
      'joint mobilization, 6 compound exercises with 3 sets each and detailed ' +
      'form cues, plus a 5-minute guided cooldown stretch.',
    category: 'workout',
    tags: 'workout,strength,circuit,bodyweight,full body',
    defaultVoice: 'am_adam',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 2,
    planJson: buildPlanJson(
      '00000000-0000-0000-0000-000000000003',
      'Full Body Strength Circuit',
      'A complete 35-minute bodyweight session: 5-minute dynamic warmup with ' +
        'joint mobilization, 6 compound exercises with 3 sets each and detailed ' +
        'form cues, plus a 5-minute guided cooldown stretch.',
      'workout',
      ['workout', 'strength', 'circuit', 'bodyweight', 'full body'],
      'am_adam',
      plan3Steps,
    ),
  },
  {
    name: 'Morning Routine',
    description:
      'A structured 45-minute morning ritual: hydration, gentle movement, ' +
      'cold-water face wash, mindful breakfast, journaling, and daily intention ' +
      'setting — with guided prompts throughout.',
    category: 'routine',
    tags: 'routine,morning,productivity,wellbeing,mindfulness',
    defaultVoice: 'af_heart',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 3,
    planJson: buildPlanJson(
      '00000000-0000-0000-0000-000000000004',
      'Morning Routine',
      'A structured 45-minute morning ritual: hydration, gentle movement, ' +
        'cold-water face wash, mindful breakfast, journaling, and daily intention ' +
        'setting — with guided prompts throughout.',
      'routine',
      ['routine', 'morning', 'productivity', 'wellbeing', 'mindfulness'],
      'af_heart',
      plan4Steps,
    ),
  },
  {
    name: 'Deep Work Session',
    description:
      'A guided 2-hour deep work session: environment setup ritual, ' +
      'two 50-minute focus blocks with a 10-minute active recovery break, ' +
      'progress check-ins, and a closing reflection.',
    category: 'focus',
    tags: 'focus,deep work,productivity,flow,work',
    defaultVoice: 'am_michael',
    locale: 'enUS',
    isPublished: true,
    sortOrder: 4,
    planJson: buildPlanJson(
      '00000000-0000-0000-0000-000000000005',
      'Deep Work Session',
      'A guided 2-hour deep work session: environment setup ritual, ' +
        'two 50-minute focus blocks with a 10-minute active recovery break, ' +
        'progress check-ins, and a closing reflection.',
      'focus',
      ['focus', 'deep work', 'productivity', 'flow', 'work'],
      'am_michael',
      plan5Steps,
    ),
  },
];

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  console.log('Checking library_plans table...');

  const existing = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(libraryPlans);

  const count = existing[0]?.count ?? 0;

  if (count > 0) {
    console.log(`Already seeded (${count} rows found), skipping.`);
    process.exit(0);
  }

  console.log('Inserting 5 library plans...');

  await db.insert(libraryPlans).values(seedRows);

  console.log('Successfully seeded 5 library plans:');
  for (const row of seedRows) {
    console.log(`  [${row.sortOrder}] ${row.name} (${row.category})`);
  }
  process.exit(0);
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
