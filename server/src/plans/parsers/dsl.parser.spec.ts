import { parseDslPlan } from './dsl.parser';

describe('parseDslPlan', () => {
  // ── Happy path ───────────────────────────────────────────────────────────

  it('parses a complete plan with all 6 step types', () => {
    const dsl = `Name: Full Demo
Description: Uses every step type.
Category: workout
Voice: am_adam
---
Say: Let's warm up.
Wait: 10
Notify: Starting main set!
Play: ocean
Repeat: 3
  Say: Go!
  Wait: 20
  Say: Rest.
  Wait: 10
EndRepeat
StopAudio
Play: gong
Say: Great workout. See you next time.`;

    const result = parseDslPlan(dsl);

    expect(result.success).toBe(true);
    expect(result.plan).toBeDefined();
    expect(result.plan!.name).toBe('Full Demo');
    expect(result.plan!.description).toBe('Uses every step type.');
    expect(result.plan!.category).toBe('workout');
    expect(result.plan!.defaultVoice).toBe('am_adam');

    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    // say, wait, notify, play, repeat, stopAudio, play, say = 8
    expect(steps).toHaveLength(8);

    const types = steps.map((s) => s.type);
    expect(types).toEqual(['say', 'wait', 'notify', 'play', 'repeat', 'stopAudio', 'play', 'say']);

    const repeat = steps[4] as Record<string, unknown>;
    expect(repeat.count).toBe(3);
    expect((repeat.steps as any[]).length).toBe(4);
  });

  it('parses a minimal plan', () => {
    const dsl = `Name: Quick
Description: A quick test.
Category: custom
Voice: af_heart
---
Say: Hello.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.plan!.steps).toHaveLength(1);
  });

  // ── Voice override ─────────────────────────────────────────────────────

  it('parses Say with voice override', () => {
    const dsl = `Name: Test
Description: Voice override test.
Category: custom
Voice: af_heart
---
Say [am_eric]: Push it!
Say: Normal voice.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);

    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'say', text: 'Push it!', voice: 'am_eric' });
    expect(steps[1]).toEqual({ type: 'say', text: 'Normal voice.' });
  });

  // ── Duration parsing ───────────────────────────────────────────────────

  it('parses various Wait duration formats', () => {
    const dsl = `Name: Duration Test
Description: Test durations.
Category: custom
Voice: af_heart
---
Wait: 30
Wait: 30s
Wait: 2m
Wait: 1m30s`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);

    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'wait', durationSeconds: 30 });
    expect(steps[1]).toEqual({ type: 'wait', durationSeconds: 30 });
    expect(steps[2]).toEqual({ type: 'wait', durationSeconds: 120 });
    expect(steps[3]).toEqual({ type: 'wait', durationSeconds: 90 });
  });

  // ── Auto-repair ────────────────────────────────────────────────────────

  it('auto-repairs typo in step type (Sya -> Say)', () => {
    const dsl = `Name: Typo Test
Description: Has a typo.
Category: custom
Voice: af_heart
---
Sya: Hello there.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.repaired.length).toBeGreaterThan(0);
    expect((result.plan!.steps as any[])[0].type).toBe('say');
  });

  it('auto-repairs missing colon (Wait 30 -> Wait: 30)', () => {
    const dsl = `Name: Colon Test
Description: Missing colon.
Category: custom
Voice: af_heart
---
Say: Hello.
Wait 30`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.repaired.some((r) => r.includes('missing colon'))).toBe(true);
    expect((result.plan!.steps as any[])[1]).toEqual({ type: 'wait', durationSeconds: 30 });
  });

  it('auto-repairs close-enough asset name', () => {
    const dsl = `Name: Asset Fix
Description: Misspelled asset.
Category: custom
Voice: af_heart
---
Play: ocen`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect((result.plan!.steps as any[])[0].assetKey).toBe('ocean');
  });

  it('auto-repairs invalid category to closest match', () => {
    const dsl = `Name: Cat Fix
Description: Bad category.
Category: yogaa
Voice: af_heart
---
Say: Hello.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.plan!.category).toBe('yoga');
  });

  it('falls back to "custom" for unrecognizable category', () => {
    const dsl = `Name: Cat Fallback
Description: Unknown category.
Category: xyzabc
Voice: af_heart
---
Say: Hello.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.plan!.category).toBe('custom');
  });

  it('auto-closes unclosed Repeat blocks', () => {
    const dsl = `Name: Unclosed Repeat
Description: Missing EndRepeat.
Category: custom
Voice: af_heart
---
Repeat: 3
  Say: Go!
  Wait: 10
Say: Done.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.repaired.some((r) => r.includes('Auto-closed'))).toBe(true);
    // "Say: Done." ends up inside the repeat since no EndRepeat was found
  });

  it('ignores orphan EndRepeat', () => {
    const dsl = `Name: Orphan End
Description: Extra EndRepeat.
Category: custom
Voice: af_heart
---
Say: Hello.
EndRepeat
Say: Bye.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.repaired.some((r) => r.includes('Orphan'))).toBe(true);
    expect((result.plan!.steps as any[]).length).toBe(2); // both Say steps
  });

  // ── Nested repeat ──────────────────────────────────────────────────────

  it('handles nested repeat blocks', () => {
    const dsl = `Name: Nested
Description: Nested repeats.
Category: workout
Voice: am_adam
---
Repeat: 3
  Say: Set start.
  Repeat: 5
    Say: Rep!
    Wait: 3
  EndRepeat
  Say: Set done.
  Wait: 30
EndRepeat`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);

    const outer = (result.plan!.steps as any[])[0];
    expect(outer.type).toBe('repeat');
    expect(outer.count).toBe(3);
    expect(outer.steps).toHaveLength(4); // say, repeat, say, wait

    const inner = outer.steps[1];
    expect(inner.type).toBe('repeat');
    expect(inner.count).toBe(5);
    expect(inner.steps).toHaveLength(2); // say, wait
  });

  // ── Error cases ────────────────────────────────────────────────────────

  it('fails when --- separator is missing', () => {
    const dsl = `Name: No Sep
Description: No separator.
Category: custom
Voice: af_heart
Say: Hello.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('separator'))).toBe(true);
  });

  it('fails when Name is missing from header', () => {
    const dsl = `Description: No name.
Category: custom
Voice: af_heart
---
Say: Hello.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('Name'))).toBe(true);
  });

  it('fails when no valid steps exist', () => {
    const dsl = `Name: Empty
Description: No steps.
Category: custom
Voice: af_heart
---`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('No valid steps'))).toBe(true);
  });

  it('fails for completely unrecognizable lines', () => {
    const dsl = `Name: Bad Lines
Description: Garbage steps.
Category: custom
Voice: af_heart
---
xyzgarbage
123456`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('Cannot parse'))).toBe(true);
  });

  // ── Markdown fence stripping ───────────────────────────────────────────

  it('strips markdown code fences from Gemini output', () => {
    const dsl = '```\nName: Fenced\nDescription: Wrapped in fences.\nCategory: custom\nVoice: af_heart\n---\nSay: Hello.\n```';

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.plan!.name).toBe('Fenced');
  });

  // ── Asset alias / drop ────────────────────────────────────────────────

  it('remaps babbling_brook to rain via semantic alias', () => {
    const dsl = `Name: Water Plan
Description: Calming water sounds.
Category: meditation
Voice: af_bella
---
Play: babbling_brook
Say: Relax.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toMatchObject({ type: 'play', assetKey: 'rain' });
    expect(result.repaired.some((r) => r.includes('babbling_brook'))).toBe(true);
  });

  it('remaps waves to ocean via semantic alias', () => {
    const dsl = `Name: Beach
Description: Ocean sounds.
Category: meditation
Voice: af_bella
---
Play: waves
Say: Breathe.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toMatchObject({ type: 'play', assetKey: 'ocean' });
  });

  it('drops a completely unknown asset and succeeds without it', () => {
    const dsl = `Name: Unknown Sound
Description: Has a mystery sound.
Category: custom
Voice: af_heart
---
Play: mystery_synth_pad_v2
Say: Continue.`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    // Play step dropped; only the Say step remains
    expect(steps).toHaveLength(1);
    expect(steps[0].type).toBe('say');
    expect(result.repaired.some((r) => r.includes('dropped'))).toBe(true);
  });

  // ── Count step ──────────────────────────────────────────────────────────

  it('parses "Count: 10" as count 1→10', () => {
    const dsl = `Name: Count Test
Description: Count up.
Category: workout
Voice: am_adam
---
Count: 10`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps).toHaveLength(1);
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 10, intervalSeconds: 1 });
  });

  it('parses "Count: 10 to 1" as countdown', () => {
    const dsl = `Name: Countdown Test
Description: Count down.
Category: workout
Voice: am_adam
---
Count: 10 to 1`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 10, to: 1, intervalSeconds: 1 });
  });

  it('parses "Count: 5 to 15" as partial range', () => {
    const dsl = `Name: Range Count
Description: Partial range.
Category: workout
Voice: am_adam
---
Count: 5 to 15`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 5, to: 15, intervalSeconds: 1 });
  });

  it('parses "Count: 1" as a single-number count', () => {
    const dsl = `Name: One Count
Description: Single.
Category: custom
Voice: af_heart
---
Count: 1`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 1, intervalSeconds: 1 });
  });

  it('auto-repairs typo "Coutn: 10"', () => {
    const dsl = `Name: Typo Count
Description: Typo.
Category: custom
Voice: af_heart
---
Coutn: 10`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    expect(result.repaired.some((r) => r.toLowerCase().includes('coutn'))).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 10, intervalSeconds: 1 });
  });

  it('auto-repairs alias "Countdown: 10"', () => {
    const dsl = `Name: Alias Count
Description: Alias.
Category: custom
Voice: af_heart
---
Countdown: 10`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 10, intervalSeconds: 1 });
  });

  it('fails for non-numeric count value', () => {
    const dsl = `Name: Bad Count
Description: Non-numeric.
Category: custom
Voice: af_heart
---
Count: abc`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('Invalid count'))).toBe(true);
  });

  it('fails for count value of 0', () => {
    const dsl = `Name: Zero Count
Description: Zero.
Category: custom
Voice: af_heart
---
Count: 0`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('Invalid count'))).toBe(true);
  });

  it('fails for span exceeding 100', () => {
    const dsl = `Name: Big Count
Description: Too many.
Category: custom
Voice: af_heart
---
Count: 1 to 200`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('exceed 100'))).toBe(true);
  });

  it('works alongside other step types', () => {
    const dsl = `Name: Mixed Steps
Description: Count mixed in.
Category: workout
Voice: am_adam
---
Say: Hold this position.
Count: 10
Say: Great job!`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps).toHaveLength(3);
    expect(steps[0].type).toBe('say');
    expect(steps[1]).toEqual({ type: 'count', from: 1, to: 10, intervalSeconds: 1 });
    expect(steps[2].type).toBe('say');
  });

  it('works inside a Repeat block', () => {
    const dsl = `Name: Repeat Count
Description: Count in repeat.
Category: workout
Voice: am_adam
---
Repeat: 3
  Say: Hold.
  Count: 5
EndRepeat`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps).toHaveLength(1);
    expect(steps[0].type).toBe('repeat');
    const inner = (steps[0] as any).steps as Array<Record<string, unknown>>;
    expect(inner).toHaveLength(2);
    expect(inner[1]).toEqual({ type: 'count', from: 1, to: 5, intervalSeconds: 1 });
  });

  // ── Count step with interval ────────────────────────────────────────────

  it('parses "Count: 10 every 3s" with custom interval', () => {
    const dsl = `Name: Interval Count
Description: Custom interval.
Category: workout
Voice: am_adam
---
Count: 10 every 3s`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 10, intervalSeconds: 3 });
  });

  it('parses "Count: 10 to 1 every 5s" with countdown and interval', () => {
    const dsl = `Name: Interval Countdown
Description: Countdown with interval.
Category: workout
Voice: am_adam
---
Count: 10 to 1 every 5s`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 10, to: 1, intervalSeconds: 5 });
  });

  it('parses interval without "s" suffix', () => {
    const dsl = `Name: No Suffix
Description: No s.
Category: custom
Voice: af_heart
---
Count: 5 every 2`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(true);
    const steps = result.plan!.steps as Array<Record<string, unknown>>;
    expect(steps[0]).toEqual({ type: 'count', from: 1, to: 5, intervalSeconds: 2 });
  });

  it('rejects interval exceeding 20s', () => {
    const dsl = `Name: Big Interval
Description: Too long.
Category: custom
Voice: af_heart
---
Count: 10 every 25s`;

    const result = parseDslPlan(dsl);
    expect(result.success).toBe(false);
    expect(result.errors.some((e) => e.includes('exceed 20'))).toBe(true);
  });
});
