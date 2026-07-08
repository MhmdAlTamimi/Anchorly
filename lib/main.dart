// Anchorly — app entry point.
//
// A single Android app bundling three independent, offline tools:
// Todo · Notes · Journal. Data is local-only (SQLite via drift).

import 'package:flutter/material.dart';

import 'app.dart';

void main() {
  // Ensure Flutter bindings are ready before any platform channels (drift, etc).
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnchorlyApp());
}
