// NOTES TAB — editor
// ------------------
//  * Rich-text editing via flutter_quill.                                 (N3)
//  * Bidirectional text: the title follows the text typed into it, and the
//    Quill editor renders Arabic (RTL) and English (LTR) per line, so mixed
//    Arabic+English notes read correctly.                                 (N4, N6)
//  * Reduced, collapsible formatting bar: bold, font size, undo/redo,
//    indentation, quote block.                                            (N5)
//
// Saving: the note is saved LIVE as you type (debounced) and flushed on exit,
// and deleted if left completely empty — so content is never lost.
//
// Rich text is stored as a Quill "delta" (structured JSON), so we save
// `document.toDelta().toJson()` as a string into Note.contentJson.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/text_direction.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.noteId});

  final int noteId;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _editorFocus = FocusNode();
  QuillController? _quill;
  bool _loading = true;
  // Debounces live-saving as the user types (see _onChanged).
  Timer? _debounce;
  // The formatting bar is collapsible so the writing surface stays calm and
  // uncramped. Formatting while typing would be impossible if we auto-hid it on
  // keyboard open, so instead we give a toggle in the app bar.
  bool _showToolbar = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final note = await db.notesDao.getById(widget.noteId);
    _titleController.text = note.title;

    Document doc;
    try {
      final data = jsonDecode(note.contentJson);
      doc = (data is List && data.isNotEmpty)
          ? Document.fromJson(data)
          : Document();
    } catch (_) {
      doc = Document();
    }

    final quill = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    // Save continuously (like the Todo tab): every edit to the title or body
    // schedules a debounced write, so a note is persisted as soon as it has
    // any content — no reliance on a fragile save-on-close.
    quill.addListener(_onChanged);
    _titleController.addListener(_onChanged);

    setState(() {
      _quill = quill;
      _loading = false;
    });
  }

  /// Called on every edit; debounces a save so we don't hit the DB per keystroke.
  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _save);
  }

  bool get _isEmpty {
    final quill = _quill;
    if (quill == null) return true;
    final body = quill.document.toPlainText().trim();
    return body.isEmpty && _titleController.text.trim().isEmpty;
  }

  /// Persist the current title + delta.
  Future<void> _save() async {
    final quill = _quill;
    if (quill == null) return;
    final json = jsonEncode(quill.document.toDelta().toJson());
    await db.notesDao.save(
      widget.noteId,
      title: _titleController.text.trim(),
      contentJson: json,
    );
  }

  /// On leaving: flush a final save, or delete the note if it's completely
  /// empty (so empty notes never linger). Awaited before the route pops, so
  /// there is no race with the list refreshing.
  Future<void> _handleExit() async {
    _debounce?.cancel();
    if (_isEmpty) {
      await db.notesDao.deleteNote(widget.noteId);
    } else {
      await _save();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quill?.removeListener(_onChanged);
    _titleController.removeListener(_onChanged);
    _titleController.dispose();
    _editorFocus.dispose();
    _quill?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quill = _quill;
    // canPop:false lets us finish saving (or delete-if-empty) BEFORE the route
    // actually pops, so the notes list never reads a half-saved state.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExit();
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          IconButton(
            tooltip: _showToolbar ? 'Hide formatting' : 'Show formatting',
            icon: Icon(_showToolbar
                ? Icons.keyboard_hide_rounded
                : Icons.text_format_rounded),
            onPressed: () => setState(() => _showToolbar = !_showToolbar),
          ),
        ],
      ),
      body: _loading || quill == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.md, Spacing.md, Spacing.md, Spacing.sm),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _titleController,
                    builder: (context, value, _) => TextField(
                      controller: _titleController,
                      textDirection: directionOf(value.text),
                      style: Theme.of(context).textTheme.titleLarge,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: QuillEditor.basic(
                    controller: quill,
                    focusNode: _editorFocus,
                    config: const QuillEditorConfig(
                      padding: EdgeInsets.all(Spacing.md),
                      placeholder: 'Write…',
                      autoFocus: false,
                    ),
                  ),
                ),
                // Reduced formatting bar: bold, font size, undo/redo,
                // indentation and quote block only — everything else is hidden
                // to keep it calm and uncluttered. Toggle it from the app bar.
                if (_showToolbar)
                  SafeArea(
                    top: false,
                    child: QuillSimpleToolbar(
                      controller: quill,
                      config: const QuillSimpleToolbarConfig(
                        // Shown:
                        showBoldButton: true,
                        showFontSize: true,
                        showUndo: true,
                        showRedo: true,
                        showIndent: true,
                        showQuote: true,
                        // Hidden:
                        showItalicButton: false,
                        showUnderLineButton: false,
                        showStrikeThrough: false,
                        showInlineCode: false,
                        showCodeBlock: false,
                        showListNumbers: false,
                        showListBullets: false,
                        showListCheck: false,
                        showHeaderStyle: false,
                        showAlignmentButtons: false,
                        showColorButton: false,
                        showBackgroundColorButton: false,
                        showLink: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showClearFormat: false,
                        showFontFamily: false,
                        showSmallButton: false,
                        showDividers: false,
                        showClipboardCopy: false,
                        showClipboardCut: false,
                        showClipboardPaste: false,
                        showDirection: false,
                      ),
                    ),
                  ),
              ],
            ),
      ),
    );
  }
}
