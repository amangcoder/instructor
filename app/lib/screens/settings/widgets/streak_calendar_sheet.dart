/// StreakCalendarSheet — bottom sheet showing a swipeable monthly calendar of
/// streak activity.
///
/// ## Features
/// - 7-column calendar grid (Sunday → Saturday) per month
/// - Swipeable [PageView] to navigate up to [_kTotalMonths] months back
/// - Colour-coded day cells:
///   - 🟢 Green  : completed day
///   - 🔵 Blue   : streak freeze used
///   - ⚫ Gray   : missed past day (no completion, no freeze)
///   - 🔘 Outline: today (border in primary colour)
/// - Legend at the bottom explaining the colour codes
/// - Fully accessible: Semantics on each day cell + month navigation buttons
///
/// ## Usage
///
/// ```dart
/// showStreakCalendarSheet(context);
/// ```
library streak_calendar_sheet;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/models/streak_state.dart';
import 'package:instructor/providers/streak_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

/// How many months back the user can swipe.
const int _kTotalMonths = 6;

/// Day-of-week header labels, beginning from Sunday.
/// Two-character abbreviations are used to avoid ambiguity between
/// Sunday/Saturday ('S') and Tuesday/Thursday ('T').
const _kWeekdayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

/// Full weekday names used as semantic labels for screen readers.
const _kWeekdayFullNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

/// Month names (1-indexed; index 0 is empty).
const _kMonthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Background colour for completed day cells.
const _kCompletedColor = Color(0xFF4CAF50); // Material Green 500

/// Background colour for days where a streak freeze was consumed.
const _kFrozenColor = Color(0xFF64B5F6); // Material Blue 300

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the [StreakCalendarSheet] as a modal bottom sheet.
///
/// Uses `useRootNavigator: true` and `useSafeArea: true` so the sheet sits
/// above the system navigation bar on all devices.
Future<void> showStreakCalendarSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const StreakCalendarSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StreakCalendarSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Modal bottom sheet displaying a swipeable monthly streak calendar.
///
/// Reads [streakCalendarProvider] for the last ~30 days of [DayStatus] records.
/// Older months the user swipes to are shown with empty cells where data is
/// unavailable (no false "missed" signal is displayed).
class StreakCalendarSheet extends ConsumerStatefulWidget {
  const StreakCalendarSheet({super.key});

  @override
  ConsumerState<StreakCalendarSheet> createState() =>
      _StreakCalendarSheetState();
}

class _StreakCalendarSheetState extends ConsumerState<StreakCalendarSheet> {
  late final PageController _pageController;

  /// Current page index.  0 = oldest allowed month; [_kTotalMonths]-1 = current.
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _kTotalMonths - 1;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Converts a page index to a month offset from *now*.
  /// pageIndex == _kTotalMonths - 1  →  offset 0 (current month)
  /// pageIndex == 0                  →  offset _kTotalMonths - 1
  int _offsetFor(int pageIndex) => _kTotalMonths - 1 - pageIndex;

