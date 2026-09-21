import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceTertiary,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.statusSafe,
    required this.statusSafeContainer,
    required this.statusSafeBorder,
    required this.statusWarning,
    required this.statusWarningContainer,
    required this.statusWarningBorder,
    required this.statusDanger,
    required this.statusDangerContainer,
    required this.statusDangerBorder,
    required this.statusOverdraft,
    required this.statusOverdraftContainer,
    required this.unitCash,
    required this.unitMobileMoney,
    required this.unitBank,
    required this.unitCard,
    required this.shadow,
    required this.scrim,
});

  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color onSurfaceTertiary;
  final Color outline;
  final Color outlineVariant;

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;

  final Color statusSafe;
  final Color statusSafeContainer;
  final Color statusSafeBorder;
  final Color statusWarning;
  final Color statusWarningContainer;
  final Color statusWarningBorder;
  final Color statusDanger;
  final Color statusDangerContainer;
  final Color statusDangerBorder;
  final Color statusOverdraft;
  final Color statusOverdraftContainer;

  final Color unitCash;
  final Color unitMobileMoney;
  final Color unitBank;
  final Color unitCard;

  final Color shadow;
  final Color scrim;

  //Light
  static const light = AppColors(
    background: Color(0xFFFBF8F3),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF6F2EA),
    surfaceContainerHigh: Color(0xFFEDE7DC),
    surfaceContainerHighest: Color(0xFFE3E2DF),
    onSurface: Color(0xFF1B1C1A),
    onSurfaceVariant: Color(0xFF3E4948),
    onSurfaceTertiary: Color(0xFF6E7978),
    outline: Color(0xFF6E7978),
    outlineVariant: Color(0xFFBDC9C7),
    primary: Color(0xFF006762),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF00837C),
    onPrimaryContainer: Color(0xFFF3FFFD),
    secondary: Color(0xFF9A442D),
    onSecondary: Color(0xFFFFFFFF),
    statusSafe: Color(0xFF2E9E6B),
    statusSafeContainer: Color(0xFFE7F6EE),
    statusSafeBorder: Color(0x4D2E9E6B),
    statusWarning: Color(0xFFE8A317),
    statusWarningContainer: Color(0xFFFDF5E3),
    statusWarningBorder: Color(0x4DE8A317),
    statusDanger: Color(0xFFE5533D),
    statusDangerContainer: Color(0xFFFDECE9),
    statusDangerBorder: Color(0x4DE5533D),
    statusOverdraft: Color(0xFFB3123F),
    statusOverdraftContainer: Color(0xFFF9E6EB),
    unitCash: Color(0xFF2E9E6B),
    unitMobileMoney: Color(0xFF277DA1),
    unitBank: Color(0xFF7B5EA7),
    unitCard: Color(0xFFE07A5F),
    shadow: Color(0x0A2C2D2B),
    scrim: Color(0x4D000000),
  );

  //Dark
  static const dark = AppColors(
    background: Color(0xFF14161A),
    surface: Color(0xFF1F2329),
    surfaceContainer: Color(0xFF282C34),
    surfaceContainerHigh: Color(0xFF323741),
    surfaceContainerHighest: Color(0xFF3C414A),
    onSurface: Color(0xFFF1F3F7),
    onSurfaceVariant: Color(0xFF9DA6B5),
    onSurfaceTertiary: Color(0xFF5F6877),
    outline: Color(0xFF859490),
    outlineVariant: Color(0xFF3C4A46),
    primary: Color(0xFF57F1DB),
    onPrimary: Color(0xFF003731),
    primaryContainer: Color(0xFF2DD4BF),
    onPrimaryContainer: Color(0xFF00574D),
    secondary: Color(0xFFFFB3B0),
    onSecondary: Color(0xFF670211),
    statusSafe: Color(0xFF34D399),
    statusSafeContainer: Color(0x2634D399), // 15% teal-emerald
    statusSafeBorder: Color(0x4D34D399),   // 30%
    statusWarning: Color(0xFFFBBF24),
    statusWarningContainer: Color(0x26FBBF24),
    statusWarningBorder: Color(0x4DFBBF24),
    statusDanger: Color(0xFFF87171),
    statusDangerContainer: Color(0x26F87171),
    statusDangerBorder: Color(0x4DF87171),
    statusOverdraft: Color(0xFFFB7185),
    statusOverdraftContainer: Color(0x33E11D48),
    unitCash: Color(0xFF34D399),
    unitMobileMoney: Color(0xFF5EB6E0),
    unitBank: Color(0xFFA78BFA),
    unitCard: Color(0xFFFFB4A1),
    shadow: Color(0x73000000),
    scrim: Color(0x66000000),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? surfaceContainerHighest,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onSurfaceTertiary,
    Color? outline,
    Color? outlineVariant,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? statusSafe,
    Color? statusSafeContainer,
    Color? statusSafeBorder,
    Color? statusWarning,
    Color? statusWarningContainer,
    Color? statusWarningBorder,
    Color? statusDanger,
    Color? statusDangerContainer,
    Color? statusDangerBorder,
    Color? statusOverdraft,
    Color? statusOverdraftContainer,
    Color? unitCash,
    Color? unitMobileMoney,
    Color? unitBank,
    Color? unitCard,
    Color? shadow,
    Color? scrim,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceContainer: surfaceContainer ?? this.surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest ?? this.surfaceContainerHighest,
    onSurface: onSurface ?? this.onSurface,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    onSurfaceTertiary: onSurfaceTertiary ?? this.onSurfaceTertiary,
    outline: outline ?? this.outline,
    outlineVariant: outlineVariant ?? this.outlineVariant,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    statusSafe: statusSafe ?? this.statusSafe,
    statusSafeContainer: statusSafeContainer ?? this.statusSafeContainer,
    statusSafeBorder: statusSafeBorder ?? this.statusSafeBorder,
    statusWarning: statusWarning ?? this.statusWarning,
    statusWarningContainer: statusWarningContainer ?? this.statusWarningContainer,
    statusWarningBorder: statusWarningBorder ?? this.statusWarningBorder,
    statusDanger: statusDanger ?? this.statusDanger,
    statusDangerContainer: statusDangerContainer ?? this.statusDangerContainer,
    statusDangerBorder: statusDangerBorder ?? this.statusDangerBorder,
    statusOverdraft: statusOverdraft ?? this.statusOverdraft,
    statusOverdraftContainer: statusOverdraftContainer ?? this.statusOverdraftContainer,
    unitCash: unitCash ?? this.unitCash,
    unitMobileMoney: unitMobileMoney ?? this.unitMobileMoney,
    unitBank: unitBank ?? this.unitBank,
    unitCard: unitCard ?? this.unitCard,
    shadow: shadow ?? this.shadow,
    scrim: scrim ?? this.scrim,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceContainer: c(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: c(surfaceContainerHigh, other.surfaceContainerHigh),
      surfaceContainerHighest: c(surfaceContainerHighest, other.surfaceContainerHighest),
      onSurface: c(onSurface, other.onSurface),
      onSurfaceVariant: c(onSurfaceVariant, other.onSurfaceVariant),
      onSurfaceTertiary: c(onSurfaceTertiary, other.onSurfaceTertiary),
      outline: c(outline, other.outline),
      outlineVariant: c(outlineVariant, other.outlineVariant),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryContainer: c(primaryContainer, other.primaryContainer),
      onPrimaryContainer: c(onPrimaryContainer, other.onPrimaryContainer),
      secondary: c(secondary, other.secondary),
      onSecondary: c(onSecondary, other.onSecondary),
      statusSafe: c(statusSafe, other.statusSafe),
      statusSafeContainer: c(statusSafeContainer, other.statusSafeContainer),
      statusSafeBorder: c(statusSafeBorder, other.statusSafeBorder),
      statusWarning: c(statusWarning, other.statusWarning),
      statusWarningContainer: c(statusWarningContainer, other.statusWarningContainer),
      statusWarningBorder: c(statusWarningBorder, other.statusWarningBorder),
      statusDanger: c(statusDanger, other.statusDanger),
      statusDangerContainer: c(statusDangerContainer, other.statusDangerContainer),
      statusDangerBorder: c(statusDangerBorder, other.statusDangerBorder),
      statusOverdraft: c(statusOverdraft, other.statusOverdraft),
      statusOverdraftContainer: c(statusOverdraftContainer, other.statusOverdraftContainer),
      unitCash: c(unitCash, other.unitCash),
      unitMobileMoney: c(unitMobileMoney, other.unitMobileMoney),
      unitBank: c(unitBank, other.unitBank),
      unitCard: c(unitCard, other.unitCard),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
    );
  }
}

/// Convenience extension so widgets can call `context.colors.statusSafe`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}