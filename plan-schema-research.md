# Plan Schema Research & Recommendation

## 1. How Existing Interval Timer / Workout Apps Define Sequences

### Garmin FIT SDK (Industry Standard for Fitness)
The Garmin FIT format uses a **step-based model** with these key concepts:
- **WorkoutStep**: atomic unit with `duration_type`, `duration_value`, `target_type`, `target_value`, `intensity`
- **Repeat steps**: a special step type (`RepeatUntilStepsCmplt`, `RepeatUntilTime`, `RepeatUntilDistance`) that references back to a previous step index, creating loops
- Steps are flat (not nested), with repeats implemented via back-references -- this is awkward and error-prone

### Zwift ZWO Format (XML-based workout files)
```xml
<workout_file>
  <name>SST (short)</name>
  <author>Coach</author>
  <sportType>bike</sportType>
  <workout>
    <Warmup Duration="300" PowerLow="0.30" PowerHigh="0.70">
      <textevent timeoffset="20" message="Welcome to SST workout"/>
      <textevent timeoffset="120" message="Get your cadence up to 90-100rpm"/>
    </Warmup>
    <IntervalsT Repeat="4" OnDuration="300" OnPower="0.96" OffDuration="300" OffPower="0.88"/>
    <Cooldown Duration="300" PowerLow="0.5" PowerHigh="0.30"/>
  </workout>
</workout_file>
```
Key patterns: typed segments (Warmup/Cooldown/IntervalsT), text events with time offsets relative to segment start, repeat count on interval blocks.

**Critique (from Rene Saarsoo)**: ZWO is overly rigid -- limited block types, no nesting, text events awkwardly embedded in power blocks.

### Seconds Pro (Popular Interval Timer App)
Uses JSON with flat timer segments:
- Each segment has: `name`, `duration` (seconds), `color`, `sound`, spoken cue text
- Sets are groups of segments with a repeat count
- Export/import via JSON files or AirDrop

### SMIL (W3C Standard for Synchronized Multimedia)
The closest existing **standard** for timed multimedia sequences:
```xml
<body>
  <seq>  <!-- sequential -->
    <par>  <!-- parallel -->
      <audio src="music.mp3" dur="30min"/>
      <seq>
        <text dur="2min">Child's pose</text>
        <text dur="3min">Downward dog</text>
      </seq>
    </par>
  </seq>
</body>
```
Three primitives: `<seq>` (sequential), `<par>` (parallel), `<excl>` (exclusive/switch). This is the **most relevant existing standard** for Instructor's needs.

### Serverless Workflow Specification (CNCF)
A YAML/JSON DSL for orchestrating tasks:
- `do` for sequential steps
- `fork` for parallel branches
- Timeouts, delays, and scheduling built in
- Too enterprise-focused, but the sequential/parallel primitives are excellent inspiration

---

## 2. YAML vs JSON vs Custom DSL

### Recommendation: **YAML as primary authoring format, JSON as storage/interchange format**

| Criterion | YAML | JSON | Custom DSL |
|---|---|---|---|
| Human readability | Excellent | Good | Can be excellent |
| Comments | Yes (`#`) | No | Depends |
| Authoring experience | Best for hand-editing | Verbose (quotes, braces) | Requires learning |
| Tooling | Broad support | Universal support | Must build from scratch |
| Nested structures | Clean via indentation | Verbose but explicit | Depends |
| Duration literals | Need custom type (`5m30s`) | Need custom type | Can be native |
| Error messages | Indentation errors are cryptic | Clear syntax errors | Depends |
| Visual builder mapping | Easy bidirectional | Easy bidirectional | Complex bidirectional |
| Type safety | Weak (implicit coercion) | Moderate | Can be strong |

**Decision**: Use YAML for human-authored Plans (files, sharing, documentation). Convert to JSON for storage in the app database. The schema is the same -- just different serializations. Avoid a fully custom DSL because it requires custom tooling, custom syntax highlighting, and creates a learning barrier.

