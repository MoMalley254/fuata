
import 'package:flutter/material.dart';

/// Tabular figures keep monetary columns from jittering during updates.
const List<FontFeature> _tnum = [FontFeature.tabularFigures()];

class AppTypography {
  static const _family = 'PlusJakartaSans';

  static const displayHero = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 48 / 40,
    letterSpacing: -0.03,
    fontFeatures: _tnum,
  );

  static const displayHeroMobile = TextStyle(
    fontFamily: _family,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 44 / 36,
    letterSpacing: -0.03,
    fontFeatures: _tnum,
  );

  static const headlineLg = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 32 / 26,
    letterSpacing: -0.02,
  );

  static const headlineSm = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
    letterSpacing: -0.01,
  );

  static const bodyLg = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
  );

  static const bodyMd = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.01,
  );

  static const bodySm = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0.01,
  );

  static const labelLg = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 20 / 15,
    letterSpacing: 0.01,
  );

  static const labelMd = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 18 / 13,
    letterSpacing: 0.02,
  );

  static const labelSm = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.04,
  );

  static const numericKeypad = TextStyle(
    fontFamily: _family,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 28 / 24,
    fontFeatures: _tnum,
  );

  /// Feed into ThemeData so Material components inherit the family.
  static TextTheme textTheme(Color primary, Color variant) => TextTheme(
    displayLarge: displayHero.copyWith(color: primary),
    displayMedium: displayHeroMobile.copyWith(color: primary),
    headlineLarge: headlineLg.copyWith(color: primary),
    headlineMedium: headlineSm.copyWith(color: primary),
    titleLarge: headlineSm.copyWith(color: primary),
    titleMedium: labelLg.copyWith(color: primary),
    bodyLarge: bodyLg.copyWith(color: primary),
    bodyMedium: bodyMd.copyWith(color: variant),
    bodySmall: bodySm.copyWith(color: variant),
    labelLarge: labelLg.copyWith(color: primary),
    labelMedium: labelMd.copyWith(color: variant),
    labelSmall: labelSm.copyWith(color: variant),
  );
}