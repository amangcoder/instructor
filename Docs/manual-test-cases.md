# Manual Test Cases — Instructor App

End-user experience test cases organized by feature area.

**Legend:** P0 = Critical, P1 = High, P2 = Medium, P3 = Low

---

## 1. Onboarding

### TC-1.1 First Launch Shows Onboarding (P0)
**Precondition:** Fresh install, no prior app data.
1. Launch the app.
2. **Expected:** Onboarding screen appears with a 3-page carousel.
3. Swipe through all 3 pages: "Create Plans", "Runs in Background", "Start with Templates".
4. **Expected:** Each page displays its illustration, title, and description. Page indicator updates.

### TC-1.2 Skip Button on Onboarding (P1)
1. On any onboarding page, tap "Skip".
2. **Expected:** Template Picker sheet appears as a modal overlay.

### TC-1.3 Select a Template from Onboarding (P0)
1. Complete or skip onboarding to reach the Template Picker.
2. Scroll through templates grouped by category (Yoga, Meditation, Workout, etc.).
3. Tap a template (e.g., "Morning Yoga").
4. **Expected:** Plan is created in local storage. App navigates to Plan Editor with the template steps pre-populated.

### TC-1.4 Start from Scratch (P1)
1. On the Template Picker, tap "Start from scratch".
2. **Expected:** App navigates to Plan Editor with an empty plan.

### TC-1.5 Onboarding Does Not Reappear (P0)
1. Complete onboarding (select a template or start from scratch).
2. Force-close and relaunch the app.
3. **Expected:** App opens directly to the Plan Library screen, not onboarding.

---

## 2. Plan Library (Home Screen)

### TC-2.1 View Plans in Library (P0)
**Precondition:** At least 2 plans exist.
1. Navigate to the Plan Library (home screen).
2. **Expected:** Plans are listed as cards showing: name, category icon, total duration, and last-used date (relative, e.g., "2 hours ago").

### TC-2.2 Search Plans by Name (P1)
1. On the library screen, tap the search bar.
2. Type a partial plan name (e.g., "Yoga").
3. **Expected:** List filters in real-time to show only plans matching the query. Non-matching plans disappear.
4. Clear the search field.
5. **Expected:** All plans reappear.

### TC-2.3 Filter Plans by Category (P1)
1. Tap a category filter chip (e.g., "Meditation").
2. **Expected:** Only plans in the selected category are shown.
3. Tap the same chip again (or "All").
4. **Expected:** All plans reappear.

### TC-2.4 Combined Search and Category Filter (P2)
1. Select a category chip (e.g., "Workout").
2. Type a search term.
3. **Expected:** Results match both the category and the search query.

### TC-2.5 Empty Library State (P2)
**Precondition:** No plans exist (delete all plans or fresh install post-onboarding with "start from scratch" then delete that plan).
1. View the library.
2. **Expected:** An empty state message is displayed (not a blank screen).

### TC-2.6 Duplicate a Plan (P1)
**Precondition:** Authenticated user, at least 1 plan exists.
1. Long-press or tap the menu icon on a plan card.
2. Select "Duplicate".
3. **Expected:** A copy of the plan appears in the library with a modified name (e.g., "Morning Yoga (copy)").
4. Open the duplicate.
5. **Expected:** All steps match the original.

### TC-2.7 Delete a Plan (P1)
**Precondition:** Authenticated user, at least 1 plan exists.
1. Tap the menu icon on a plan card and select "Delete".
2. **Expected:** Confirmation dialog appears.
3. Confirm deletion.
4. **Expected:** Plan is removed from the library. It does not reappear after relaunch.

### TC-2.8 Create New Plan Button (P0)
**Precondition:** Authenticated user.
1. Tap the "+" FloatingActionButton.
2. **Expected:** Navigates to Plan Editor for a new plan.

---

## 3. Plan Editor

### TC-3.1 Add a "Say" Step (P0)
1. Open Plan Editor (new or existing plan).
2. Tap a step insert button ("+") between steps or at the end.
3. Select "Say".
4. Enter text: "Take a deep breath".
5. **Expected:** Step card appears showing "SAY" label and the entered text. Duration header updates.

### TC-3.2 Add a "Wait" Step (P0)
1. Add a new step, select "Wait".
2. Set duration to 30 seconds.
3. **Expected:** Step card shows "WAIT" label and "0:30" duration. Total plan duration updates.

