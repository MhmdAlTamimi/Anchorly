// NOTES TAB — home list
// ----------------------
//  * Scrollable list of all notes with title/preview + last-edited time. (N1)
//  * Create new note (FAB); swipe-to-delete with confirm.                 (N2)
//  * Tapping a note opens the rich-text editor.                          (N3)
//
// Data model (Note): id, title, contentJson (Quill delta), createdAt, updatedAt.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/confirm_dialog.dart';
import '../../shared/text_direction.dart';
import 'note_editor_page.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  NotesDao get _dao => db.notesDao;

  Future<void> _createAndOpen(BuildContext context) async {
    final id = await _dao.createEmpty();
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: id)),
      );
    }
    // If the note was left completely empty, tidy it up so the list stays clean.
    final note = await _dao.getById(id);
    if (_plainText(note.contentJson).isEmpty && note.title.trim().isEmpty) {
      await _dao.deleteNote(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createAndOpen(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _dao.watchAll(),
        builder: (context, snap) {
          final notes = snap.data ?? const [];
          if (notes.isEmpty) return const _EmptyState();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final note = notes[i];
              return _NoteTile(
                note: note,
                onOpen: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NoteEditorPage(noteId: note.id),
                  ),
                ),
                onDelete: () => _dao.deleteNote(note.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onOpen,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _plainText(note.contentJson);
    final title = note.title.trim().isEmpty
        ? (preview.isEmpty ? 'Untitled' : preview.split('\n').first)
        : note.title.trim();

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirm(
        context,
        title: 'Delete note?',
        message: 'This note will be permanently removed.',
      ),
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        child: Icon(Icons.delete_rounded, color: theme.colorScheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: onOpen,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: directionOf(title),
        ),
        subtitle: Text(
          preview.isEmpty ? 'No additional text' : preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textDirection: directionOf(preview),
        ),
        trailing: Text(
          _relativeTime(note.updatedAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
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
          Icon(Icons.sticky_note_2_rounded,
              size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: Spacing.sm),
          Text('No notes yet — tap + to write one.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              )),
        ],
      ),
    );
  }
}

/// Best-effort plain-text preview of a Quill delta (safe on empty/invalid JSON).
String _plainText(String contentJson) {
  try {
    final data = jsonDecode(contentJson);
    if (data is List && data.isNotEmpty) {
      return Document.fromJson(data).toPlainText().trim();
    }
  } catch (_) {
    // Fall through to empty on any parse issue.
  }
  return '';
}

String _relativeTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat.MMMd().format(t);
}
