import 'package:flutter/widgets.dart';

/// Spacing values measured from the design frames.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Horizontal page gutter.
  static const double gutter = 22;

  /// Gap between content sections.
  static const double section = 20;

  static const headerPadding = EdgeInsets.fromLTRB(gutter, 10, gutter, 18);
  static const contentPadding = EdgeInsets.fromLTRB(gutter, 6, gutter, 24);
  static const cardPadding = EdgeInsets.all(16);
  static const calloutPadding = EdgeInsets.all(14);
}

abstract final class AppRadii {
  static const double button = 10;
  static const double card = 18;
  static const double viewfinder = 26;
  static const double pill = 100;

  static const buttonRadius = BorderRadius.all(Radius.circular(button));
  static const cardRadius = BorderRadius.all(Radius.circular(card));
  static const pillRadius = BorderRadius.all(Radius.circular(pill));
}
