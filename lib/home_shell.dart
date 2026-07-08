// The bottom-navigation shell that hosts the three tabs.
//
// Uses an IndexedStack so each tab keeps its scroll position/state when you
// switch away and back. A 4th tab can be added by appending to the two lists
// below — no other tab needs to change (feature-first modularity).

import 'package:flutter/material.dart';

import 'core/database/db.dart';
import 'features/checkin/checkin_page.dart';
import 'features/journal/journal_page.dart';
import 'features/notes/notes_page.dart';
import 'features/todo/todo_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _pages = [
    TodoPage(),
    NotesPage(),
    JournalPage(),
    CheckinPage(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.checklist_rounded),
      label: 'Todo',
    ),
    NavigationDestination(
      icon: Icon(Icons.sticky_note_2_rounded),
      label: 'Notes',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_rounded),
      label: 'Journal',
    ),
    NavigationDestination(
      icon: Icon(Icons.self_improvement_rounded),
      label: 'Check-in',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Reconcile-on-open: clean up stale done todos at startup (see TodoDao).
    db.todoDao.reconcileForToday();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Also reconcile when the app returns to the foreground on a new day.
    if (state == AppLifecycleState.resumed) {
      db.todoDao.reconcileForToday();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: _destinations,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}