### TC-3.3 Add a "Notify" Step (P1)
1. Add a new step, select "Notify".
2. Enter title: "Time's up!" and body: "Move to the next exercise".
3. **Expected:** Step card shows "NOTIFY" label with the entered title/body.

### TC-3.4 Add a "Play" Step (P1)
1. Add a new step, select "Play".
2. Select an audio asset (e.g., "Rain").
3. Configure: loop = on, volume = 70%.
4. **Expected:** Step card shows "PLAY" label, audio asset name, and configured properties.

### TC-3.5 Add a "Stop Audio" Step (P2)
1. Add a "Stop Audio" step.
2. **Expected:** Step card shows "STOP AUDIO" label. No additional input needed.

### TC-3.6 Add a "Repeat" Block (P1)
1. Add a "Repeat" step.
2. Set repeat count to 3.
3. Add child steps inside the repeat block (e.g., Say + Wait).
4. **Expected:** Repeat block visually nests child steps. Total duration = child duration x 3.

### TC-3.7 Reorder Steps via Drag (P1)
1. Create a plan with 3+ steps.
2. Long-press a step card and drag it to a new position.
3. **Expected:** Step moves to the new position. Other steps shift accordingly. Duration remains correct.

### TC-3.8 Edit an Existing Step (P1)
1. Tap on an existing step card to expand it.
2. Modify the text or duration.
3. **Expected:** Changes reflect immediately on the card and in the duration header.

### TC-3.9 Set Plan Metadata (P1)
1. Open the plan metadata sheet.
2. Set name: "My Routine", description, category: "Routine", and tags.
3. **Expected:** Metadata saves with the plan. Plan appears in library with the correct name and category.

### TC-3.10 Override Voice on a Say Step (P2)
1. Expand a "Say" step.
2. Change the voice to a different option (e.g., "charon").
3. **Expected:** Voice override is saved. When executed, this step uses the overridden voice, not the plan default.

### TC-3.11 Save Plan Triggers TTS Pre-rendering (P1)
1. Create a plan with 2+ "Say" steps.
2. Tap "Save".
3. **Expected:** Plan saves successfully. TTS audio is pre-rendered (may show a brief progress indicator). Plan appears in library.

### TC-3.12 Cancel Without Saving (P2)
1. Make changes to a plan in the editor.
2. Tap "Cancel" or navigate back.
3. **Expected:** Changes are discarded. Plan in library retains its previous state.

---

## 4. Plan Execution

### TC-4.1 Start Plan with Countdown (P0)
1. From the library, tap a plan card.
2. **Expected:** A 3-2-1 countdown overlay appears.
3. Countdown completes.
4. **Expected:** App navigates to the Now Playing screen. First step begins executing.

### TC-4.2 Now Playing Screen Layout (P0)
1. Start a plan.
2. **Expected:** Now Playing screen shows:
   - Plan name at top
   - Large countdown timer (current step remaining time)
   - Current step card with type label and instruction text
   - Next-up preview of the upcoming step
   - Gesture hint text at bottom

### TC-4.3 Say Step Plays TTS Audio (P0)
1. Execute a plan with a "Say" step containing text "Stretch your arms".
2. **Expected:** TTS voice speaks "Stretch your arms" through the device speaker. Timer counts down for the step duration.

### TC-4.4 Wait Step Shows Timer (P0)
1. Execute a plan with a "Wait" step (30 seconds).
2. **Expected:** Timer counts down from 0:30. No audio plays (except ambient if active). Screen shows "WAIT" label.

### TC-4.5 Notify Step Fires Notification (P1)
1. Execute a plan with a "Notify" step.
2. **Expected:** A local push notification appears with the configured title and body. On Android, notification shows in the system tray.

### TC-4.6 Play Step Starts Ambient Audio (P1)
1. Execute a plan with a "Play" step (e.g., "Rain", loop=on).
2. **Expected:** Ambient rain audio begins playing and continues looping through subsequent steps.

### TC-4.7 Stop Audio Step Halts Ambient (P1)
**Precondition:** Ambient audio is currently playing.
1. Execute a plan where a "Stop Audio" step follows a "Play" step.
2. **Expected:** Ambient audio stops when the "Stop Audio" step executes.