  /// Human-readable "Month YYYY" string for [pageIndex].
  String _monthLabel(int pageIndex) {
    final offset = _offsetFor(pageIndex);
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month - offset, 1);
    return '${_kMonthNames[dt.month]} ${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(streakCalendarProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.88,
      minChildSize: 0.40,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Semantics(
                label: 'Drag to resize',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Month navigation ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left),
                      color: colorScheme.primary,
                      onPressed: _currentPage > 0
                          ? () => _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_currentPage),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right),
                      color: colorScheme.primary,
                      onPressed: _currentPage < _kTotalMonths - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),

              // ── Weekday header row ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(
                    _kWeekdayLabels.length,
                    (i) => Semantics(
                      label: _kWeekdayFullNames[i],
                      child: SizedBox(
                        width: 36,
                        child: ExcludeSemantics(
                          child: Text(
                            _kWeekdayLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ── Month PageView ───────────────────────────────────────────
              Expanded(
                child: calendarAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load calendar data.',
                        style: TextStyle(color: colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (days) {
                    // "yyyy-MM-dd" → DayStatus lookup map
                    final dayMap = <String, DayStatus>{
                      for (final d in days) _dateKey(d.date): d,
                    };

                    return Semantics(
                      label: 'Streak calendar. '
                          'Swipe left or right to change months.',
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (p) =>
                            setState(() => _currentPage = p),
                        itemCount: _kTotalMonths,
                        itemBuilder: (ctx, index) {
                          return _MonthGrid(
                            monthOffset: _offsetFor(index),
                            dayMap: dayMap,
                            scrollController: scrollController,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // ── Legend ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(
                      color: _kCompletedColor,
                      label: 'Completed',
                    ),
                    const SizedBox(width: 16),
                    _LegendItem(
                      color: _kFrozenColor,
                      label: 'Freeze used',
                    ),
                    const SizedBox(width: 16),
                    _LegendItem(
                      color: colorScheme.surfaceContainerHigh,
                      label: 'Missed',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MonthGrid — calendar grid for a single month
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a 7-column grid for the calendar month identified by [monthOffset]
/// (0 = current month, 1 = last month, …).
///
/// [dayMap] maps "yyyy-MM-dd" keys to [DayStatus] records.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.monthOffset,
    required this.dayMap,
    required this.scrollController,
  });

  final int monthOffset;
  final Map<String, DayStatus> dayMap;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month - monthOffset, 1);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;

    // weekday: 1=Mon…7=Sun → convert to 0=Sun…6=Sat
    final leadingBlanks = first.weekday % 7;

    final children = <Widget>[
      // Blank spacer cells before the 1st of the month
      for (int i = 0; i < leadingBlanks; i++) const SizedBox(),

      // Day cells
      for (int day = 1; day <= daysInMonth; day++)
        _DayCell(
          day: day,
          status: dayMap[_dateKey(DateTime(first.year, first.month, day))],
          isFuture: DateTime(first.year, first.month, day).isAfter(now),
        ),
    ];

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 2,
        childAspectRatio: 1.0,
        children: children,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayCell — a single day in the calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.status,
    required this.isFuture,
  });

  final int day;
  final DayStatus? status;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isToday = status?.isToday ?? false;
    final completed = status?.completed ?? false;
    final frozeStreak = status?.frozeStreak ?? false;
    final hasData = status != null;

    // ── Background and text colours ─────────────────────────────────────────
    Color bgColor;
    Color textColor;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.25);
    } else if (completed) {
      bgColor = _kCompletedColor;
      textColor = Colors.white;
    } else if (frozeStreak) {
      bgColor = _kFrozenColor;
      textColor = Colors.white;
    } else if (hasData) {
      bgColor = colorScheme.surfaceContainerHigh;
      textColor = colorScheme.onSurfaceVariant;
    } else {
      // No tracking data (before the feature was released / older month)
      bgColor = Colors.transparent;
      textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    }

    // ── Today border ────────────────────────────────────────────────────────
    BoxBorder? border;
    if (isToday) {
      border = Border.all(color: colorScheme.primary, width: 2);
    }

    // ── Accessibility label ─────────────────────────────────────────────────
    final statusStr = completed
        ? 'completed'
        : frozeStreak
            ? 'streak frozen'
            : isFuture
                ? 'upcoming'
                : hasData
                    ? 'not completed'
                    : '';

    final semanticLabel = isToday
        ? 'Today, day $day${statusStr.isNotEmpty ? ", $statusStr" : ""}'
        : 'Day $day${statusStr.isNotEmpty ? ", $statusStr" : ""}';

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LegendItem
// ─────────────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper
// ─────────────────────────────────────────────────────────────────────────────

/// Stable "yyyy-MM-dd" key for use in the [dayMap] lookup.
String _dateKey(DateTime date) =>
    '${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