**Duration format**: Use human-friendly short strings like `"5m"`, `"30s"`, `"1h30m"` (Go-style duration) rather than ISO 8601 (`PT5M30S`) which is harder to read, or raw seconds which lose meaning. Parse these into milliseconds at runtime.

---

## 3. Music/Audio Cue Formats

### How existing apps handle audio:
- **Cue sheets**: `mm:ss:ff` format for marking positions in audio files
- **Zwift text events**: `timeoffset` attribute (seconds from segment start)
- **Meditation apps**: named bell sounds (`tibetan_bowl`, `soft_chime`) with interval scheduling
- **SMIL**: `<audio src="..." begin="5s" dur="30min" repeatCount="3"/>`

### Recommended approach for Instructor:
```yaml
# Audio actions in the Plan
- play: forest-ambience.mp3    # starts playing, continues in background
  volume: 0.6
  fade_in: 3s

- play: singing-bowl.mp3       # one-shot sound effect
  mode: once

- play: lo-fi-beats.mp3
  mode: loop                   # loops until explicitly stopped
  volume: 0.4

- stop: lo-fi-beats.mp3        # stop a specific background audio
```

Audio `mode` options:
- `once` (default): play to completion
- `loop`: repeat until stopped or Plan ends
- `background`: alias for loop, semantically clearer

---

## 4. Relative Timing vs Sequential Timing

### Two fundamental models:

**Sequential (after previous step)**:
```yaml
steps:
  - say: "Begin in child's pose"     # starts at t=0
  - wait: 2m                         # waits 2 minutes
  - say: "Rise to downward dog"      # starts at t=2:00
  - wait: 3m
  - say: "Hold the pose"             # starts at t=5:00
```

**Absolute/offset (from Plan start)**:
```yaml
steps:
  - at: 0:00
    say: "Begin in child's pose"
  - at: 2:00
    say: "Rise to downward dog"
  - at: 5:00
    say: "Hold the pose"
```

### Recommendation: **Sequential by default, with optional absolute offsets**

