// Per-field text-direction detection (the trickiest UX detail in the app).
//
// We do NOT force a global direction. Instead each field decides its own
// direction from the text typed into it: Arabic → RTL, English → LTR. This is
// what lets Arabic and English coexist without one looking "broken".

import 'package:flutter/widgets.dart';
// Import ONLY Bidi from intl — intl also exports its own `TextDirection`
// class, which would collide with Flutter's dart:ui TextDirection.
import 'package:intl/intl.dart' show Bidi;

/// Returns the natural direction for [text].
///
/// Uses the first "strong" character: if the text begins with (or, when it
/// starts with neutral characters, predominantly contains) RTL script, we lay
/// it out RTL; otherwise LTR. Falls back to [fallback] for empty text so an
/// empty field matches the surrounding UI.
TextDirection directionOf(String text, {TextDirection fallback = TextDirection.ltr}) {
  if (text.trim().isEmpty) return fallback;
  return Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
}
