// Single shared database instance for the whole app.
//
// This is a single-user, offline app, so one global instance is the simplest
// option that works (per the PRD's "pick the simplest option" rule). It is
// created once at startup and every feature reads from it.

import 'database.dart';

/// The one app-wide database. Access DAOs via `db.todoDao`, `db.notesDao`, etc.
final AppDatabase db = AppDatabase();
