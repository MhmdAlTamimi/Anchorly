// JOURNAL TAB — habit calendar
// ----------------------------
//  * Monthly calendar for one habit.                                      (J1)
//  * Per day three states: success (green), relapse (red),
//    unfilled/neutral (grey). Tapping a day edits its state.              (J2)
//  * Each day holds a free-text note; past days are revisitable.          (J3, J4)
//
// Data model (DayEntry): id, habitId (FK), date, state, note.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/text_direction.dart';

class HabitCalendarPage extends StatefulWidget {
  const HabitCalendarPage({
    super.key,
    required this.habitId,
    required this.habitName,
  });

  final int habitId;
  final String habitName;

  @override
  State<HabitCalendarPage> createState() => _HabitCalendarPageState();
}

class _HabitCalendarPageState extends State<HabitCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  JournalDao get _dao => db.journalDao;

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.habitName)),
      body: StreamBuilder<List<DayEntry>>(
        stream: _dao.watchEntries(widget.habitId),
        builder: (context, snap) {
          final entries = snap.data ?? const <DayEntry>[];
          // Build a fast lookup from day -> state for the calendar builders.
          final byDay = <DateTime, DayState>{
            for (final e in entries) _dayKey(e.date): e.state,
          };

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(Spacing.md),
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.sm),
                  child: TableCalendar<DayEntry>(
                    firstDay: DateTime.utc(2000, 1, 1),
                    lastDay: DateTime.utc(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _selectedDay != null && isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.month,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                      _openDayEditor(selected, byDay[_dayKey(selected)]);
                    },
                    onPageChanged: (focused) => _focusedDay = focused,
                    calendarBuilders: CalendarBuilders<DayEntry>(
                      defaultBuilder: (context, day, _) =>
                          _DayCell(day: day, state: byDay[_dayKey(day)]),
                      outsideBuilder: (context, day, _) =>
                          _DayCell(day: day, state: byDay[_dayKey(day)], outside: true),
                      todayBuilder: (context, day, _) =>
                          _DayCell(day: day, state: byDay[_dayKey(day)], today: true),
                      selectedBuilder: (context, day, _) =>
                          _DayCell(day: day, state: byDay[_dayKey(day)], selected: true),
                    ),
                  ),
                ),
              ),
              const _Legend(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDayEditor(DateTime day, DayState? current) async {
    final existing = await _dao.getEntry(widget.habitId, day);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DayEditorSheet(
        day: day,
        initialState: existing?.state ?? DayState.neutral,
        initialNote: existing?.note ?? '',
        onSave: (state, note) => _dao.upsertEntry(
          habitId: widget.habitId,
          day: day,
          state: state,
          note: note,
        ),
      ),
    );
  }
}

/// A single calendar day, colored by its recorded state.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.state,
    this.today = false,
    this.selected = false,
    this.outside = false,
  });

  final DateTime day;
  final DayState? state;
  final bool today;
  final bool selected;
  final bool outside;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bg;
    Color fg = theme.colorScheme.onSurface;

    switch (state) {
      case DayState.success:
        bg = AppColors.success;
        fg = Colors.white;
      case DayState.relapse:
        bg = AppColors.relapse;
        fg = Colors.white;
      case DayState.neutral:
      case null:
        bg = null; // unfilled/neutral shows plain
    }

    if (outside) {
      fg = fg.withValues(alpha: 0.35);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : today
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    width: 1.5)
                : null,
      ),
      child: Text('${day.day}', style: TextStyle(color: bg == null ? fg : fg)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          _LegendDot(color: AppColors.success, label: 'Success'),
          _LegendDot(color: AppColors.relapse, label: 'Relapse'),
          _LegendDot(color: AppColors.neutral, label: 'Neutral'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Spacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Bottom sheet to set a day's state + note.
class _DayEditorSheet extends StatefulWidget {
  const _DayEditorSheet({
    required this.day,
    required this.initialState,
    required this.initialNote,
    required this.onSave,
  });

  final DateTime day;
  final DayState initialState;
  final String initialNote;
  final Future<void> Function(DayState state, String note) onSave;

  @override
  State<_DayEditorSheet> createState() => _DayEditorSheetState();
}

class _DayEditorSheetState extends State<_DayEditorSheet> {
  late DayState _state = widget.initialState;
  late final TextEditingController _note =
      TextEditingController(text: widget.initialNote);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Add bottom inset so the sheet rises above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMMEEEEd().format(widget.day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          SegmentedButton<DayState>(
            segments: const [
              ButtonSegment(
                value: DayState.success,
                label: Text('Success'),
                icon: Icon(Icons.check_rounded),
              ),
              ButtonSegment(
                value: DayState.relapse,
                label: Text('Relapse'),
                icon: Icon(Icons.close_rounded),
              ),
              ButtonSegment(
                value: DayState.neutral,
                label: Text('Neutral'),
                icon: Icon(Icons.remove_rounded),
              ),
            ],
            selected: {_state},
            onSelectionChanged: (s) => setState(() => _state = s.first),
          ),
          const SizedBox(height: Spacing.md),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _note,
            builder: (context, value, _) => TextField(
              controller: _note,
              textDirection: directionOf(value.text),
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What happened today?',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () async {
                await widget.onSave(_state, _note.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
