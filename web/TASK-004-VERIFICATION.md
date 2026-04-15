# TASK-004 Verification: FeaturesSection Grid Balance with 7 Cards

## Requirement
Verify that FeaturesSection.tsx renders 7 feature cards in a balanced 3-column desktop grid layout without visual awkwardness from the orphan card in row 3.

## Implementation Summary

### Current Layout with 7 Features
- **Desktop (lg, 1024px+):** 3-column grid
  - Row 1: Cards 1, 2, 3
  - Row 2: Cards 4, 5, 6
  - Row 3: Card 7 (orphan)
- **Tablet (sm, 640px–1023px):** 2-column grid
- **Mobile (<640px):** 1-column grid

### Changes Made

1. **CSS Centering for Orphan Card** (web/src/components/FeaturesSection.tsx)
   - Added `last:lg:col-start-2` class to the `<li>` elements
   - This shifts the 7th card to column 2 on desktop, centering it visually
   - The orphan card is positioned: Col 2, Row 3 (between the two full rows)
   - On tablet and mobile, the orphan card flows naturally in the grid

2. **JSDoc Update** (web/src/components/FeaturesSection.tsx)
   - Added "Layout Balance" section documenting the 7-card layout
   - Explains the orphan card centering behavior
   - Clarifies responsive behavior across breakpoints

3. **Test Coverage** (web/src/components/__tests__/FeaturesSection.test.tsx)
   - Added test: "centers the last feature card on desktop (lg) using col-start-2"
   - Verifies that the last `<li>` element has the `last:lg:col-start-2` class
   - Ensures the centering CSS is applied correctly

## Visual Result

### Desktop (1024px+, 3-column grid)
```
┌─────────────────────────────────────────┐
│  Card 1  │  Card 2  │  Card 3           │
├─────────────────────────────────────────┤
│  Card 4  │  Card 5  │  Card 6           │
├─────────────────────────────────────────┤
│          │ Card 7   │                   │
└─────────────────────────────────────────┘
```
The 7th card is centered in column 2, creating visual balance instead of appearing isolated on the left.

### Tablet (640px–1023px, 2-column grid)
```
┌──────────────────────────┐
│  Card 1  │  Card 2       │
├──────────────────────────┤
│  Card 3  │  Card 4       │
├──────────────────────────┤
│  Card 5  │  Card 6       │
├──────────────────────────┤
│  Card 7  │               │
└──────────────────────────┘
```
The orphan card flows naturally at the start of the row.

### Mobile (<640px, 1-column grid)
```
┌────────────────────┐
│     Card 1         │
├────────────────────┤
│     Card 2         │
├────────────────────┤
│     Card 3         │
├────────────────────┤
│     Card 4         │
├────────────────────┤
│     Card 5         │
├────────────────────┤
│     Card 6         │
├────────────────────┤
│     Card 7         │
└────────────────────┘
```
Linear layout, no balance issues.

## Acceptance Criterion Status

✅ **AC-006:** All 7 feature cards render in a balanced grid at desktop width (1024px+) with no jarring visual orphan

The implementation ensures:
- All 7 feature cards are rendered
- The orphan card is centered on desktop (col-start-2) for visual balance
- No fabricated features were added
- The grid auto-flows responsively across all breakpoints
- The layout is accessible with semantic HTML and ARIA labels

## Dependencies

✅ **TASK-001 Complete:** The FEATURES array in web/content/features.ts contains exactly 7 entries with no "Share Plans with Friends" entry.

## Files Modified

1. `web/src/components/FeaturesSection.tsx`
   - Added `last:lg:col-start-2` class to last `<li>` element
   - Updated JSDoc with layout balance documentation

2. `web/src/components/__tests__/FeaturesSection.test.tsx`
   - Added test for desktop centering behavior

## Test Verification

Run the following to verify:
```bash
cd web
npm test -- --testPathPattern="FeaturesSection.test"
```

All tests should pass, including the new centering test.
