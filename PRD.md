# Instructor — Product Requirements Document

**Version**: 1.0
**Date**: April 5, 2026
**Status**: Draft

---

## Table of Contents

1. [Vision & Problem Statement](#1-vision--problem-statement)
2. [Core Concept](#2-core-concept)
3. [Competitive Landscape](#3-competitive-landscape)
4. [Target Users](#4-target-users)
5. [The Plan — Core Abstraction](#5-the-plan--core-abstraction)
6. [Plan Schema & DSL](#6-plan-schema--dsl)
7. [Feature Requirements](#7-feature-requirements)
8. [UX & Design](#8-ux--design)
9. [Technical Architecture](#9-technical-architecture)
10. [AI Integration](#10-ai-integration)
11. [Monetization & Business Model](#11-monetization--business-model)
12. [Go-to-Market Strategy](#12-go-to-market-strategy)
13. [MVP Scope](#13-mvp-scope)
14. [Roadmap](#14-roadmap)
15. [Risks & Mitigations](#15-risks--mitigations)
16. [Success Metrics](#16-success-metrics)

---

## 1. Vision & Problem Statement

### The Problem

People lose track of time. They get absorbed, deviate, or forget what they were supposed to do next. The mental overhead of constantly tracking "what's next" pulls them out of the present moment — creating anxiety and reducing the quality of whatever they're doing right now.

Existing solutions fall into two failing categories:
- **To-do apps** require you to check them — they demand your attention
- **Pre-recorded guided content** (meditation apps, workout videos) isn't customizable — you follow someone else's plan or nothing

There is no tool that lets you **author your own timed guidance** and have it **run autonomously in the background**, telling you what to do without requiring any interaction.

### The Vision

**Instructor** is a personal, push-only life conductor. You create **Plans** — playable, time-sequenced scripts — and run them. During execution, Instructor delivers instructions via voice and notifications while playing ambient audio. You never respond to it. You just follow.

Think of it as **a playlist, but for actions instead of songs.**

---

## 2. Core Concept

### How It Works

1. **Author** a Plan — a sequence of timed instructions, audio cues, and pauses
2. **Start** the Plan (explicit foreground action)
3. **Follow** — the Plan runs in the background, speaking instructions and playing audio on schedule
4. **Done** — the Plan ends, you move on

### Core Design Principles

| Principle | Meaning |
|---|---|
| **Push-only** | Instructor speaks, you do. Never asks "did you finish?" |
| **Plan once, run many** | Plans are reusable scripts you can play repeatedly |
| **Per-instruction delivery** | Each instruction can be voice (TTS) or notification — author's choice |
| **Background execution** | Start a Plan, then it runs while you do the activity |
| **Composable** | Plans can embed other Plans |
| **Graceful interruption** | Pause/resume or stop cleanly at any time |

### What Instructor Is NOT

- Not a chatbot — no conversation during execution
- Not a to-do app — no checkboxes, no completion tracking
- Not a productivity tracker — no judgement, no metrics
- Not something that needs your attention — it gets YOUR attention when it's time

---

## 3. Competitive Landscape

### Market Gap

No single app combines: (a) user-authored arbitrary TTS instructions, (b) time-sequenced plan execution, (c) ambient audio layering, (d) true push-only background delivery, and (e) domain-agnostic flexibility. Every existing product is locked into one vertical.

### Key Competitors

| App | Category | What It Does | Key Limitation vs Instructor |
|---|---|---|---|
| **Seconds Pro** | Interval Timer | Custom HIIT/Tabata timers with spoken interval names | Fitness-only; speaks labels, not full instructions; no ambient audio |
| **Intervals Pro** | Interval Timer | Configurable HIIT timer with spoken alerts | iOS-only; fitness-locked; short spoken labels only |
| **Routinery** | Routine Planner | Step-by-step timed routines with voice alerts | Routine/habit-only; speaks task names, not rich instructions; no ambient audio |
| **Insight Timer** | Meditation | Meditation timer with interval bells and ambient sounds | No guided instruction builder — bells only, not TTS |
| **SpeakTimer** | Voice Timer | Custom speech text at any point in a countdown | Closest mechanical competitor — but no Plan abstraction, no ambient audio, no community |
| **Vital AI** | AI Meditation | AI-generated spoken meditations | AI-generated one-shot sessions, not user-authored reusable plans |
| **ChefTalk AI** | Cooking | Voice-first cooking companion | Requires voice interaction (not push-only); cooking-only |
| **Focus Bear** | ADHD/Productivity | Routine automation with device locking | Coercive (locks device); no TTS guidance; no ambient audio |
| **Headspace/Calm** | Meditation | Pre-recorded guided meditation and wellness | Pre-authored content only; can't create your own sessions |

### Competitive Advantage

Instructor is the **first general-purpose guided routine player**. The key differentiator: **"Runs in the background. No screen. Just do."**

---

## 4. Target Users

### Primary Persona: Self-Guided Practitioner

People who practice activities independently (yoga at home, self-led meditation, solo workouts, home cooking) and want structured guidance without a live instructor or pre-recorded video.

**Characteristics:**
- Already does the activity, wants better time structure
- Frustrated by watching screens during physical activities
- Values customization over pre-made content
- Willing to spend 5 minutes building a Plan for repeated use

### Secondary Persona: Routine Builder

People who struggle with time management, ADHD-adjacent attention patterns, or simply want their daily routines automated.

**Characteristics:**
- Loses track of time regularly
- Wants a "conductor" for morning/evening routines
- Prefers being told what to do over checking a list

### Tertiary Persona: Instructor/Creator

Yoga teachers, personal trainers, cooking instructors who want to create and share guided Plans with students/clients.

**Characteristics:**
- Creates content for others
- Wants to publish or sell Plans
- Needs branding and distribution tools

---

## 5. The Plan — Core Abstraction

A **Plan** is a reusable, playable timeline of instructions and actions. It is the single core entity in the product.

### Instruction Types

| Type | Purpose | Delivery |
|---|---|---|
| `say` | Verbal instruction | TTS voice output |
| `notify` | Alert / reminder | Push notification or on-screen |
| `count` | Speak sequential numbers at a cadence (e.g., "1... 2... 3...") | TTS voice counting |
| `play` | Audio (music, bell, ambient sound) | Background audio playback |
| `stop` | Halt a playing audio track | Stops specified audio |
| `wait` | Silence / pause for a duration | Timer only |
| `repeat` | Loop a sub-sequence N times | Container for nested steps |
| `repeat_for` | Loop a sub-sequence for a duration | Time-bounded container |
| `parallel` | Run multiple tracks concurrently | Multi-lane container |
| `run` | Embed another Plan | Sub-plan reference |

### Plan Properties

| Property | Description |
|---|---|
| **id** | Unique identifier |
| **name** | Human-readable title |
| **description** | Optional summary |
| **category** | yoga, meditation, workout, cooking, routine, focus, custom |
| **duration** | Fixed (e.g., 30m) or open-ended |
| **tags** | Searchable labels |
| **voice** | Default TTS voice for `say` instructions |
| **steps** | Ordered list of instructions |

### Plan Behaviors

- **Pausable**: can pause and resume from exact position
- **Background execution**: audio plays and instructions fire while screen is off
- **No confirmation**: never asks "did you do it?" — advances purely on time
- **Composable**: Plans can embed other Plans via `run`
- **Offline**: executes fully offline once downloaded

---

## 6. Plan Schema & DSL

### Format Decision

- **YAML** for human authoring (readable, supports comments, minimal syntax noise)
- **JSON** for storage, API interchange, and the visual editor's internal model
- **Go-style durations** for readability: `5m`, `30s`, `2m30s`, `1h30m`

### Schema Primitives

```yaml
# Say — verbal instruction via TTS
- say: "Begin in child's pose. Focus on your breath."
  voice: calm-female          # optional, overrides Plan default

# Notify — push notification
- notify: "5 minutes remaining"

# Play — start audio
- play: forest-ambience.mp3
  mode: loop                  # once | loop (default: once)
  volume: 0.6                 # 0.0–1.0
  fade_in: 3s                 # optional

# Stop — halt audio
- stop: forest-ambience.mp3
  fade_out: 5s                # optional

# Count — speak sequential numbers at a cadence
- count:
    from: 1
    to: 10
    interval: 3s              # time between each number
    voice: energetic-male      # optional, overrides Plan default

# Count with custom format
- count:
    from: 1
    to: 30
    interval: 1s
    say_every: 5               # only speak every 5th number (5, 10, 15...)
    say_last: 3                # always speak the last 3 (28, 29, 30)

# Wait — pause
- wait: 2m30s

# Repeat — count-based loop
- repeat: 4
  steps:
    - say: "Inhale deeply."
    - wait: 4s
    - say: "Exhale slowly."
    - wait: 4s

# Repeat for duration — time-based loop
- repeat_for: 10m
  steps:
    - play: bell.mp3
    - wait: 2m

# Parallel — concurrent tracks
- parallel:
    music:
      - play: ambient.mp3
        mode: loop
    instructions:
      - say: "Begin stretching."
      - wait: 5m
      - say: "Switch sides."

# Run — embed sub-plan
- run: morning-meditation     # references Plan by ID
```

### Example: Morning Yoga (30 min)

```yaml
name: Morning Yoga Flow
category: yoga
duration: 30m
voice: calm-female
steps:
  - play: forest-ambience.mp3
    mode: loop
    volume: 0.4
    fade_in: 5s

  - say: "Welcome. Let's begin in child's pose. Focus on your breath."
  - wait: 2m

  - say: "Slowly rise to downward dog. Spread your fingers wide."
  - wait: 3m

  - say: "Step your right foot forward into a low lunge."
  - wait: 1m30s

  - say: "Now your left foot forward. Hold."
  - wait: 1m30s

  - repeat: 3
    steps:
      - say: "Sun salutation. Inhale, reach up."
      - wait: 30s
      - say: "Exhale, fold forward."
      - wait: 30s
      - say: "Step back to plank. Hold."
      - wait: 20s
      - say: "Lower to the ground. Cobra pose."
      - wait: 20s
      - say: "Push back to downward dog."
      - wait: 40s

  - notify: "5 minutes remaining"
  - say: "Come to a seated position for cool-down."
  - wait: 3m

  - play: bell.mp3
  - say: "Namaste. Your practice is complete."
  - wait: 10s

  - stop: forest-ambience.mp3
    fade_out: 5s
```

### Example: Meditation with Repeating Bells (10 min)

```yaml
name: Mindful Breathing
category: meditation
duration: 10m
voice: gentle-male
steps:
  - play: singing-bowl.mp3
  - say: "Find a comfortable position. Close your eyes."
  - wait: 30s
  - say: "Bring attention to your breath. Simply observe."
  - wait: 30s

  - repeat_for: 8m
    steps:
      - wait: 2m
      - play: soft-bell.mp3

  - play: singing-bowl.mp3
  - say: "Gently bring your awareness back. Open your eyes when ready."
  - wait: 30s
```

### Example: Plank & Core Workout with Counting (15 min)

```yaml
name: Core Burn
category: workout
duration: 15m
voice: energetic-male
steps:
  - play: upbeat-track.mp3
    mode: loop
    volume: 0.3

  - say: "Let's go. Starting with a forearm plank."
  - count:
      from: 1
      to: 30
      interval: 1s
  - play: bell.mp3
  - say: "Rest."
  - wait: 15s

  - say: "Right side plank."
  - count:
      from: 1
      to: 20
      interval: 1s
  - play: bell.mp3
  - say: "Switch. Left side."
  - count:
      from: 1
      to: 20
      interval: 1s
  - play: bell.mp3
  - say: "Rest."
  - wait: 15s

  - repeat: 3
    steps:
      - say: "Bicycle crunches."
      - count:
          from: 1
          to: 20
          interval: 1s
          say_every: 5
          say_last: 3
      - play: bell.mp3
      - say: "Rest."
      - wait: 10s

  - say: "Final plank. Hold as long as you can."
  - count:
      from: 1
      to: 60
      interval: 1s
      say_every: 10
      say_last: 5
  - play: bell.mp3
  - say: "Done. Great work."

  - stop: upbeat-track.mp3
    fade_out: 3s
```

### Example: Morning Routine with Embedded Plans

```yaml
name: Morning Routine
category: routine
duration: 45m
steps:
  - say: "Good morning. Time to start your day."
  - say: "Head to the bathroom. Brush your teeth."
  - wait: 5m

  - run: morning-meditation       # embedded 10-min meditation Plan

  - say: "Time for breakfast. Head to the kitchen."
  - wait: 20m

  - notify: "Leave for work in 10 minutes"
  - wait: 10m
  - say: "Time to go. Have a great day."
```

### Example: Cooking with Parallel Timers

```yaml
name: Pasta with Sauce
category: cooking
steps:
  - say: "Let's make pasta with tomato sauce. Start by gathering ingredients."
  - wait: 2m

  - parallel:
      pasta:
        - say: "Fill a large pot with water and set to boil."
        - wait: 8m
        - say: "Water should be boiling. Add salt and pasta."
        - wait: 10m
        - play: timer-ding.mp3
        - say: "Pasta is done. Drain and set aside."
      sauce:
        - say: "Heat olive oil in a pan. Add minced garlic."
        - wait: 2m
        - say: "Add crushed tomatoes and stir."
        - wait: 5m
        - say: "Season with salt, pepper, and basil. Reduce heat."
        - wait: 11m
        - say: "Sauce is ready."

  - say: "Combine pasta and sauce. Plate and enjoy."
```

---

## 7. Feature Requirements

### P0 — Must Have (MVP)

| Feature | Description |
|---|---|
| **Plan Editor** | Create, edit, reorder, duplicate steps in a Plan |
| **Plan Player** | Execute Plans with TTS, notifications, and audio in background |
| **Background Audio** | Play ambient audio/music continuously during Plan execution |
| **TTS Delivery** | Speak instructions via high-quality voice synthesis |
| **Notification Delivery** | Send push notifications for `notify` steps |
| **Audio Mixing** | Overlay TTS on ambient audio with automatic volume ducking |
| **Pause/Resume** | Pause Plan execution and resume from exact position |
| **Stop** | End Plan execution cleanly |
| **Lock Screen Controls** | Play/pause/skip from lock screen and headphone buttons |
| **Starter Plans** | 10-15 pre-built Plans across key categories |
| **Plan Library** | Browse, search, and organize personal Plans |
| **Per-instruction delivery choice** | Author chooses voice or notification per instruction |
| **Repeat blocks** | Count-based and duration-based loops |
| **Offline execution** | Plans execute fully without network |

### P1 — Should Have (v1.1–v1.5)

| Feature | Description |
|---|---|
| **AI Plan Generation** | Generate Plans from natural language descriptions |
| **Multiple TTS Voices** | 3-5 voice personas (calm, energetic, gentle) |
| **Plan Composability** | Embed sub-Plans via `run` |
| **Parallel Tracks** | Concurrent instruction tracks (for cooking, etc.) |
| **Widgets** | Home screen widget for quick Plan launch |
| **Apple Watch / WearOS** | Wrist controls: pause, skip, step display, haptics |
| **Calendar Integration** | Schedule Plans at specific times |
| **Import/Export** | Share Plans as YAML/JSON files |
| **Streak Tracking** | Visual streak counter for repeated Plans |
| **Dynamic Island / Live Activity** | Show current step on iOS lock screen |

### P2 — Nice to Have (v2.0+)

| Feature | Description |
|---|---|
| **Plan Marketplace** | Browse and share community Plans |
| **Voice Commands** | "Pause", "Skip", "Repeat" during execution |
| **Custom Voice Cloning** | Create personalized instructor voices |
| **Import from URL** | Convert YouTube videos / recipe URLs into Plans |
| **Adaptive Plans** | AI adjusts Plans based on usage history |
| **Siri / Google Assistant** | "Hey Siri, start my morning routine" |
| **B2B Creator Tools** | Branded Plans, client management, usage analytics |
| **AI Soundscapes** | Generated ambient audio matched to activity type |
| **Embeddable Player** | Embed Plans on any website/app via iframe, SDK, or web component |
| **Public API** | REST/GraphQL API for creating, managing, and triggering Plans programmatically |
| **Web Player** | Browser-based Plan player (no app install required) |

---

## 8. UX & Design

### Design Philosophy: The Invisible App

The best version of Instructor is one the user **forgets they're using** during execution. Every design decision is filtered through: *"Does this require the user to look at their phone?"* If yes, eliminate it or make it optional.

### Interaction Hierarchy During Execution

1. **Voice** — primary. All instructions delivered as speech.
2. **Haptics** — secondary. Step transitions felt on wrist/phone.
3. **Audio cues** — tertiary. Chimes, bells for transitions.
4. **Visual** — last resort. Only for users who choose to look.

### Key Screens

#### Home — My Plans

- List of user's Plans sorted by recent use
- Each card shows: name, category icon, duration, last-used date
- One-tap to start a Plan (with 3-second countdown)
- "+" button to create new Plan
- Search/filter by category

#### Plan Editor

- **Vertical card list** — each step is a draggable card, color-coded by type
- **Inline editing** — tap a card to expand and edit in-place (no separate screen)
- **Drag-and-drop reordering** with haptic feedback
- **Insert between steps** — "+" between cards in edit mode
- **Repeat blocks** shown as container cards with nested steps (like Scratch blocks)
- **Total duration** always visible at top, updating in real-time
- **Preview/dry-run** — play through at 4x speed to verify
- **Templates** — start from a pre-built template and customize

#### Active Session (Now Playing)

- **Large timer** showing time remaining in current step
- **Current step text** in large font above timer
- **"Next up"** in smaller text below
- **Minimal controls**: tap anywhere to pause/resume
- **Background color shift** by step type (subtle, glanceable from across room)
- **Auto-dim** after 10 seconds of no touch (30% brightness, timer only)
- **No scrolling, no menus, no lists** — single static view

#### Session Controls During Execution

| Action | Gesture | Confirmation? |
|---|---|---|
| Pause | Tap anywhere / hardware button | No |
| Resume | Tap anywhere / hardware button | No |
| Skip step | Swipe right or double-tap | No |
| Go back | Swipe left or triple-tap | No |
| End session | Swipe down or hold pause 2s | Single prompt |
| Volume | Hardware buttons | No |

### Interruption Handling

- **Phone call**: Auto-pause. On call end: "Your plan is paused. Tap to resume."
- **Other app notifications**: Don't pause. Voice ducks momentarily, resumes.
- **App switch**: Plan continues in background (like music). Persistent notification shown.
- **App crash**: State persisted to disk every step transition. Offer resume on next launch.

### Onboarding

1. Three-screen carousel: (1) "Create timed plans for any activity" (2) "Voice guides you, so you stay focused" (3) "Let's build your first plan"
2. Immediately funnel into guided Plan creation from a template
3. Never show an empty "My Plans" screen
4. Progressive disclosure — start with basic steps, unlock advanced features (repeat blocks, parallel tracks) as user creates more Plans

### Accessibility

- **VoiceOver/TalkBack**: Accessible pause button alongside full-screen tap target
- **Hearing impairments**: Strong haptic feedback at step transitions; instruction text displayed on screen; color-coded backgrounds
- **Motor impairments**: Full-screen tap target for pause; Switch Control support
- **Low vision**: Dynamic Type support; maximum contrast; large timer regardless of system text size

---

## 9. Technical Architecture

### Platform & Stack

**Recommendation: Flutter**

| Component | Technology | Rationale |
|---|---|---|
| Framework | **Flutter** | Best balance of cross-platform + native audio integration |
| Background execution | **audio_service** | Battle-tested; handles iOS audio mode + Android foreground service |
| Audio playback | **just_audio** | Multiple simultaneous players, gapless, background-capable |
| TTS (high quality) | **Pre-rendered via OpenAI TTS** | Best quality, zero runtime latency, works offline |
| TTS (fallback) | **flutter_tts** (platform TTS) | For dynamic/user-edited content |
| Audio mixing | **Two just_audio players** with coordinated volume | Ambient track + voice/effect track |
| Timer engine | **Dart Timer inside audio_service isolate** | Reliable with active audio session |
| Local notifications | **flutter_local_notifications** | Backup alerts and session reminders |
| Lock screen controls | **Built into audio_service** | Play/pause/skip from lock screen |
| State management | **Riverpod** | For session, timer, and playback state |
| Local storage | **SQLite (drift)** | Plans, preferences, history |
| Cloud sync (future) | **Firebase / Supabase** | User accounts, Plan sync |

### Background Execution Strategy

#### iOS
- Declare `UIBackgroundModes: audio` in Info.plist
- Maintain active `AVAudioSession` with category `.playback`
- Ambient music playback keeps the app alive; `DispatchSourceTimer` fires with sub-100ms precision
- Local notifications scheduled as backup safety net (max 64 pending)

#### Android
- Start Foreground Service with `foregroundServiceType="mediaPlayback"`
- Persistent notification with session controls
- `Handler.postDelayed()` for in-process timing (sub-50ms precision)
- Prompt user to disable battery optimization on aggressive OEMs (Xiaomi, Samsung, Huawei)

### Audio Mixing Architecture

```
┌─────────────────────────────────────────────────┐
│              Session Engine (Background)         │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         Timeline Scheduler                │   │
│  │  Events: [(time, action)]                 │   │
│  │  High-precision timer (wall-clock based)  │   │
│  │  Drift compensation via absolute times    │   │
│  └──────────────┬───────────────────────────┘   │
│                 │                                │
│  ┌──────────────▼───────────────────────────┐   │
│  │         Audio Mixer                       │   │
│  │  ┌──────────────┐  ┌─────────────────┐   │   │
│  │  │ Ambient       │  │ Voice/Effects   │   │   │
│  │  │ Player        │  │ Player          │   │   │
│  │  │ (continuous)  │  │ (on-demand)     │   │   │
│  │  └──────────────┘  └─────────────────┘   │   │
│  │  Volume ducking: ambient → 20% during    │   │
│  │  voice, restore after with smooth fade   │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Platform Integration                     │   │
│  │  - Lock screen / Now Playing controls     │   │
│  │  - Local notification backup              │   │
│  │  - Audio session management               │   │
│  │  - Live Activity / Dynamic Island (iOS)   │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Timer Precision

| Scenario | Precision |
|---|---|
| App in foreground | <10ms |
| Background + active audio session (iOS) | <100ms |
| Background + foreground service (Android) | <50ms |
| Local notification trigger | +/- 1-5 seconds |

Sub-100ms precision is more than sufficient for timed instruction sequences.

### Data Flow

```
Plan (YAML/JSON) → Parse → Timeline Events → Session Engine → Audio/TTS/Notifications
                                                    ↕
                                              State Persistence (SQLite)
                                                    ↕
                                              UI (Now Playing screen)
```

---

## 10. AI Integration

### MVP AI Features

| Feature | Implementation | Cost |
|---|---|---|
| **AI Plan Generation** | GPT-4o-mini / Claude Haiku with structured JSON output | ~$0.005/Plan |
| **3-5 Instructor Voices** | OpenAI TTS, pre-generated at Plan creation | ~$0.015/Plan |
| **Basic Personalization** | User profile (fitness level, goals) injected into LLM prompt | Negligible |

#### AI Plan Generation Flow

1. User types: *"Create a 15-minute morning stretch routine for someone with lower back pain"*
2. App sends request to LLM with Plan schema + user profile context
3. LLM returns structured JSON matching Plan format
4. App generates TTS audio for each `say` step (cached locally)
5. User can edit, then play

**Estimated cost**: $0.02-0.08 per Plan (LLM + TTS). At 10K Plans/month = ~$200-800/month.

### Post-MVP AI Features

| Feature | Description | When |
|---|---|---|
| **Iterative refinement** | "Make it harder" / "Swap out downward dog" — multi-turn LLM conversation | v1.5 |
| **History-based personalization** | Include last 5-10 sessions in LLM context | v2.0 |
| **Import from URL** | Convert YouTube videos / recipe blogs into Plans (Whisper + LLM) | v2.0 |
| **Voice commands** | "Pause", "Skip", "Repeat" via native speech recognition (free, on-device) | v2.0 |
| **Adaptive ambient music** | Mubert API for infinite non-repeating ambient tracks ($14/mo) | v2.0 |

### Future AI Features

| Feature | Description | When |
|---|---|---|
| **Custom voice cloning** | ElevenLabs voice cloning for personalized instructor voice | v3.0 |
| **Real-time adaptive Plans** | LLM dynamically adjusts remaining steps mid-session | v3.0 |
| **On-device LLM** | Llama-class model for offline Plan generation | v3.0 |
| **Computer vision form checking** | On-device pose estimation for exercise form | v3.0+ |

### TTS Strategy

| Tier | Engine | Quality | Latency | Cost | Use Case |
|---|---|---|---|---|---|
| **Primary** | OpenAI TTS (pre-rendered) | 9/10 | None (cached) | $15/1M chars | All Plans — generated at creation time |
| **Fallback** | Platform TTS (AVSpeechSynthesizer / Google TTS) | 7/10 | <100ms | Free | Dynamic content, offline edits |
| **Premium** (future) | ElevenLabs | 10/10 | Pre-rendered | $5-99/mo | Custom voices, premium tier |

**Key architecture decision**: Pre-generate all TTS audio at Plan creation time. No runtime TTS. This eliminates latency, enables full offline playback, and gives highest quality.

### Privacy-First AI

- All user data stored on-device (SQLite)
- LLM calls send only the prompt + preferences — never usage history unless explicitly needed
- TTS audio cached locally after generation
- Voice commands processed on-device via native speech recognition (never sent to cloud)
- Position as: *"Your routines, your device, your data"*

### Embeddable Player & Platform API

A key strategic differentiator: Instructor isn't just an app — it's a **platform** that other websites and apps can integrate.

#### Embeddable Web Player

Any website can embed an Instructor Plan player, similar to embedding a YouTube video or Spotify playlist:

```html
<!-- Embed a Plan on any website -->
<iframe src="https://instructor.app/embed/plan-id"
        width="400" height="120"
        allow="autoplay; microphone"
        frameborder="0">
</iframe>

<!-- Or use the web component -->
<instructor-player plan-id="abc123" theme="dark" />
<script src="https://instructor.app/sdk/v1/player.js"></script>
```

**Use cases for embeds:**
- A yoga teacher embeds a guided flow on their personal website
- A recipe blog embeds a cooking timer Plan alongside their recipe
- A fitness article embeds a workout Plan readers can start in-browser
- A corporate wellness portal embeds routines for employees

#### JavaScript / Web SDK

```javascript
import { InstructorPlayer } from '@instructor/sdk';

const player = new InstructorPlayer({
  planId: 'abc123',
  voice: 'calm-female',
  onStepChange: (step) => console.log('Now:', step.text),
  onComplete: () => console.log('Done!'),
});

player.play();
player.pause();
player.skip();
```

#### REST API

Third-party apps can create, manage, and trigger Plans programmatically:

```
POST   /api/v1/plans              Create a Plan
GET    /api/v1/plans/:id          Get a Plan
PUT    /api/v1/plans/:id          Update a Plan
DELETE /api/v1/plans/:id          Delete a Plan
POST   /api/v1/plans/:id/render   Pre-render TTS audio for a Plan
GET    /api/v1/plans/:id/embed    Get embed URL/code
```

#### Integration Scenarios

| Integration | How It Works |
|---|---|
| **Yoga studio website** | Studio embeds Plans on class page; students follow along at home |
| **Recipe websites** | "Cook along" button renders the recipe as a timed Plan |
| **Fitness apps** | Use API to generate and trigger Plans from within their own app |
| **LMS / e-learning** | Study session Plans embedded in course modules |
| **Smart home** | API triggers Plans from Home Assistant, IFTTT, or Shortcuts |
| **Wearable apps** | Third-party watch apps trigger Plans via API |

#### Monetization of Platform

- **Free embed**: up to 100 plays/month, Instructor branding
- **Pro embed**: $9.99/month, unlimited plays, custom branding, analytics
- **API access**: included in B2B tier, usage-based pricing for high volume

---

## 11. Monetization & Business Model

### Hybrid Freemium + Marketplace

#### Free Tier
- Up to 3 custom Plans
- 1 TTS voice (platform default)
- Access to free community Plans
- Basic ambient sounds (5 tracks)
- 7-day streak tracking
- No ads (ads destroy wellness app trust)

#### Premium — $5.99/month or $39.99/year
- Unlimited Plans
- AI Plan generation (describe your routine → get a Plan)
- 10+ premium TTS voices
- Premium ambient sound library (20+ tracks)
- Cloud sync across devices
- Advanced analytics and streak history
- Calendar integration and smart scheduling
- Priority access to new features

#### Marketplace (transactional)
- Creators list Plans for free or $0.99-$9.99
- Instructor takes 30%
- Creator subscription bundles (e.g., yoga teacher's full library for $4.99/mo)

#### B2B / Studio Tier — $29.99/month
- Everything in Premium
- Branded Plan sharing (custom logo, colors)
- Client management (assign Plans)
- Usage analytics per client
- Custom onboarding

### Revenue Mix Target (Year 2)
- 60% subscriptions
- 25% marketplace transactions
- 15% B2B/Studio plans

### Pricing Rationale

$5.99/month is deliberately below Calm ($15/mo) and Headspace ($13/mo) because Instructor is a platform/utility, not a content library. The value grows as the marketplace grows. Lower pricing reduces friction for a new brand.

### Unit Economics

- Cloud cost per user: ~$0.03-0.06/month (AI + TTS + infrastructure)
- At 3-5% free-to-paid conversion → sustainable at ~10K users
- Marketplace creates zero-marginal-cost content (users create for each other)

---

## 12. Go-to-Market Strategy

### Beachhead Market: Self-Guided Yoga Practitioners

**Why yoga first:**
- Already use timed sequences (poses held for duration)
- Share routines actively in online communities
- Frustrated by watching screens during practice
- Vocal, community-oriented, willing to pay for wellness tools

### Phase 1: Foundation (Months 1-3)

**Goal**: 5,000 users, 50 community Plans, product-market fit signal

1. Launch with **20 built-in Starter Plans** (morning routine, yoga flows, meditation, HIIT, Pomodoro, cooking timers)
2. Seed **10 high-quality yoga Plans** in r/yoga, yoga Facebook groups, Instagram yoga communities
3. **Product Hunt launch** for initial visibility
4. **Free tier only** — no monetization. Gather usage data on which categories get traction.

### Phase 2: Community & Monetization (Months 4-8)

**Goal**: 25,000 users, 500 community Plans, first revenue

1. Launch **Plan sharing** — users publish and share Plans
2. Launch **Premium subscription** gating AI generation, extra voices, unlimited Plans
3. **Creator outreach**: recruit 20-30 yoga/fitness micro-influencers with 80/20 revenue split
4. **Content marketing**: "How I automated my morning routine" posts targeting productivity communities

### Phase 3: Expansion & B2B (Months 9-14)

**Goal**: 100,000 users, sustainable revenue, B2B pipeline

1. Launch **paid Plans** in marketplace
2. Launch **Studio/Pro tier** for yoga studios and personal trainers
3. **Platform integrations**: Apple Watch, Siri Shortcuts, Apple Health
4. **Referral program**: "Share a Plan, both get 1 month Premium free"
5. **Localization**: Spanish, French, German, Portuguese, Japanese TTS voices

### Phase 4: Scale (Months 15+)

- Corporate wellness partnerships
- API for third-party integrations
- Advanced AI features (adaptive Plans, voice cloning)
- Hardware partnerships (smart speakers, wearables)

### App Store Optimization

Target long-tail keywords (avoid competing on "meditation app"):
- "yoga timer with voice instructions"
- "guided morning routine app"
- "cooking step timer voice"
- "workout interval timer with spoken cues"
- "custom guided meditation builder"

---

## 13. MVP Scope

### MVP = Plan Editor + Plan Player + Starter Library

**Build these:**

1. **Plan Editor** — create/edit Plans with `say`, `notify`, `play`, `wait`, `repeat` blocks in a vertical card-based UI
2. **Plan Player** — execute Plans in background with TTS + audio + notifications
3. **Audio Engine** — ambient audio playback with TTS ducking
4. **Lock Screen Controls** — play/pause/skip from lock screen and headphone buttons
5. **Starter Plans** — 15 pre-built Plans across yoga, meditation, routine, workout, cooking
6. **Plan Library** — browse, search, favorite personal Plans
7. **Basic Settings** — voice selection (1-2 voices), volume, notification preferences

**Do NOT build for MVP:**

- AI Plan generation (add in v1.1)
- Plan sharing/marketplace
- Apple Watch/WearOS
- Widgets
- Voice commands
- Analytics/streaks
- User accounts/cloud sync
- Parallel tracks

### MVP Timeline Estimate

| Phase | Duration |
|---|---|
| Design (UI/UX, Plan schema) | 2-3 weeks |
| Audio engine + background execution | 3-4 weeks |
| Plan editor UI | 2-3 weeks |
| Plan player / session screen | 2-3 weeks |
| TTS integration + audio mixing | 2 weeks |
| Starter Plans content | 1 week |
| Testing + polish | 2-3 weeks |
| **Total** | **~14-19 weeks** |

---

## 14. Roadmap

```
v1.0 (MVP)         Plan Editor + Player + Starter Library
  │
v1.1               AI Plan Generation + 5 TTS voices + Streaks
  │
v1.2               Plan Sharing + Community Plans + Import/Export
  │
v1.5               Apple Watch + Widgets + Calendar Integration
  │                 Dynamic Island / Live Activity
  │
v2.0               Marketplace (paid Plans) + Voice Commands
  │                 Import from URL + Adaptive Music
  │                 Parallel Tracks + Composable Plans
  │
v2.5               B2B Studio Tier + Creator Tools
  │
v3.0               Custom Voice Cloning + Adaptive Plans
  │                 On-device AI + Advanced Personalization
```

---

## 15. Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| **"Too broad, no clear audience"** | High | Lead with one niche (yoga), expand from proven base |
| **iOS kills app in background** | High | Active audio session keeps app alive; local notification backup; persist state every step transition |
| **TTS quality feels robotic** | High | Pre-render with neural TTS (OpenAI); offer recorded voice option for creators |
| **Low switching costs** | Medium | Marketplace creates network effects; creator lock-in; Plan library grows over time |
| **Android OEM battery killers** | Medium | Prompt user to disable optimization; document per-OEM instructions |
| **Marketplace chicken-and-egg** | High | Seed with built-in Plans; recruit creators before opening to users |
| **Apple App Store rejection** | Medium | Genuine audio playback (ambient music) satisfies background audio requirements |
| **User doesn't know what to create** | High | Templates + AI generation lower the barrier; starter Plans prove the concept |
| **Competition from incumbents** | Medium | Incumbents are locked into verticals; Instructor's generality is the moat |

---

## 16. Success Metrics

### North Star Metric

**Weekly Plans Played** — the number of Plan executions per week across all users. This captures both user acquisition and engagement in a single number.

### Primary Metrics

| Metric | Target (Month 6) | Target (Month 12) |
|---|---|---|
| Monthly Active Users (MAU) | 10,000 | 50,000 |
| Weekly Plans Played | 25,000 | 150,000 |
| Plans Created per User (lifetime) | 3+ | 5+ |
| D7 Retention | 20% | 30% |
| D30 Retention | 10% | 15% |
| Plan Completion Rate | 70% | 80% |
| Free-to-Paid Conversion | 2% | 4% |

### Secondary Metrics

| Metric | Purpose |
|---|---|
| Avg. session duration | Are Plans being played to completion? |
| Plans shared | Is the product viral? |
| Community Plans downloaded | Is the marketplace working? |
| AI Plans generated | Is AI generation a driver? |
| Creator Plans published | Is the supply side growing? |
| NPS | Would users recommend? |

### Anti-Metrics (Do NOT Optimize For)

- Screen time during Plan execution (should be ZERO)
- Notifications dismissed (means we're interrupting, not guiding)
- Plans abandoned mid-creation (editor friction)

---

## Appendix A: Competitor Reference Links

- [Seconds Interval Timer](https://www.intervaltimer.com/)
- [Intervals Pro](https://apps.apple.com/us/app/intervals-pro-hiit-timer/id957586938)
- [O'Coach](https://ocoach.app/)
- [Routinery](https://www.routinery.app/)
- [Insight Timer](https://insighttimer.com/)
- [SpeakTimer](https://apps.apple.com/us/app/speaktimer-voice-alert-timer/id1331136866)
- [Vital AI](https://joinvital.ai/)
- [ChefTalk AI](https://cheftalk.ai/)
- [Focus Bear](https://www.focusbear.io)
- [Headspace](https://www.headspace.com/)
- [Calm](https://www.calm.com/)

## Appendix B: Technical Reference

- [iOS Background Execution — Audio Mode](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Android Foreground Services](https://developer.android.com/develop/background-work/services/foreground-services)
- [Flutter audio_service package](https://pub.dev/packages/audio_service)
- [Flutter just_audio package](https://pub.dev/packages/just_audio)
- [OpenAI TTS API](https://platform.openai.com/docs/guides/text-to-speech)
- [ElevenLabs](https://elevenlabs.io/)
- [react-timeline-editor](https://github.com/xzdarcy/react-timeline-editor)
- [W3C SMIL 3.0](https://www.w3.org/TR/SMIL3/)
