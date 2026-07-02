// NOTES TAB — editor
// ------------------
//  * Rich-text editing via flutter_quill.                                 (N3)
//  * Bidirectional text: the title follows the text typed into it, and the
//    Quill editor renders Arabic (RTL) and English (LTR) per line, so mixed
//    Arabic+English notes read correctly.                                 (N4, N6)
//  * Formatting bar: bold, italic, font sizes, checklist (no colors).     (N5)
//
// Rich text is stored as a Quill "delta" (structured JSON), so we save
// `document.toDelta().toJson()` as a string into Note.contentJson.

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

    setState(() {
      _quill = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _loading = false;
    });
  }

  /// Persist the current title + delta. Called when leaving the editor.
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

  @override
  void dispose() {
    // Fire-and-forget save on the way out (no context needed).
    _save();
    _titleController.dispose();
    _editorFocus.dispose();
    _quill?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quill = _quill;
    return Scaffold(
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
    );
  }
}
