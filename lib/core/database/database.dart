// Anchorly local database (drift / SQLite).
//
// DATA MODEL OVERVIEW
// -------------------
// This single database backs all three tabs. Each tab owns its own table(s):
//
//   TodoItems  : id, text, isDone, completedAt?, createdAt
//   Notes      : id, title, contentJson (Quill delta), createdAt, updatedAt
//   Habits     : id, name, createdAt
//   DayEntries : id, habitId (FK -> Habits.id), date, state, note
//   CheckIns   : id, createdAt, emotionsJson, note, urge{Intensity,Outcome},
//                urgeNote, coping  (a timestamped self check-in)
//
// One-to-many: one Habit has many DayEntries, linked by DayEntries.habitId.
// Deleting a Habit cascades and removes all of its DayEntries (see the FK).
//
// Why drift (not raw sqflite)? When the app grows (e.g. a new column, a 4th
// tab) drift's `schemaVersion` + `migration` let us evolve the schema WITHOUT
// wiping the user's existing data. Bump schemaVersion and add an `onUpgrade`
// step; never edit an old migration.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// The three states a Journal day can hold.
/// Stored as an integer in SQLite via drift's `intEnum`.
enum DayState { neutral, success, relapse }

/// What happened with an urge, when one is logged on a check-in.
enum UrgeOutcome { resisted, partly, gaveIn }

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Named `content` (not `text`): a getter called `text` would clash with
  // drift's inherited Table.text() column builder.
  TextColumn get content => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  // Null until the item is checked off; set to the moment it was completed.
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  // Quill stores rich text as a JSON "delta" — kept as a text blob here.
  TextColumn get contentJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class DayEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  // Foreign key to Habits. onDelete cascade => deleting a habit removes its days.
  IntColumn get habitId =>
      integer().references(Habits, #id, onDelete: KeyAction.cascade)();
  // Normalized to midnight so "a day" is unambiguous.
  DateTimeColumn get date => dateTime()();
  IntColumn get state => intEnum<DayState>()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, date},
      ];
}

