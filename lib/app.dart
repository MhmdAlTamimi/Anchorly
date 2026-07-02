// Root widget: theme, localization and the bottom-nav shell.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;

import 'core/theme/theme.dart';
import 'home_shell.dart';

class AnchorlyApp extends StatelessWidget {
  const AnchorlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anchorly',
      debugShowCheckedModeBanner: false,

      // Follow the system light/dark setting.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,

      // Localizations. We support English (LTR) and Arabic (RTL). The
      // FlutterQuill delegate is required by the rich-text editor. We do NOT
      // force a global locale/direction — direction is detected per text field
      // so Arabic and English can coexist in one note.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],

      home: const HomeShell(),
    );
  }
}
