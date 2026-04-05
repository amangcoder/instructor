# Instructor

## Problem

I don't keep track of time. I get absorbed, deviate, or forget what I was supposed to do. I don't want to constantly think about "what's next" — I want to stay fully present in what I'm doing right now. I need an external conductor that tells me what to do, when.

## Core Concept

**Instructor** is a personal, push-only guide. You create **Plans** — playable, time-sequenced scripts — and run them. During execution, Instructor delivers instructions to you. You never respond to it. You just follow.

- You explicitly **start** a Plan (foreground action)
- The Plan then runs in the **background** — playing audio, firing notifications, speaking instructions — while you go about the activity
- Each instruction in a Plan can be delivered via **voice (TTS)** or **notification**, configured per-instruction
- Audio (ambient music, bells, cues) plays in the background throughout

## The Plan — Core Abstraction

A Plan is a reusable, playable timeline of instructions and actions.

### Instruction Types

| Type | Purpose |
|---|---|
| `say` | Verbal instruction via TTS |
| `notify` | Push notification / on-screen alert |
| `play` | Play audio (music, bell, ambient sound) — runs in background |
| `wait` | Silence / pause for a duration |
| `repeat` | Loop a sub-sequence N times or for N minutes |

Each `say` or `notify` is chosen per-instruction when authoring the Plan — so a yoga Plan might use voice for pose cues but a notification for "5 minutes remaining".

### Plan Properties

- **Duration**: fixed or open-ended
- **Pausable**: can pause and resume from where you left off
- **Background execution**: once started, the Plan runs in the background — audio plays, instructions fire on schedule
- **No confirmation**: never asks "did you do it?" — just moves forward on time
- **Composable**: a Plan can include other Plans (e.g., morning routine embeds a 5-min meditation Plan)

### Example Plan: Morning Yoga (30 min)

```
[0:00]  play: ambient music (forest.mp3)       <- plays in background
[0:00]  say: "Begin in child's pose. Focus on your breath."
[2:00]  say: "Slowly rise to downward dog."
[5:00]  say: "Hold. Notice where you feel tension."
[5:30]  say: "Walk your feet to your hands."
...
[25:00] notify: "5 minutes remaining"
[28:00] play: soft bell
[28:00] say: "Come to stillness. You're done."
[30:00] stop music. End Plan.
```

## Use Cases

| Use Case | Example |
|---|---|
| Yoga session | 30-min guided flow with ambient music, voice cues |
| Meditation | 10-min guided session with bell intervals |
| Morning routine | Sequential: brush, shower, prep breakfast — timed steps |
| Pomodoro work block | 25-min focus + 5-min break, voice instruction at transitions |
| Cooking | Step-by-step recipe with timed waits ("flip in 3 minutes") |
| Wind-down routine | Evening sequence: screen-off cue, reading timer, sleep prep |

## What This Is NOT

- Not a chatbot — no conversation during execution
- Not a to-do app — no checkboxes, no completion tracking
- Not a productivity tracker — no judgement, no metrics
- Not something that needs your attention — it gets YOUR attention when it's time

## Design Principles

1. **Push-only** — Instructor speaks, you do. No "did you finish?" prompts.
2. **Plan once, run many** — Plans are reusable scripts.
3. **Per-instruction delivery** — each instruction is voice or notification, your choice when authoring.
4. **Background execution** — start a Plan, then it runs in the background while you do the activity.
5. **Composable** — Plans can embed other Plans.
6. **Graceful interruption** — pause/resume or stop cleanly.
