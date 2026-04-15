// TASK-013: Calendar Event Sheet
//
// A modal bottom sheet that lets the user schedule a plan session as a native
// iOS calendar event.
//
// ## Layout (top → bottom)
// 1. Drag handle
// 2. Header — sheet title + Cancel button
// 3. Read-only plan info row — plan name + estimated duration
// 4. Date picker row  — taps to open showDatePicker()
// 5. Time picker row  — taps to open showTimePicker()
// 6. Recurrence dropdown — None / Daily / Weekdays (Mon-Fri) / Weekly
// 7. Add to Calendar ElevatedButton
//
// ## Permission flow
// On tap of "Add to Calendar":
//   1. Call CalendarService.requestPermission().
//   2. If authorized → createEvent() → success SnackBar → Navigator.pop().
//   3. If denied    → AlertDialog with "Open Settings" button.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:instructor/services/calendar_service.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows the [CalendarEventSheet] as a modal bottom sheet.
///
/// [planName]        — Displayed as the event title (read-only).
/// [planDuration]    — Estimated duration shown next to the plan name and used
///                     to set the event end time.
///
/// Returns when the sheet is dismissed (by the user or after a successful
/// event creation).
Future<void> showCalendarEventSheet(
  BuildContext context, {
  required String planName,
  required Duration planDuration,
  String? planId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useRootNavigator: true,
    builder: (_) => CalendarEventSheet(
      planName: planName,
      planDuration: planDuration,
      planId: planId,
    ),
  );
}

// ── CalendarEventSheet ────────────────────────────────────────────────────────

/// A [DraggableScrollableSheet] that lets the user pick a date, time, and
/// recurrence rule before adding the plan session to their iOS calendar.
class CalendarEventSheet extends ConsumerStatefulWidget {
  const CalendarEventSheet({
    super.key,
    required this.planName,
    required this.planDuration,
    this.planId,
  });

  final String planName;
  final Duration planDuration;

  /// Optional plan ID used to build a deep-link URL embedded in the event.
  final String? planId;

  @override
  ConsumerState<CalendarEventSheet> createState() => _CalendarEventSheetState();
}

class _CalendarEventSheetState extends ConsumerState<CalendarEventSheet> {
  // ── Picker state ──────────────────────────────────────────────────────────

  /// Initially set to tomorrow to encourage future scheduling.
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  CalendarRecurrence _recurrence = CalendarRecurrence.none;

  // ── Loading / error state ─────────────────────────────────────────────────

  bool _isAdding = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  }

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Full [DateTime] combining [_selectedDate] and [_selectedTime].
  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  /// Deep-link URL for the event, e.g. `instructor://plans/abc123`.
  String? get _deepLink {
    final id = widget.planId;
    if (id == null || id.isEmpty) return null;
    return 'instructor://plans/$id';
  }

  // ── Pickers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Allow today and any future date.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select session date',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Select session time',
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  // ── Add to Calendar ───────────────────────────────────────────────────────

  Future<void> _addToCalendar() async {
    if (_isAdding) return;

    // Validate that the selected date+time is in the future.
    if (!_startDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected time has already passed. Please choose a future date and time.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isAdding = true);

    final service = ref.read(calendarServiceProvider);

    try {
      final authorized = await service.requestPermission();

      if (!mounted) return;

      if (!authorized) {
        setState(() => _isAdding = false);
        _showPermissionDeniedDialog();
        return;
      }

      await service.createEvent(
        title: widget.planName.isEmpty ? 'Plan Session' : widget.planName,
        durationMinutes: widget.planDuration.inMinutes.clamp(1, 1440),
        startDateTime: _startDateTime,
        recurrence: _recurrence,
        deepLink: _deepLink,
      );

      if (!mounted) return;

      // Pop the sheet first, then show SnackBar on the parent scaffold.
      Navigator.of(context).pop();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Added to Calendar'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      debugPrint('CalendarEventSheet: PlatformException adding event: $e');
      // Map known EventKit error codes to friendly strings.
      final String friendlyMessage;
      if (e.code == 'PERMISSION_DENIED' || e.code == '1') {
        friendlyMessage = 'Calendar access was denied.';
      } else {
        friendlyMessage = 'Could not create event — please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      debugPrint('CalendarEventSheet: unexpected error adding event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add to calendar. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    final service = ref.read(calendarServiceProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calendar Access Required'),
        content: const Text(
          'Instructor needs access to your calendar to create events.\n\n'
          'Please grant Calendar access in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              service.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (sheetContext, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Semantics(
                label: 'Drag to resize sheet',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Sheet header ─────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Add to Calendar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ── Scrollable content ───────────────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    // ── Plan info (read-only) ──────────────────────────────
                    _PlanInfoHeader(
                      planName: widget.planName,
                      planDuration: widget.planDuration,
                    ),
                    const SizedBox(height: 24),

                    // ── Date picker ───────────────────────────────────────
                    _PickerRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(_selectedDate),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),

                    // ── Time picker ───────────────────────────────────────
                    _PickerRow(
                      icon: Icons.access_time_outlined,
                      label: 'Time',
                      value: _selectedTime.format(context),
                      onTap: _pickTime,
                    ),
                    const SizedBox(height: 20),

                    // ── Recurrence dropdown ───────────────────────────────
                    Semantics(
                      label: 'Recurrence',
                      child: DropdownButtonFormField<CalendarRecurrence>(
                        value: _recurrence,
                        decoration: const InputDecoration(
                          labelText: 'Repeat',
                          prefixIcon: Icon(Icons.repeat_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: CalendarRecurrence.values
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label),
                              ),
                            )
                            .toList(),
                        onChanged: (r) {
                          if (r != null) setState(() => _recurrence = r);
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Add to Calendar button ─────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isAdding ? null : _addToCalendar,
                        icon: _isAdding
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _isAdding ? 'Adding…' : 'Add to Calendar',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
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

  // ── Formatters ────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── _PlanInfoHeader ───────────────────────────────────────────────────────────

/// Read-only header showing the plan name and estimated duration.
class _PlanInfoHeader extends StatelessWidget {
  const _PlanInfoHeader({
    required this.planName,
    required this.planDuration,
  });

  final String planName;
  final Duration planDuration;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Semantics(
      label: 'Plan: $planName, duration: ${_formatDuration(planDuration)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.fitness_center_outlined,
                size: 20,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName.isEmpty ? 'Untitled Plan' : planName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(planDuration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
    if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    return '${s}s';
  }
}

// ── _PickerRow ────────────────────────────────────────────────────────────────

/// A tappable list tile that opens a system picker (date or time).
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '$label: $value — tap to change',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