### TC-4.8 Repeat Block Executes N Times (P1)
1. Execute a plan with a Repeat block (count=3) containing Say("Rep") + Wait(5s).
2. **Expected:** The child steps execute 3 times. Voice says "Rep" three times with 5-second waits between. Total block takes ~15 seconds.

### TC-4.9 Audio Ducking During Voice (P1)
**Precondition:** Ambient audio is playing via a "Play" step.
1. A "Say" step begins executing.
2. **Expected:** Ambient audio volume fades to ~20% while TTS voice plays, then restores to original volume after TTS completes.

### TC-4.10 Pause and Resume (P0)
1. During plan execution, single-tap the screen.
2. **Expected:** Execution pauses. Timer stops. Badge shows "Paused". Audio pauses.
3. Single-tap again.
4. **Expected:** Execution resumes. Timer continues. Audio resumes.

### TC-4.11 Skip Forward (P0)
1. During execution, swipe right (or double-tap).
2. **Expected:** Current step is skipped. Next step begins immediately.

### TC-4.12 Skip Backward (P1)
1. During execution (not on the first step), swipe left (or triple-tap).
2. **Expected:** Execution returns to the previous step. That step restarts from the beginning.

### TC-4.13 End Session via Long Press (P0)
1. During execution, long-press the screen for 2 seconds.
2. **Expected:** Confirmation dialog appears: "End session?"
3. Confirm.
4. **Expected:** Execution stops. Audio stops. App navigates back to library.

### TC-4.14 End Session via Swipe Down (P1)
1. During execution, swipe down.
2. **Expected:** Same confirmation dialog as TC-4.13.

### TC-4.15 Plan Completion Summary (P0)
1. Let a plan run to completion (all steps finish).
2. **Expected:** Completion dialog appears showing: plan name, step count, total elapsed duration.
3. Dismiss the dialog.
4. **Expected:** App navigates back to the Plan Library.

### TC-4.16 Auto-Dim After Inactivity (P2)
1. Start plan execution.
2. Do not interact with the screen for 10+ seconds.
3. **Expected:** Screen brightness dims to ~30%.
4. Tap the screen.
5. **Expected:** Brightness restores to normal.

### TC-4.17 Background Audio Continues When Screen Locks (P0)
1. Start a plan with ambient audio and/or TTS.
2. Lock the device screen (press power button).
3. **Expected:** Audio continues playing. Steps continue executing in the background.
4. Unlock the screen.
5. **Expected:** Now Playing screen shows current progress accurately.

### TC-4.18 Auto-Pause on Incoming Phone Call (P2)
**Platform:** Android only (requires READ_PHONE_STATE permission).
1. Start plan execution with audio playing.
2. Receive an incoming phone call.
3. **Expected:** Execution pauses automatically. Audio stops.
4. End the phone call.
5. **Expected:** Execution resumes (or remains paused for manual resume — verify behavior).

### TC-4.19 Crash Recovery (P0)
1. Start a plan mid-execution (e.g., on step 3 of 10).
2. Force-kill the app (swipe from app switcher).
3. Relaunch the app.
4. **Expected:** App detects a recoverable session and offers to resume.
5. Confirm resume.
6. **Expected:** Execution resumes from the last persisted step (step 3 or nearby). Timer reflects correct remaining time.

### TC-4.20 Crash Recovery — Decline Resume (P2)
1. Same as TC-4.19, but decline the resume offer.
2. **Expected:** Session is cleared. App shows the Plan Library normally.

---

## 5. Text-to-Speech (TTS)

### TC-5.1 Default TTS Provider Works (P0)
1. Go to Settings. Note the current TTS provider (e.g., Gemini).
2. Execute a plan with a "Say" step.
3. **Expected:** Voice audio plays using the selected provider's voice.

### TC-5.2 Switch TTS Provider (P1)
1. Go to Settings > TTS Provider. Switch from Gemini to Kokoro (or vice versa).
2. Execute a plan with a "Say" step.
3. **Expected:** Voice sounds different, matching the new provider's voice characteristics.

