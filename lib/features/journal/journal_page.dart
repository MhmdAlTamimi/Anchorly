// JOURNAL TAB — habit list
// ------------------------
//  * List of habits; adding one creates its own dedicated calendar.      (J1)
//  * Tapping a habit opens its monthly calendar.                          (J1)
//  * Deleting a habit removes its calendar and all day entries (confirm). (J5)
//
// Data model: Habit(id, name, createdAt) has many DayEntry rows (one-to-many).

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/confirm_dialog.dart';
import '../../shared/text_direction.dart';
import 'habit_calendar_page.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  JournalDao get _dao => db.journalDao;

  Future<void> _addHabit(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New habit'),
        content: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TextField(
            controller: controller,
            autofocus: true,
            textDirection: directionOf(value.text),
            decoration: const InputDecoration(hintText: 'e.g. Read, Exercise…'),
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await _dao.addHabit(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addHabit(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<Habit>>(
        stream: _dao.watchHabits(),
        builder: (context, snap) {
          final habits = snap.data ?? const [];
          if (habits.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            itemCount: habits.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final habit = habits[i];
              return ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.local_fire_department_rounded),
                ),
                title: Text(habit.name, textDirection: directionOf(habit.name)),
                trailing: IconButton(
                  tooltip: 'Delete habit',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Delete "${habit.name}"?',
                      message:
                          'This removes the habit and every day recorded for it.',
                    );
                    if (ok) await _dao.deleteHabit(habit.id);
                  },
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HabitCalendarPage(
                      habitId: habit.id,
                      habitName: habit.name,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_month_rounded,
              size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: Spacing.sm),
          Text('No habits yet — tap + to start tracking one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}
