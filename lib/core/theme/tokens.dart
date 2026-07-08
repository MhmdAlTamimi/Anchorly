// Design tokens: the single source of truth for spacing, radius and elevation.
//
// Why centralize these? If sizing lives in one file, the whole app stays
// visually consistent and can be re-tuned in one place. Scattering magic
// numbers across widgets is what makes an app impossible to restyle later.

import 'package:flutter/widgets.dart';

/// Consistent spacing scale (a 4-point grid). Use these instead of raw numbers.
class Spacing {
  const Spacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Corner radii for rounded surfaces.
class Radii {
  const Radii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(lg));
}

/// Subtle elevation used sparingly for "depth".
class Elevations {
  const Elevations._();

  static const double card = 1;
  static const double raised = 3;
}