Sequential timing is:
- Easier to author and modify (inserting a step doesn't require recalculating all subsequent times)
- More composable (embedded Plans don't need to know their absolute position)
- How people naturally think about instructions ("do X, then wait, then do Y")

Absolute timing is useful for:
- Parallel tracks (audio that starts at a specific time)
- "Countdown" notifications ("5 minutes remaining")

**Hybrid approach**: Steps execute sequentially. Use `at:` for absolute positioning within a block. Use `wait:` for explicit pauses. Actions without `wait:` between them execute immediately one after another (effectively simultaneous).

---

## 5. Repeating Blocks and Nested Plans

### Repeat patterns from existing systems:
- **Garmin FIT**: flat step list with back-reference repeat (fragile, hard to read)
- **Zwift ZWO**: `Repeat="4"` attribute on interval blocks (simple but limited)
- **SMIL**: `repeatCount` and `repeatDur` on any element
- **Serverless Workflow**: explicit `for` loop construct

### Recommended approach:

```yaml
# Repeat N times
- repeat: 4
  steps:
    - say: "Inhale deeply"
    - wait: 4s
    - say: "Exhale slowly"
    - wait: 4s

# Repeat for a duration
- repeat_for: 10m
  steps:
    - play: bell.mp3
    - wait: 2m

# Nested Plan reference
- run: morning-meditation    # references another Plan by ID/name
  duration: 10m              # optional: override the sub-plan's duration
```

**Key design decisions**:
- `repeat: N` for count-based loops
- `repeat_for: duration` for time-based loops (stops after duration regardless of where in the loop)
- `run: plan-id` for embedding other Plans
- Nested `repeat` blocks are allowed (repeat within repeat)

---

## 6. Existing Standards for Timed Instruction Sequences

| Standard | Domain | Relevance |
|---|---|---|
| **SMIL 3.0** (W3C) | Synchronized multimedia | **HIGH** -- seq/par/excl primitives are directly applicable |
| **Garmin FIT** | Fitness devices | MEDIUM -- workout step model is relevant but too fitness-specific |
| **ZWO** (Zwift) | Cycling workouts | MEDIUM -- good example of what NOT to do (too rigid) |
| **Cue Sheets** | Audio CD tracks | LOW -- audio marker format, not instruction sequences |
| **Serverless Workflow** (CNCF) | Cloud orchestration | MEDIUM -- excellent DSL design, wrong domain |
| **MusicXML** | Sheet music | LOW -- too music-specific |
| **iCalendar/VTODO** | Calendaring | LOW -- event-based, not sequence-based |

**Conclusion**: No existing standard fits Instructor perfectly. SMIL is the closest conceptually (sequential + parallel + timed media), but it's XML-heavy and designed for multimedia presentation, not push-based instruction. The best approach is a **purpose-built YAML schema** that borrows SMIL's seq/par concepts, Garmin's step model, and Serverless Workflow's clean DSL ergonomics.

---

## 7. Making This User-Friendly for a Visual Plan Builder UI

### UI Model: Vertical Block List (like Shortcuts / Zapier)

Based on research of visual workflow builders:

1. **Primary view: vertical step list** -- each step is a card/block
   - Drag to reorder
   - Click to edit properties
   - Color-coded by type (say=blue, wait=gray, play=green, notify=yellow, repeat=purple)

2. **Repeat blocks**: visually indented container blocks (like nested if-blocks in Scratch)
   - Drag steps into/out of repeat blocks
   - Header shows "Repeat 4x" or "Repeat for 10m"

3. **Timeline preview**: horizontal timeline at the top/bottom showing computed absolute times
   - Audio tracks shown as colored bars
   - Say/notify events as markers
   - Updates in real-time as you edit the step list

4. **Sub-plan embedding**: shown as a collapsed card with the sub-plan name
   - Click to expand inline or navigate to sub-plan
   - Shows computed duration

### Data model alignment with UI:

The schema must map cleanly to UI blocks:
- Every step = one draggable card
- `repeat` blocks = container cards
- `run` (sub-plan) = reference cards
- No implicit timing magic -- what you see is what executes

### Key UI/schema constraints:
- Steps array order = execution order (sequential by default)
- Parallel actions use explicit `parallel:` blocks
- Every `wait` is visible as a block (no hidden delays)
- Duration labels computed and shown on each block

---

## 8. Recommended Schema

### Core Types

```typescript
// TypeScript type definitions for the Plan schema

type Duration = string;  // "30s", "5m", "1h30m", "2m30s"

type Voice = "default" | "calm" | "energetic" | "whisper" | string;

type AudioMode = "once" | "loop";

type Step =
  | SayStep
  | NotifyStep
  | PlayStep
  | StopStep
  | WaitStep
  | RepeatStep
  | RepeatForStep
  | ParallelStep
  | RunStep;

interface SayStep {
  say: string;
  voice?: Voice;
  rate?: number;     // speech rate multiplier, default 1.0
}

interface NotifyStep {
  notify: string;
  title?: string;    // notification title (body is the notify string)
}

interface PlayStep {
  play: string;      // audio file name or URI
  volume?: number;   // 0.0 to 1.0, default 1.0
  mode?: AudioMode;  // "once" (default) or "loop"
  fade_in?: Duration;
  fade_out?: Duration;
}

interface StopStep {
  stop: string;      // audio file name to stop, or "all"
  fade_out?: Duration;
}

interface WaitStep {
  wait: Duration;
}

interface RepeatStep {
  repeat: number;    // number of times
  steps: Step[];
}

interface RepeatForStep {
  repeat_for: Duration;
  steps: Step[];
}

interface ParallelStep {
  parallel: {
    [trackName: string]: Step[];
  };
}

interface RunStep {
  run: string;       // Plan ID or name
  params?: Record<string, any>;  // override parameters
}

interface Plan {
  name: string;
  id?: string;
  description?: string;
  version?: number;
  tags?: string[];
  default_voice?: Voice;
  steps: Step[];
}
```

---

## 9. Complete Examples

### Example 1: 30-Minute Yoga Session

```yaml
name: Morning Yoga Flow
description: A gentle 30-minute yoga session with ambient music
tags: [yoga, morning, gentle]
default_voice: calm

steps:
  # Start ambient music
  - play: forest-ambience.mp3
    mode: loop
    volume: 0.4
    fade_in: 5s

  # Opening
  - say: "Welcome. Find a comfortable seat and close your eyes."
  - wait: 10s
  - say: "Take three deep breaths. Inhale through the nose, exhale through the mouth."
  - wait: 30s

  # Warm-up
  - say: "Gently come to child's pose. Rest your forehead on the mat."
  - wait: 2m
  - say: "Slowly rise to tabletop position. Wrists under shoulders, knees under hips."
  - wait: 30s

  # Cat-cow flow
  - say: "Begin cat-cow. Inhale, drop the belly. Exhale, round the spine."
  - repeat: 5
    steps:
      - say: "Inhale, cow pose."
        voice: whisper
      - wait: 5s
      - say: "Exhale, cat pose."
        voice: whisper
      - wait: 5s

  # Standing sequence
  - say: "Step to the top of your mat. Forward fold."
  - wait: 1m
  - say: "Inhale, halfway lift. Exhale, fold."
  - wait: 30s
  - say: "Step back to downward-facing dog. Hold here."
  - wait: 2m

  # Sun salutation flow
  - say: "Let's flow through two sun salutations."
  - repeat: 2
    steps:
      - say: "Inhale, look forward. Exhale, step or hop to the top."
      - wait: 10s
      - say: "Inhale, rise up, arms overhead."
      - wait: 5s
      - say: "Exhale, forward fold."
      - wait: 5s
      - say: "Inhale, halfway lift. Exhale, step back to plank."
      - wait: 10s
      - say: "Lower to chaturanga. Inhale, upward dog."
      - wait: 10s
      - say: "Exhale, press back to downward dog. Hold for five breaths."
      - wait: 30s

  # Warrior sequence
  - say: "Step your right foot forward. Warrior one."
  - wait: 1m30s
  - say: "Open to warrior two."
  - wait: 1m30s
  - say: "Reverse warrior. Reach back."
  - wait: 1m
  - say: "Cartwheel your hands down. Step back to downward dog."
  - wait: 30s
  - say: "Now the left side. Step your left foot forward. Warrior one."
  - wait: 1m30s
  - say: "Open to warrior two."
  - wait: 1m30s
  - say: "Reverse warrior."
  - wait: 1m

  # Cool down
  - notify: "5 minutes remaining"
  - say: "Come to a seated position. Let's cool down."
  - wait: 30s
  - say: "Seated forward fold. Let gravity do the work."
  - wait: 1m30s
  - say: "Lie back for savasana. Let your body be completely still."
  - wait: 2m

  # Closing
  - play: singing-bowl.mp3
    volume: 0.7
  - wait: 10s
  - say: "Begin to bring awareness back to your body. Wiggle your fingers and toes."
  - wait: 20s
  - say: "When you're ready, roll to one side and press up to a seat."
  - wait: 15s
  - say: "Namaste. You're done."

  - stop: forest-ambience.mp3
    fade_out: 5s
```

### Example 2: 10-Minute Meditation with Repeating Bell Intervals

```yaml
name: Morning Meditation
description: 10-minute breath-awareness meditation with bell every 2 minutes
tags: [meditation, breathing, morning]
default_voice: whisper

steps:
  # Opening
  - play: singing-bowl.mp3
  - wait: 3s
  - say: "Find your seat. Close your eyes. Settle in."
  - wait: 15s
  - say: "Bring your attention to the breath. Don't control it. Just notice."
  - wait: 30s
  - say: "Each time the mind wanders, gently return to the breath."
  - wait: 12s

  # Main meditation block -- bell every 2 minutes
  - repeat: 4
    steps:
      - wait: 2m
      - play: tibetan-bell.mp3
        volume: 0.5

  # Closing
  - wait: 30s
  - say: "Begin to deepen your breath."
  - wait: 15s
  - say: "Gently open your eyes."
  - wait: 10s
  - play: singing-bowl.mp3
  - wait: 3s
  - say: "Your meditation is complete. Carry this stillness with you."
```

### Example 3: Morning Routine with Embedded Sub-Plans

```yaml
name: Weekday Morning
description: Full morning routine from wake-up to out the door
tags: [morning, routine, weekday]
default_voice: energetic

steps:
  # Wake up
  - play: gentle-alarm.mp3
  - wait: 5s
  - say: "Good morning. Time to start your day."
  - wait: 10s

  # Meditation (embedded sub-plan)
  - say: "Let's begin with a short meditation."
  - run: morning-meditation

  # Exercise
  - say: "Meditation complete. Time to move your body."
  - wait: 10s
  - run: quick-stretch-routine

  # Shower & prep
  - play: upbeat-playlist.mp3
    mode: loop
    volume: 0.3
  - say: "Time to shower. You have 10 minutes."
  - wait: 8m
  - notify: "2 minutes left for shower"
  - wait: 2m
  - say: "Shower time is up. Get dressed."
  - wait: 5m

  # Breakfast
  - say: "Head to the kitchen. Breakfast time. You have 15 minutes."
  - wait: 10m
  - notify: "5 minutes left for breakfast"
  - wait: 5m

  # Out the door
  - stop: upbeat-playlist.mp3
    fade_out: 3s
  - say: "Time to go. Grab your keys, wallet, and phone."
  - wait: 15s
  - say: "Have a great day."

# Sub-plan definitions (these would be separate Plan files):
# morning-meditation: see Example 2 above
# quick-stretch-routine: a 5-minute stretch plan
```

### Example 4: Cooking Recipe with Parallel Timers

```yaml
name: Pasta with Garlic Bread
description: Cook pasta and garlic bread simultaneously, everything ready together
tags: [cooking, dinner, pasta]
default_voice: default

steps:
  - say: "Let's make pasta with garlic bread. Gather your ingredients."
  - wait: 30s
  - notify: "Ingredients: pasta, sauce, garlic, bread, butter, parmesan"
  - wait: 1m

  # Preheat
  - say: "Preheat the oven to 375 degrees for the garlic bread."
  - wait: 30s
  - say: "Fill a large pot with water and put it on high heat."
  - wait: 30s

  # Wait for water + oven
  - say: "We'll wait for the water to boil. This takes about 8 minutes."
  - wait: 5m
  - say: "While waiting, prepare the garlic bread. Slice the bread, spread butter and minced garlic."
  - wait: 3m

  # Parallel cooking phase
  - say: "Water should be boiling. Let's start both timers."
  - parallel:
      pasta:
        - say: "Add pasta to the boiling water. Stir once."
        - wait: 5m
        - say: "Stir the pasta."
        - wait: 3m
        - say: "Check the pasta. It should be almost al dente."
        - wait: 2m
        - say: "Pasta is done. Drain it now."

      garlic_bread:
        - say: "Put the garlic bread in the oven."
        - wait: 8m
        - notify: "Check garlic bread -- should be golden brown"
        - wait: 2m
        - say: "Remove garlic bread from the oven."

  # Both done, assemble
  - play: ding.mp3
  - say: "Both are done. Toss the pasta with sauce and plate it up."
  - wait: 1m
  - say: "Slice the garlic bread and serve alongside."
  - wait: 30s
  - say: "Dinner is ready. Enjoy your meal."
```

---

## 10. Schema Design Decisions Summary

| Decision | Choice | Rationale |
|---|---|---|
| Format | YAML (authoring) + JSON (storage) | YAML is readable; JSON is universal for APIs/DBs |
| Timing model | Sequential by default | Easier to author, modify, and compose |
| Duration syntax | Human-friendly (`5m30s`) | More readable than ISO 8601 or raw seconds |
| Repeat | `repeat: N` and `repeat_for: duration` | Covers both count-based and time-based loops |
| Parallelism | `parallel:` block with named tracks | Named tracks map well to UI and are debuggable |
| Composability | `run: plan-id` | Simple reference model, like function calls |
| Audio | `play:` / `stop:` with mode/volume | Covers one-shot, looping, and fade effects |
| Voice | `voice:` per-step, `default_voice:` per-plan | Flexible without being verbose |
| Delivery | `say:` vs `notify:` as separate types | Per the original design, delivery method is per-instruction |

## 11. Implementation Notes

### Duration parsing
Support these formats and parse to milliseconds at runtime:
- `30s` -> 30000
- `5m` -> 300000
- `2m30s` -> 150000
- `1h` -> 3600000
- `1h30m` -> 5400000

### Parallel block execution
A `parallel:` block completes when its **longest track** finishes. All tracks start simultaneously. Each track is an independent sequential step list.

### Repeat-for semantics
`repeat_for: 10m` starts the step sequence, and when it completes, restarts it. When 10 minutes total have elapsed, it stops -- even mid-step. The last `say`/`play` that started will complete (don't cut off mid-speech), but the next step won't begin.

### Sub-plan resolution
`run: plan-id` resolves the plan by ID from the user's plan library. At execution time, the sub-plan's steps are inlined into the execution timeline. Circular references must be detected at validation time.

### Visual builder data model
The YAML schema maps directly to a tree of UI blocks:
```
Plan
  └── steps[]
        ├── SayBlock
        ├── WaitBlock
        ├── PlayBlock
        ├── NotifyBlock
        ├── RepeatBlock
        │     └── steps[] (recursive)
        ├── ParallelBlock
        │     ├── track "name1" -> steps[]
        │     └── track "name2" -> steps[]
        └── RunBlock (reference to another Plan)
```

This tree structure maps to:
- A **flat vertical list** for the step editor (drag & drop)
- A **horizontal timeline** for the preview (computed from durations)
- A **block nesting** visualization for repeat/parallel containers

---

## Sources

- [Garmin FIT SDK - Workout File Types](https://developer.garmin.com/fit/file-types/workout/)
- [Garmin FIT SDK - Encoding Workout Files](https://developer.garmin.com/fit/cookbook/encoding-workout-files/)
- [Zwift Workout File Reference](https://github.com/h4l/zwift-workout-file-reference/blob/master/zwift_workout_file_tag_reference.md)
- [Why the ZWO format sucks](https://nene.github.io/2021/01/14/zwo-sucks)
- [SMIL 3.0 W3C Recommendation](https://www.w3.org/TR/SMIL3/)
- [SMIL Wikipedia](https://en.wikipedia.org/wiki/Synchronized_Multimedia_Integration_Language)
- [Serverless Workflow Specification](https://github.com/serverlessworkflow/specification)
- [Serverless Workflow DSL](https://github.com/serverlessworkflow/specification/blob/main/dsl.md)
- [ISO 8601 Duration Format](https://en.wikipedia.org/wiki/ISO_8601)
- [YAML vs JSON Comparison (AWS)](https://aws.amazon.com/compare/the-difference-between-yaml-and-json/)
- [YAML vs JSON (SnapLogic)](https://www.snaplogic.com/blog/json-vs-yaml-whats-the-difference-and-which-one-is-right-for-your-enterprise)
- [Seconds Pro Interval Timer](https://www.intervaltimer.com/)
- [Exercise Timer App](https://exercisetimer.net/)
- [react-timeline-editor](https://github.com/xzdarcy/react-timeline-editor)
- [Workflow Builder (React Flow)](https://reactflow.dev/ui/templates/workflow-editor)
- [Temporal YAML DSL](https://medium.com/@surajsub_68985/using-temporal-and-yaml-as-dsl-for-orchestration-3fa38405f65d)
- [Cue Sheet Specification](https://wyday.com/cuesharp/specification.php)
- [TrainingPeaks Structured Workouts](https://help.trainingpeaks.com/hc/en-us/articles/115000325647-Structured-Workout-sync-and-Manual-Export)
- [Mealie Recipe Timer Discussion](https://github.com/mealie-recipes/mealie/discussions/1573)
