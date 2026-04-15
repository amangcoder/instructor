# Manual & E2E Test Checklist — TASK-016

> These tests require a physical iOS 16.1+ device and cannot be automated.
> Each test must be performed by a human QA tester.

---

## 1. Live Activity / Dynamic Island (iOS 16.1+)

### Prerequisites
- Physical iPhone 14 or later (or any device with Dynamic Island)
- iOS 16.1+ installed
- App built with `NSSupportsLiveActivities = YES` in Info.plist

### Tests

- [ ] **LA-001**: Start a plan session → Live Activity appears on Dynamic Island within 1 second
- [ ] **LA-002**: Compact view shows current step name and progress indicator
- [ ] **LA-003**: Long-press Dynamic Island → expanded view shows step name, step index/total, time remaining
- [ ] **LA-004**: Expanded view shows Pause/Resume/Skip button controls
- [ ] **LA-005**: Tap Pause in expanded view → session pauses, Live Activity updates status
- [ ] **LA-006**: Tap Resume → session resumes, Live Activity updates
- [ ] **LA-007**: Tap Skip → advances to next step, Live Activity reflects new step
- [ ] **LA-008**: Step transition → Live Activity updates within 1 second (AC-019)
- [ ] **LA-009**: Tap Dynamic Island compact view → app opens to now-playing screen (AC-020)
- [ ] **LA-010**: Session completes → Live Activity shows "Completed" state
- [ ] **LA-011**: After completion, Live Activity auto-dismisses within 4 seconds (AC-022)
- [ ] **LA-012**: Lock screen shows Live Activity presentation during active session
- [ ] **LA-013**: On iOS 15 or earlier → no Live Activity attempted, no crash (AC-023)
- [ ] **LA-014**: Kill app during session → Live Activity ends gracefully

---

## 2. Widget Rendering & Updates

### Prerequisites
- iOS device with widgets on home screen
- InstructorWidget and StreakOnlySmallWidget added to home screen

### Tests

- [ ] **WG-001**: Small widget shows plan name, current step, and status icon during active session (AC-012)
- [ ] **WG-002**: Small widget shows streak count alongside playback info
- [ ] **WG-003**: Streak-only small widget shows current streak count
- [ ] **WG-004**: Streak-only widget shows "Done today ✓" when session completed today (AC-013)
- [ ] **WG-005**: Streak-only widget shows "Start a session" when no session today
- [ ] **WG-006**: Complete a session → widget updates within 5 seconds (AC-014)
- [ ] **WG-007**: Medium widget shows streak + playback state combined
- [ ] **WG-008**: Lock screen widget (accessory rectangular) shows streak when idle (REQ-015)
- [ ] **WG-009**: Lock screen widget shows playback state during active session
- [ ] **WG-010**: Tap widget → app opens to appropriate screen
- [ ] **WG-011**: Widget renders correctly after app is force-quit

---

## 3. Calendar Event Creation

### Prerequisites
- iOS device with Calendar app
- App has NOT been granted calendar access yet (for permission tests)

### Tests

- [ ] **CAL-001**: Open plan → tap calendar icon → CalendarEventSheet appears
- [ ] **CAL-002**: Date picker allows selecting a future date
- [ ] **CAL-003**: Time picker allows selecting a time
- [ ] **CAL-004**: Recurrence dropdown shows: None, Daily, Weekdays, Weekly
- [ ] **CAL-005**: First time: "Add to Calendar" prompts for calendar permission
- [ ] **CAL-006**: Grant permission → event created successfully
- [ ] **CAL-007**: Event title matches plan name
- [ ] **CAL-008**: Event duration matches estimated plan duration
- [ ] **CAL-009**: Event notes/URL contains deep link (instructor://...) (AC-015)
- [ ] **CAL-010**: Tap deep link in Calendar event → app opens to plan's now-playing screen
- [ ] **CAL-011**: Deny permission → dialog with "Open Settings" button shown (AC-016)
- [ ] **CAL-012**: Recurrence "Daily" → event repeats daily in Calendar app
- [ ] **CAL-013**: Recurrence "Weekdays" → event repeats Mon-Fri only
- [ ] **CAL-014**: Recurrence "Weekly" → event repeats weekly

---

## 4. Universal Links / Plan Sharing

### Prerequisites
- App installed on device
- Backend running with sharing endpoints
- A second device or browser for testing link reception

### Tests

- [ ] **UL-001**: Share a plan → share sheet opens with URL and description text
- [ ] **UL-002**: Share URL format: https://instructor.app/s/XXXXXXXXXXXX (under 60 chars) (AC-007)
- [ ] **UL-003**: Open share URL in Safari → redirects to app (Universal Link)
- [ ] **UL-004**: App opens to SharedPlanPreviewScreen with plan details (AC-009)
- [ ] **UL-005**: Preview shows plan name, description, step count, estimated duration
- [ ] **UL-006**: Tap "Save to My Plans" → plan saved to library within 3 seconds (AC-010)
- [ ] **UL-007**: Saved plan appears in plan library with correct name and steps
- [ ] **UL-008**: Open share URL when app is NOT installed → web fallback page shown (AC-008)
- [ ] **UL-009**: Web fallback shows plan info and App Store install badges
- [ ] **UL-010**: Revoke sharing → previously shared URL returns 404 (AC-011)
- [ ] **UL-011**: Revoked link opened in app shows "Plan no longer available" error

---

## 5. Cross-Device Streak Sync

### Prerequisites
- Two iOS devices (A and B) signed into the same account
- Both devices connected to internet
- Backend sync endpoints operational

### Tests

- [ ] **SYNC-001**: Device A: complete a session → streak increments
- [ ] **SYNC-002**: Device B: open app → trigger sync → streak matches Device A (AC-024)
- [ ] **SYNC-003**: Device A: complete 3 sessions over 3 days → Device B shows 3-day streak after sync
- [ ] **SYNC-004**: Device A: go offline → complete session → come online → sync uploads completion (AC-025)
- [ ] **SYNC-005**: Both devices complete session simultaneously → no duplicate, streak correct
- [ ] **SYNC-006**: Device A: complete then sync → Device B: complete then sync → combined streak correct

---

## 6. Streak Freeze Mechanics (Manual Verification)

### Tests

- [ ] **FRZ-001**: User with 2 available freezes misses 1 day → streak preserved, freeze count decrements
- [ ] **FRZ-002**: User with 0 freezes misses 1 day → streak resets to 0
- [ ] **FRZ-003**: User completes 7 consecutive days → freeze replenished (count increments by 1)
- [ ] **FRZ-004**: User with 2 freezes completes 7 more days → freeze count stays at 2 (max cap)
- [ ] **FRZ-005**: Freeze consumption visible in ActivityStatsCard

---

## 7. Timezone Change Scenarios

### Tests

- [ ] **TZ-001**: Complete session in EST timezone → change device to PST → streak still accurate
- [ ] **TZ-002**: Complete session at 11 PM EST → fly to PST (8 PM same day) → next day in PST, streak maintained
- [ ] **TZ-003**: Complete session → change timezone → day boundary doesn't create false gap
- [ ] **TZ-004**: Streak calendar shows correct day highlights regardless of timezone change

---

## Sign-Off

| Section | Tester | Date | Pass/Fail |
|---------|--------|------|-----------|
| Live Activity | | | |
| Widgets | | | |
| Calendar | | | |
| Universal Links | | | |
| Cross-Device Sync | | | |
| Streak Freeze | | | |
| Timezone | | | |
