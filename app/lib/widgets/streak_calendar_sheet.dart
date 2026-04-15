/// StreakCalendarSheet — bottom sheet showing a 30-day streak calendar grid.
///
/// Displays each day colour-coded:
/// - 🟢 Green  : completed day
/// - 🔵 Blue   : streak freeze used
/// - ⚫ Gray   : missed past day
/// - 🔘 Outline: today (with colour fill from above)
///
/// Supports swiping left/right (via [PageView]) to navigate up to
/// [_totalMonths] months back from the current month.
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
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the [StreakCalendarSheet] as a modal bottom sheet.
///
/// Call this from an [InkWell] / [GestureDetector] onTap handler, e.g. the
/// Streak tile inside [ActivityStatsCard].
void showStreakCalendarSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const StreakCalendarSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// StreakCalendarSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Number of months the user can swipe back to.
const int _totalMonths = 6;

/// Day-of-week header labels, starting from Sunday.
const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// Month name lookup (1-indexed).
const _monthNames = [
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

/// Bottom sheet that renders a swipeable monthly calendar of streak activity.
///
/// Uses [streakCalendarProvider] to obtain [DayStatus] records.  Data outside
/// the provider's 30-day window (e.g. older months the user swipes to) is
/// shown as empty cells — no false "missed" signal is displayed.
class StreakCalendarSheet extends ConsumerStatefulWidget {
  const StreakCalendarSheet({super.key});

  @override
  ConsumerState<StreakCalendarSheet> createState() =>
      _StreakCalendarSheetState();
}

class _StreakCalendarSheetState extends ConsumerState<StreakCalendarSheet> {
  late PageController _pageController;

  /// Index into the [PageView].  0 = oldest allowed month, [_totalMonths]-1 =
  /// current month.
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _totalMonths - 1; // start at current month
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Returns the month offset from *now* for a given [pageIndex].
  ///
  /// pageIndex == _totalMonths - 1  →  monthOffset == 0 (current month)
  /// pageIndex == 0                 →  monthOffset == _totalMonths - 1
  int _monthOffsetFor(int pageIndex) => _totalMonths - 1 - pageIndex;

  /// Human-readable "Month YYYY" label for the page at [pageIndex].
  String _monthLabel(int pageIndex) {
    final offset = _monthOffsetFor(pageIndex);
    final now = DateTime.now();
    final target = DateTime(now.year, now.month - offset, 1);
    return '${_monthNames[target.month]} ${target.year}';
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────────────────
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
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Month navigation header ─────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous month',
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
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next month',
                      color: colorScheme.primary,
                      onPressed: _currentPage < _totalMonths - 1
                          ? () => _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              )
                          : null,
                    ),
                  ],
                ),
              ),

              // ── Weekday header row ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _weekdayLabels
                      .map(
                        (d) => SizedBox(
                          width: 36,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 6),

              // ── Month PageView ──────────────────────────────────────────────
              Expanded(
                child: calendarAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
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
                    // Build a lookup map: "yyyy-MM-dd" → DayStatus
                    final dayMap = <String, DayStatus>{
                      for (final d in days) _dateKey(d.date): d,
                    };

                    return Semantics(
                      label: 'Streak calendar — swipe left or right to change months',
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        itemCount: _totalMonths,
                        itemBuilder: (ctx, index) {
                          final offset = _monthOffsetFor(index);
                          return _MonthGrid(
                            monthOffset: offset,
                            dayMap: dayMap,
                            scrollController: scrollController,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // ── Legend ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(
                      color: _completedColor,
                      label: 'Completed',
                    ),
                    const SizedBox(width: 16),
                    _LegendItem(
                      color: _frozenColor,
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
// _MonthGrid
// ─────────────────────────────────────────────────────────────────────────────

/// Builds the grid of day cells for a single calendar month.
///
/// [monthOffset] == 0 means the current month; 1 means last month, etc.
/// [dayMap] maps "yyyy-MM-dd" strings to [DayStatus] records.
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
    // First day of the target month
    final first = DateTime(now.year, now.month - monthOffset, 1);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;

    // weekday: 1=Mon … 7=Sun.  We want 0=Sun … 6=Sat (standard US calendar).
    // weekday % 7 converts: Mon→1, Tue→2, …, Sat→6, Sun→0.
    final leadingBlanks = first.weekday % 7;

    final cells = <Widget>[
      // Leading empty cells for alignment
      for (int i = 0; i < leadingBlanks; i++) const SizedBox(),

      // Day cells
      for (int day = 1; day <= daysInMonth; day++)
        _buildDayCell(context, first, day, now),
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
        children: cells,
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime first,
    int day,
    DateTime now,
  ) {
    final date = DateTime(first.year, first.month, day);
    final key = _dateKey(date);
    final status = dayMap[key];
    final isFuture = date.isAfter(now);

    return _DayCell(
      day: day,
      status: status,
      isFuture: isFuture,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DayCell
// ─────────────────────────────────────────────────────────────────────────────

/// Day-of-month cell with colour coding for streak status.
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

    // ── Colour logic ────────────────────────────────────────────────────────
    Color bgColor;
    Color textColor;

    if (isFuture) {
      bgColor = Colors.transparent;
      textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.25);
    } else if (completed) {
      bgColor = _completedColor;
      textColor = Colors.white;
    } else if (frozeStreak) {
      bgColor = _frozenColor;
      textColor = Colors.white;
    } else if (hasData) {
      // Past day with data but not completed
      bgColor = colorScheme.surfaceContainerHigh;
      textColor = colorScheme.onSurfaceVariant;
    } else {
      // No data (before tracking began or future month)
      bgColor = Colors.transparent;
      textColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.35);
    }

    // ── Border for today ────────────────────────────────────────────────────
    BoxBorder? border;
    if (isToday) {
      border = Border.all(color: colorScheme.primary, width: 2);
    }

    // ── Accessibility label ─────────────────────────────────────────────────
    final statusLabel = completed
        ? 'completed'
        : frozeStreak
            ? 'streak frozen'
            : isFuture
                ? 'upcoming'
                : hasData
                    ? 'not completed'
                    : '';
    final semanticLabel = isToday
        ? 'Today, day $day${statusLabel.isNotEmpty ? ", $statusLabel" : ""}'
        : 'Day $day${statusLabel.isNotEmpty ? ", $statusLabel" : ""}';

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
// Shared helpers / constants
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a stable string key for a given [date]: "yyyy-MM-dd".
String _dateKey(DateTime date) =>
    '${date.year}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Background colour for a completed day cell.
const Color _completedColor = Color(0xFF4CAF50); // Material Green 500

/// Background colour for a day where a streak freeze was consumed.
const Color _frozenColor = Color(0xFF64B5F6); // Material Blue 300