class CheckIns extends Table {
  IntColumn get id => integer().autoIncrement()();
  // The moment being recorded (defaults to now, but editable).
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // Selected emotions as a JSON list of strings, e.g. ["Anxious","Tired"].
  TextColumn get emotionsJson => text().withDefault(const Constant('[]'))();
  // Optional free note ("what happened / anything to note").
  TextColumn get note => text().withDefault(const Constant(''))();
  // Optional urge section. A urge is "present" when urgeIntensity is non-null.
  IntColumn get urgeIntensity => integer().nullable()(); // 0..10
  IntColumn get urgeOutcome => intEnum<UrgeOutcome>().nullable()();
  TextColumn get urgeNote => text().withDefault(const Constant(''))(); // what the urge was
  TextColumn get coping => text().withDefault(const Constant(''))(); // what helped / will try
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [TodoItems, Notes, Habits, DayEntries, CheckIns],
  daos: [TodoDao, NotesDao, JournalDao, CheckInDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test/alternate constructor allowing an injected executor.
  AppDatabase.forTesting(super.executor);

  // v1: Todo/Notes/Journal.  v2: added the CheckIns table.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Fresh installs get every current table.
        onCreate: (m) => m.createAll(),
        // Existing installs evolve without losing data. Each `if (from < N)`
        // block runs once, in order, to bring an old database up to date.
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(checkIns);
          }
        },
        beforeOpen: (details) async {
          // Enforce foreign keys so the cascade delete above actually runs.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Opens (lazily) the SQLite file in the app's private documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'anchorly.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

// ---------------------------------------------------------------------------
// DAOs — one per feature so each tab's queries live together.
// ---------------------------------------------------------------------------

@DriftAccessor(tables: [TodoItems])
class TodoDao extends DatabaseAccessor<AppDatabase> with _$TodoDaoMixin {
  TodoDao(super.db);

  /// Active (not-done) items, newest first.
  Stream<List<TodoItem>> watchActive() {
    return (select(todoItems)
          ..where((t) => t.isDone.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Completed items, most recently completed first.
  Stream<List<TodoItem>> watchDone() {
    return (select(todoItems)
          ..where((t) => t.isDone.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .watch();
  }

  Future<void> addItem(String text) {
    return into(todoItems).insert(
      TodoItemsCompanion.insert(content: text),
    );
  }

  /// Toggle done state; stamps/clears completedAt accordingly.
  Future<void> setDone(int id, bool done) {
    return (update(todoItems)..where((t) => t.id.equals(id))).write(
      TodoItemsCompanion(
        isDone: Value(done),
        completedAt: Value(done ? DateTime.now() : null),
      ),
    );
  }

  Future<void> deleteItem(int id) {
    return (delete(todoItems)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAll() => delete(todoItems).go();

  /// T4 reconcile-on-open: remove DONE items completed before today.
  ///
  /// Why this pattern instead of a midnight timer? Mobile OSes kill background
  /// work to save battery, so there is no reliable "run at midnight while the
  /// app is closed". Instead we record WHEN each item was completed and clean
  /// up the next time the app opens on a new day. Returns rows deleted.
  Future<int> reconcileForToday() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (delete(todoItems)
          ..where((t) =>
              t.isDone.equals(true) & t.completedAt.isSmallerThanValue(startOfToday)))
        .go();
  }
}

@DriftAccessor(tables: [Notes])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  /// All notes, most recently edited first.
  Stream<List<Note>> watchAll() {
    return (select(notes)..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  Future<Note> getById(int id) {
    return (select(notes)..where((n) => n.id.equals(id))).getSingle();
  }

  /// Creates an empty note and returns its new id.
  Future<int> createEmpty() {
    return into(notes).insert(const NotesCompanion());
  }

  Future<void> save(int id, {required String title, required String contentJson}) {
    return (update(notes)..where((n) => n.id.equals(id))).write(
      NotesCompanion(
        title: Value(title),
        contentJson: Value(contentJson),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteNote(int id) {
    return (delete(notes)..where((n) => n.id.equals(id))).go();
  }
}

@DriftAccessor(tables: [Habits, DayEntries])
class JournalDao extends DatabaseAccessor<AppDatabase> with _$JournalDaoMixin {
  JournalDao(super.db);

  Stream<List<Habit>> watchHabits() {
    return (select(habits)..orderBy([(h) => OrderingTerm.asc(h.createdAt)]))
        .watch();
  }

  Future<int> addHabit(String name) {
    return into(habits).insert(HabitsCompanion.insert(name: name));
  }

  /// Deleting a habit cascades to its day entries via the FK (see DayEntries).
  Future<void> deleteHabit(int habitId) {
    return (delete(habits)..where((h) => h.id.equals(habitId))).go();
  }

  /// All day entries for one habit — used to color the calendar.
  Stream<List<DayEntry>> watchEntries(int habitId) {
    return (select(dayEntries)..where((e) => e.habitId.equals(habitId))).watch();
  }

  Future<DayEntry?> getEntry(int habitId, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return (select(dayEntries)
          ..where((e) => e.habitId.equals(habitId) & e.date.equals(d)))
        .getSingleOrNull();
  }

  /// Insert or update the state + note for a given habit/day.
  ///
  /// We look up the existing row by the (habitId, date) pair and update it, or
  /// insert a new one. (We can't use `insertOnConflictUpdate`, because that
  /// upserts on the PRIMARY KEY `id`; our "one row per day" rule is enforced by
  /// the separate unique (habitId, date) index.)
  Future<void> upsertEntry({
    required int habitId,
    required DateTime day,
    required DayState state,
    required String note,
  }) async {
    final d = DateTime(day.year, day.month, day.day);
    final existing = await (select(dayEntries)
          ..where((e) => e.habitId.equals(habitId) & e.date.equals(d)))
        .getSingleOrNull();
    if (existing == null) {
      await into(dayEntries).insert(
        DayEntriesCompanion.insert(
          habitId: habitId,
          date: d,
          state: state,
          note: Value(note),
        ),
      );
    } else {
      await (update(dayEntries)..where((e) => e.id.equals(existing.id))).write(
        DayEntriesCompanion(state: Value(state), note: Value(note)),
      );
    }
  }
}

@DriftAccessor(tables: [CheckIns])
class CheckInDao extends DatabaseAccessor<AppDatabase> with _$CheckInDaoMixin {
  CheckInDao(super.db);

  /// All check-ins recorded on [day], newest first.
  Stream<List<CheckIn>> watchForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (select(checkIns)
          ..where((c) =>
              c.createdAt.isBiggerOrEqualValue(start) &
              c.createdAt.isSmallerThanValue(end))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  /// Insert (id == null) or update a check-in. Takes plain values so the UI
  /// never has to touch drift types. Emotions arrive already JSON-encoded.
  Future<void> saveEntry({
    int? id,
    required DateTime createdAt,
    required String emotionsJson,
    required String note,
    int? urgeIntensity,
    UrgeOutcome? urgeOutcome,
    required String urgeNote,
    required String coping,
  }) async {
    final companion = CheckInsCompanion(
      createdAt: Value(createdAt),
      emotionsJson: Value(emotionsJson),
      note: Value(note),
      urgeIntensity: Value(urgeIntensity),
      urgeOutcome: Value(urgeOutcome),
      urgeNote: Value(urgeNote),
      coping: Value(coping),
    );
    if (id == null) {
      await into(checkIns).insert(companion);
    } else {
      await (update(checkIns)..where((c) => c.id.equals(id))).write(companion);
    }
  }

  Future<void> deleteEntry(int id) {
    return (delete(checkIns)..where((c) => c.id.equals(id))).go();
  }
}
