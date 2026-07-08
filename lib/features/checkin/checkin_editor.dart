// CHECK-IN TAB — add / edit sheet
// -------------------------------
// A single unified record: pick emotions (chips), optionally add a note, and
// optionally expand an "urge" section (what it was, how strong 0–10, the
// outcome, and what helped). Kept deliberately quick to fill.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/database/db.dart';
import '../../core/theme/tokens.dart';
import '../../shared/text_direction.dart';

/// The emotions offered as quick-pick chips.
const List<String> kEmotionChoices = [
  'Calm', 'Content', 'Happy', 'Grateful', 'Hopeful', 'Motivated',
  'Tired', 'Bored', 'Stressed', 'Anxious', 'Overwhelmed', 'Sad',
  'Lonely', 'Frustrated', 'Angry', 'Ashamed', 'Guilty', 'Numb',
];

/// Decodes the stored JSON list of emotions (safe on empty/invalid input).
List<String> emotionsFromJson(String json) {
  try {
    final data = jsonDecode(json);
    if (data is List) return data.map((e) => e.toString()).toList();
  } catch (_) {}
  return const [];
}

/// Opens the add/edit sheet. [day] is the day being viewed (used to date a new
/// record); [existing] is non-null when editing.
Future<void> showCheckinEditor(
  BuildContext context, {
  required DateTime day,
  CheckIn? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CheckinEditor(day: day, existing: existing),
  );
}

class _CheckinEditor extends StatefulWidget {
  const _CheckinEditor({required this.day, this.existing});

  final DateTime day;
  final CheckIn? existing;

  @override
  State<_CheckinEditor> createState() => _CheckinEditorState();
}

class _CheckinEditorState extends State<_CheckinEditor> {
  late final Set<String> _emotions;
  late final TextEditingController _note;
  late final TextEditingController _urgeNote;
  late final TextEditingController _coping;
  late bool _hasUrge;
  late double _intensity;
  UrgeOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _emotions = {...(e != null ? emotionsFromJson(e.emotionsJson) : const [])};
    _note = TextEditingController(text: e?.note ?? '');
    _urgeNote = TextEditingController(text: e?.urgeNote ?? '');
    _coping = TextEditingController(text: e?.coping ?? '');
    _hasUrge = e?.urgeIntensity != null;
    _intensity = (e?.urgeIntensity ?? 5).toDouble();
    _outcome = e?.urgeOutcome;
  }

  @override
  void dispose() {
    _note.dispose();
    _urgeNote.dispose();
    _coping.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final e = widget.existing;
    // New records are stamped now (today) or at noon of a past day being viewed.
    final now = DateTime.now();
    final isToday = DateUtils.isSameDay(widget.day, now);
    final createdAt = e?.createdAt ??
        (isToday
            ? now
            : DateTime(widget.day.year, widget.day.month, widget.day.day, 12));

    await db.checkInDao.saveEntry(
      id: e?.id,
      createdAt: createdAt,
      emotionsJson: jsonEncode(_emotions.toList()),
      note: _note.text.trim(),
      urgeIntensity: _hasUrge ? _intensity.round() : null,
      urgeOutcome: _hasUrge ? _outcome : null,
      urgeNote: _hasUrge ? _urgeNote.text.trim() : '',
      coping: _hasUrge ? _coping.text.trim() : '',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          Spacing.lg, 0, Spacing.lg, Spacing.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'New check-in' : 'Edit check-in',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Spacing.md),

          Text('How are you feeling?',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: [
              for (final emo in kEmotionChoices)
                FilterChip(
                  label: Text(emo),
                  selected: _emotions.contains(emo),
                  onSelected: (on) => setState(
                      () => on ? _emotions.add(emo) : _emotions.remove(emo)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          _field(_note,
              label: 'What happened / anything to note', minLines: 2, maxLines: 4),
          const SizedBox(height: Spacing.md),

          // Optional urge section — hidden behind a switch so a plain mood
          // check-in stays a couple of taps.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Log an urge'),
            value: _hasUrge,
            onChanged: (v) => setState(() => _hasUrge = v),
          ),
          if (_hasUrge) _buildUrgeSection(context),

          const SizedBox(height: Spacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_urgeNote, label: 'The urge was…'),
        const SizedBox(height: Spacing.sm),
        Text('Intensity: ${_intensity.round()}/10',
            style: Theme.of(context).textTheme.labelLarge),
        Slider(
          value: _intensity,
          min: 0,
          max: 10,
          divisions: 10,
          label: '${_intensity.round()}',
          onChanged: (v) => setState(() => _intensity = v),
        ),
        const SizedBox(height: Spacing.sm),
        SegmentedButton<UrgeOutcome>(
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(value: UrgeOutcome.resisted, label: Text('Resisted')),
            ButtonSegment(value: UrgeOutcome.partly, label: Text('Partly')),
            ButtonSegment(value: UrgeOutcome.gaveIn, label: Text('Gave in')),
          ],
          selected: _outcome == null ? const {} : {_outcome!},
          onSelectionChanged: (s) =>
              setState(() => _outcome = s.isEmpty ? null : s.first),
        ),
        const SizedBox(height: Spacing.md),
        _field(_coping,
            label: 'What helped / what I\'ll try', minLines: 2, maxLines: 3),
      ],
    );
  }

  /// A text field whose direction follows what's typed (Arabic RTL / English
  /// LTR), so notes read correctly in either language.
  Widget _field(
    TextEditingController controller, {
    required String label,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textDirection: directionOf(value.text),
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
