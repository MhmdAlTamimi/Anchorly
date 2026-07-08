// CHECK-IN TAB
// ------------
// A place to check in with yourself: quick, timestamped records of how you feel
// (emotion chips) with an optional note and an optional urge log. Opens on today
// and lists that day's check-ins; step back/forward to see other days.
//
// Data model (CheckIn): id, createdAt, emotionsJson, note, urgeIntensity?,
// urgeOutcome?, urgeNote, coping.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/confirm_dialog.dart';
import '../../shared/text_direction.dart';
import 'checkin_editor.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  CheckInDao get _dao => db.checkInDao;

  bool get _isToday => DateUtils.isSameDay(_day, DateTime.now());

  void _shiftDay(int days) {
    setState(() => _day = DateUtils.addDaysToDate(_day, days));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        actions: [
          if (!_isToday)
            TextButton(
              onPressed: () =>
                  setState(() => _day = DateUtils.dateOnly(DateTime.now())),
              child: const Text('Today'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCheckinEditor(context, day: _day),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          _DayNavigator(
            day: _day,
            canGoForward: !_isToday,
            onPrev: () => _shiftDay(-1),
            onNext: () => _shiftDay(1),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CheckIn>>(
              stream: _dao.watchForDay(_day),
              builder: (context, snap) {
                final items = snap.data ?? const [];
                if (items.isEmpty) return const _EmptyState();
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _CheckinTile(
                    item: items[i],
                    onEdit: () => showCheckinEditor(context,
                        day: _day, existing: items[i]),
                    onDelete: () => _dao.deleteEntry(items[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.day,
    required this.canGoForward,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime day;
  final bool canGoForward;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateUtils.isSameDay(day, DateTime.now())
        ? 'Today'
        : DateFormat.yMMMEd().format(day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            onPressed: canGoForward ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _CheckinTile extends StatelessWidget {
  const _CheckinTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final CheckIn item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emotions = emotionsFromJson(item.emotionsJson);
    final time = DateFormat.jm().format(item.createdAt);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(
        context,
        title: 'Delete this check-in?',
        message: 'This record will be permanently removed.',
      ),
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Icon(Icons.delete_rounded,
            color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: onEdit,
        title: Text(
          emotions.isEmpty ? 'Check-in' : emotions.join(' · '),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.note.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  item.note.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: directionOf(item.note),
                ),
              ),
            if (item.urgeIntensity != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _urgeSummary(item),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.tertiary),
                ),
              ),
          ],
        ),
        trailing: Text(time, style: theme.textTheme.labelSmall),
      ),
    );
  }

  String _urgeSummary(CheckIn item) {
    final parts = <String>['Urge ${item.urgeIntensity}/10'];
    switch (item.urgeOutcome) {
      case UrgeOutcome.resisted:
        parts.add('Resisted');
      case UrgeOutcome.partly:
        parts.add('Partly');
      case UrgeOutcome.gaveIn:
        parts.add('Gave in');
      case null:
        break;
    }
    if (item.urgeNote.trim().isNotEmpty) parts.add(item.urgeNote.trim());
    return parts.join(' · ');
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
          Icon(Icons.self_improvement_rounded,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: Spacing.sm),
          Text('No check-ins for this day — tap + to add one.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}
