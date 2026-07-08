// TODO TAB
// --------
// Behavior:
//  * Text field + add button appends an active item.          (T1)
//  * Checking an item marks it done -> moves to a muted,
//    struck-through "Done" section, storing completedAt.       (T2, T3)
//  * Reconcile-on-open deletes done items completed before
//    today (handled in HomeShell/TodoDao).                     (T4)
//  * "Clear all" empties both lists after a confirm dialog.    (T5)
//
// Data model (TodoItem): id, text, isDone, completedAt?, createdAt.

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/confirm_dialog.dart';
import '../../shared/text_direction.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  TodoDao get _dao => db.todoDao;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _dao.addItem(text);
    _controller.clear();
    _focus.requestFocus();
  }

  Future<void> _clearAll() async {
    final ok = await confirm(
      context,
      title: 'Clear all todos?',
      message: 'This removes every active and completed item. This cannot be undone.',
      confirmLabel: 'Clear all',
    );
    if (ok) await _dao.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo'),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _InputBar(controller: _controller, focus: _focus, onSubmit: _add),
          Expanded(
            child: StreamBuilder<List<TodoItem>>(
              stream: _dao.watchActive(),
              builder: (context, activeSnap) {
                final active = activeSnap.data ?? const [];
                return StreamBuilder<List<TodoItem>>(
                  stream: _dao.watchDone(),
                  builder: (context, doneSnap) {
                    final done = doneSnap.data ?? const [];
                    if (active.isEmpty && done.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView(
                      padding: const EdgeInsets.only(bottom: Spacing.xl),
                      children: [
                        for (final item in active)
                          _TodoTile(
                            item: item,
                            onToggle: (v) => _dao.setDone(item.id, v),
                            onDelete: () => _dao.deleteItem(item.id),
                          ),
                        if (done.isNotEmpty) _SectionHeader('Done'),
                        for (final item in done)
                          _TodoTile(
                            item: item,
                            onToggle: (v) => _dao.setDone(item.id, v),
                            onDelete: () => _dao.deleteItem(item.id),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        children: [
          Expanded(
            // Direction follows what the user types (Arabic RTL / English LTR).
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => TextField(
                controller: controller,
                focusNode: focus,
                textDirection: directionOf(value.text),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onSubmit(),
                decoration: const InputDecoration(
                  hintText: 'Add a task…',
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          FilledButton(
            onPressed: onSubmit,
            child: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final TodoItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Icon(Icons.delete_rounded, color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        leading: Checkbox(
          value: item.isDone,
          onChanged: (v) => onToggle(v ?? false),
        ),
        title: Text(
          item.content,
          textDirection: directionOf(item.content),
          style: item.isDone
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: muted,
                )
              : null,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.xs),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          letterSpacing: 1.2,
        ),
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
          Icon(Icons.checklist_rounded,
              size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: Spacing.sm),
          Text('Nothing yet — add your first task.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}
