import 'package:flutter/material.dart';

/// Inter type scale measured from the design. Most copy is Inter Regular;
/// Semi Bold is used for card action labels and form labels, Bold for the
/// active navigation label.
abstract final class AppTypography {
  static const fontFamily = 'Inter';

  static const pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 1.15,
    letterSpacing: -0.8,
    fontWeight: FontWeight.w400,
  );

  static const hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 1.1,
    letterSpacing: -1,
    fontWeight: FontWeight.w400,
  );

  static const sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.25,
    letterSpacing: -0.4,
    fontWeight: FontWeight.w400,
  );

  static const stepTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 1.45,
    fontWeight: FontWeight.w500,
  );

  static const bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 17,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  static const title = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const titleStrong = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

  static const caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    height: 1.45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const navLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  static const stat = TextStyle(
    fontFamily: fontFamily,
    fontSize: 25,
    fontWeight: FontWeight.w400,
  );

  static const timer = TextStyle(
    fontFamily: fontFamily,
    fontSize: 38,
    height: 1.1,
    letterSpacing: -1,
    fontWeight: FontWeight.w600,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const amount = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 1.1,
    letterSpacing: -1,
    fontWeight: FontWeight.w600,
  );
}