### TC-5.3 Platform TTS Fallback (P0)
1. Ensure the device has no network connection (airplane mode).
2. Execute a plan with a "Say" step that is NOT cached.
3. **Expected:** App falls back to platform TTS (device's built-in voice). Audio still plays. No crash or silent failure.

### TC-5.4 Change TTS Voice (P1)
1. Go to Settings > Voice. Select a different voice (e.g., "leda").
2. Execute a plan with a "Say" step.
3. **Expected:** Voice matches the selected voice option.

### TC-5.5 Adjust Speech Rate (P1)
1. Go to Settings > Speech Rate. Set to 1.5x.
2. Execute a "Say" step.
3. **Expected:** Voice speaks noticeably faster than at 1.0x.
4. Set to 0.5x and repeat.
5. **Expected:** Voice speaks noticeably slower.

### TC-5.6 TTS Caching — Repeated Playback (P2)
1. Execute a plan with a "Say" step for the first time (requires network).
2. Enable airplane mode.
3. Execute the same plan again.
4. **Expected:** The "Say" step plays from cache without network. No delay or error.

### TC-5.7 Change Language/Locale (P2)
1. Go to Settings > Language. Switch between "English (India)" and "English (UK)".
2. Execute a "Say" step.
3. **Expected:** Voice accent matches the selected locale.

---

## 6. Audio Engine

### TC-6.1 Ambient Audio Plays Correctly (P1)
1. Execute a plan with a "Play" step (e.g., "Forest Sounds", loop=on).
2. **Expected:** Forest ambient audio plays and loops continuously.

### TC-6.2 Ambient Volume Control (P1)
1. Go to Settings > Ambient Volume. Set to 30%.
2. Play a plan with ambient audio.
3. **Expected:** Ambient audio plays at a noticeably lower volume than at 100%.

### TC-6.3 Voice Volume Control (P1)
1. Go to Settings > Voice Volume. Set to 50%.
2. Play a "Say" step.
3. **Expected:** TTS voice plays at reduced volume.

### TC-6.4 Simultaneous Ambient + Voice (P0)
1. Execute a plan: Play("Rain") → Say("Hold this pose").
2. **Expected:** Rain ambient plays first. When "Say" starts, rain ducks to ~20%. Voice plays. Rain returns to full volume after voice ends.

### TC-6.5 Multiple Audio Assets (P2)
1. Create a plan: Play("Rain") → Wait(10s) → Play("Binaural Beats").
2. **Expected:** Rain plays first, then transitions to Binaural Beats at the second Play step.

---

## 7. Authentication

### TC-7.1 Request OTP (P0)
1. Navigate to Login screen.
2. Enter a valid email address.
3. Tap "Request OTP".
4. **Expected:** Success message appears. OTP is sent to the email.

### TC-7.2 Invalid Email Validation (P1)
1. On the Login screen, enter an invalid email (e.g., "notanemail").
2. Tap "Request OTP".
3. **Expected:** Validation error message displayed. OTP is not sent.

### TC-7.3 Verify OTP Successfully (P0)
1. Request an OTP, then navigate to the OTP screen.
2. Enter the correct 6-digit code.
3. Tap "Verify".
4. **Expected:** Authentication succeeds. App redirects to the Plan Library. User gains access to authenticated features (create/edit plans, sync, AI generation).

### TC-7.4 Incorrect OTP (P1)
1. On the OTP screen, enter a wrong code (e.g., "000000").
2. Tap "Verify".
3. **Expected:** Error message: OTP is incorrect. User can retry.

### TC-7.5 Expired OTP (P1)
1. Request an OTP. Wait 5+ minutes.
2. Enter the original OTP code.
3. **Expected:** Error message: OTP has expired. User can request a new one.

### TC-7.6 Resend OTP (P2)
1. On the OTP screen, tap "Resend OTP".
2. **Expected:** New OTP is sent. Countdown timer resets.

### TC-7.7 Logout (P0)
1. While authenticated, go to Settings > Account > Logout.
2. **Expected:** User is logged out. Authenticated features become inaccessible. Tokens are revoked.
3. Relaunch app.
4. **Expected:** User remains logged out.

### TC-7.8 Token Refresh (P2)
1. Log in and use the app until the access token expires (or simulate by waiting).
2. Perform an authenticated action.
3. **Expected:** Token refreshes automatically in the background. Action succeeds without requiring re-login.

---

## 8. Cloud Sync

### TC-8.1 Upload Plans to Cloud (P0)
**Precondition:** Authenticated user with at least 1 plan.
1. Go to Settings > Sync > Upload.
2. **Expected:** Upload succeeds. Sync status shows the current timestamp and database size.

### TC-8.2 Automatic Sync After Plan Changes (P1)
1. Create or edit a plan.
2. Wait ~30 seconds (debounce period).
3. Go to Settings > Sync Status.
4. **Expected:** Last sync time is recent (within the last minute).

### TC-8.3 Download and Restore Plans (P0)
**Precondition:** Plans were previously uploaded from this account.
1. On a fresh install (or after clearing data), log in.
2. Go to Settings > Sync > Download.
3. **Expected:** Database is downloaded and restored. All previously synced plans appear in the library.

### TC-8.4 Sync Status Display (P2)
1. Go to Settings > Sync.
2. **Expected:** Shows last sync timestamp and database file size.

---

## 9. AI Plan Generation

### TC-9.1 Generate a Plan from Description (P0)
**Precondition:** Authenticated user.
1. Navigate to the Plan Generation screen.
2. Enter: "20-minute morning stretching routine with warm-up and cool-down".
3. Tap "Generate".
4. **Expected:** Loading indicator appears. After a few seconds, app navigates to the Plan Review screen with a structured plan containing relevant steps.

### TC-9.2 Review and Edit Generated Plan (P1)
1. After generating a plan (TC-9.1), review the steps on the Review screen.
2. Edit a step's text or duration.
3. Tap "Save".
4. **Expected:** Plan is saved to local storage with the edits applied. Plan appears in the library.

### TC-9.3 Discard Generated Plan (P2)
1. After generating a plan, tap "Discard" on the Review screen.
2. **Expected:** Plan is not saved. App navigates back (to generation screen or library).

### TC-9.4 Rate Limiting on Generation (P2)
1. Generate plans repeatedly in quick succession.
2. **Expected:** After hitting the rate limit, a 429 error message appears (e.g., "Too many requests. Please wait.").

### TC-9.5 Unauthenticated User Cannot Access Generation (P1)
1. While logged out, attempt to navigate to Plan Generation.
2. **Expected:** App redirects to the Login screen.

---

## 10. Settings

### TC-10.1 Server URL Configuration (P2)
1. Go to Settings > Server URL.
2. Change the URL to a custom backend.
3. **Expected:** App uses the new URL for all API calls. (Verify by checking sync or TTS behavior.)

### TC-10.2 Notification Sound Toggle (P2)
1. Go to Settings > Notifications > Sound. Toggle OFF.
2. Execute a plan with a "Notify" step.
3. **Expected:** Notification appears silently (no sound). Toggle ON and repeat — notification plays a sound.

### TC-10.3 Vibration Toggle (P2)
1. Go to Settings > Notifications > Vibration. Toggle OFF.
2. Execute a "Notify" step.
3. **Expected:** No vibration on notification. Toggle ON — device vibrates.

### TC-10.4 Battery Optimization Prompt — Android (P2)
**Platform:** Android only.
1. Go to Settings.
2. **Expected:** Battery optimization section is visible with a prompt to disable optimization for reliable background execution.

### TC-10.5 Settings Persist Across Restarts (P1)
1. Change several settings (TTS provider, voice, speech rate, volumes).
2. Force-close and relaunch the app.
3. Go to Settings.
4. **Expected:** All settings retain their configured values.

---

## 11. Accessibility

### TC-11.1 Screen Reader — Plan Library (P2)
1. Enable VoiceOver (iOS) or TalkBack (Android).
2. Navigate the Plan Library.
3. **Expected:** Screen reader announces plan names, categories, durations, and actions. All interactive elements are focusable and labeled.

### TC-11.2 Screen Reader — Now Playing (P2)
1. With screen reader enabled, start a plan.
2. **Expected:** Dedicated accessibility buttons for pause/resume and end session are available. Current step text is announced.

### TC-11.3 Large Text on Now Playing (P1)
1. Start plan execution.
2. **Expected:** Instruction text on the Now Playing screen is large (24sp), easily readable from a distance.

### TC-11.4 Color-Coded Step Types (P2)
1. View steps in the Plan Editor or Now Playing screen.
2. **Expected:** Each step type (Say, Wait, Notify, Play, Repeat, Stop Audio) has a distinct accent color for visual differentiation.

---

## 12. Foreground Service & Notifications (Android)

### TC-12.1 Foreground Service Notification (P1)
**Platform:** Android only.
1. Start plan execution.
2. Pull down the notification shade.
3. **Expected:** A persistent notification is visible indicating the app is running in the background.

### TC-12.2 App Continues in Background (P0)
1. Start plan execution.
2. Press the Home button to send the app to background.
3. Wait for a "Say" or "Notify" step to execute.
4. **Expected:** TTS audio plays / notification fires even while the app is backgrounded.

### TC-12.3 Return from Background (P1)
1. While a plan is executing in the background, open the app.
2. **Expected:** Now Playing screen shows accurate progress — correct step, correct timer.

---

## 13. Edge Cases & Error Handling

### TC-13.1 No Network — TTS with No Cache (P1)
1. Enable airplane mode.
2. Execute a plan with a "Say" step that has never been cached.
3. **Expected:** Falls back to platform TTS. Audio still plays (device voice). No crash.

### TC-13.2 No Network — Cloud Sync (P1)
1. Enable airplane mode.
2. Attempt to sync (Settings > Sync > Upload).
3. **Expected:** Clear error message (e.g., "No network connection"). No crash or data loss.

### TC-13.3 No Network — AI Generation (P1)
1. Enable airplane mode.
2. Attempt to generate a plan.
3. **Expected:** Clear error message. No crash.

### TC-13.4 Empty Plan Execution (P2)
1. Create a plan with 0 steps. Attempt to run it.
2. **Expected:** App handles gracefully — either prevents execution or shows completion immediately. No crash.

### TC-13.5 Very Long Plan Execution (P2)
1. Create a plan with 50+ steps and total duration > 30 minutes.
2. Execute the plan.
3. **Expected:** All steps execute correctly. No memory issues, timer drift, or crashes.

### TC-13.6 Rapid Gesture Input (P2)
1. During execution, rapidly tap/swipe multiple times.
2. **Expected:** App handles input gracefully. No double-skips, crashes, or UI glitches.

### TC-13.7 Plan with Only Repeat Blocks (P3)
1. Create a plan: Repeat(5) containing Say("Go") + Wait(3s).
2. Execute.
3. **Expected:** Steps repeat exactly 5 times. Total duration is accurate.

### TC-13.8 Nested Repeat Blocks (P3)
1. Create a plan with a Repeat block inside another Repeat block.
2. Execute.
3. **Expected:** Inner and outer loops execute correctly with the expected total iterations.

### TC-13.9 Preview Mode (P2)
1. Start a plan in preview mode (4x speed).
2. **Expected:** Steps execute at 4x speed. TTS may be skipped or accelerated. Useful for dry-run verification.

---

## 14. Cross-Platform (iOS vs Android)

### TC-14.1 iOS — Background Audio via AVAudioSession (P0)
**Platform:** iOS.
1. Start a plan with audio. Lock the screen.
2. **Expected:** Audio continues via AVAudioSession. Silent loops keep the session alive during Wait steps.

### TC-14.2 Android — Foreground Service Keeps App Alive (P0)
**Platform:** Android.
1. Start a plan. Background the app and wait several minutes.
2. **Expected:** Foreground service prevents Android from killing the app. Steps continue executing.

### TC-14.3 iOS — No Phone State Permission Required (P3)
**Platform:** iOS.
1. Check app permissions.
2. **Expected:** App does not request READ_PHONE_STATE (Android-only). Call interruption is handled via audio session.

---

## 15. Data Integrity

### TC-15.1 Plan Persists After App Restart (P0)
1. Create and save a plan.
2. Force-close and relaunch the app.
3. **Expected:** Plan is present in the library with all steps intact.

### TC-15.2 Execution State Persists (P1)
1. Start a plan. Pause execution.
2. Force-close and relaunch.
3. **Expected:** App offers to resume the paused session.

### TC-15.3 Settings Survive App Update (P2)
1. Configure all settings. Update the app (install a new build over the existing one).
2. **Expected:** All settings and plans are preserved.

### TC-15.4 Duplicate Plan Has Independent Data (P2)
1. Duplicate a plan. Edit the duplicate (change name, modify steps).
2. **Expected:** Original plan is unchanged. Edits only affect the duplicate.
