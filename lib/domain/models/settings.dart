// ---------------------------------------------------------------------------
// Settings (design.md's `settings` key/value table: name, accent colour,
// detail level, Home headline and sections, banner options, theme).
//
// Like unit.dart, this brings in a `Color` — the same precedent already
// established there: the "pure Dart domain" rule is about not importing
// *widgets*, not about avoiding Flutter's colour/enum types.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Detail level applied to Activity and transaction detail
/// (ui-design-brief.md section 3, US-13). This is the single source of
/// truth for the three levels — previously duplicated as a private
/// `_DetailLevel` enum inside transaction_detail_sheet.dart.
enum DetailLevel { simple, balanced, detailed }

extension DetailLevelLabel on DetailLevel {
  String get label => switch (this) {
    DetailLevel.simple => 'Simple',
    DetailLevel.balanced => 'Balanced',
    DetailLevel.detailed => 'Detailed',
  };

  String get description => switch (this) {
    DetailLevel.simple => 'Amount, who, and a friendly time. Nothing else.',
    DetailLevel.balanced => 'Adds the money unit and category.',
    DetailLevel.detailed =>
    'Adds exact time, code, fee, note, source and balance after.',
  };
}

/// The big number on Home's hero card (ui-design-brief.md section 3).
enum HomeHeadline { leftToday, totalIHave, spentToday }

extension HomeHeadlineLabel on HomeHeadline {
  String get label => switch (this) {
    HomeHeadline.leftToday => 'Left Today',
    HomeHeadline.totalIHave => 'Total I have',
    HomeHeadline.spentToday => 'Spent Today',
  };
}

/// Which optional blocks Home shows, and in what order they're offered
/// here (design brief section 3: "Which sections Home shows").
enum HomeSection { units, lately, weekPeek }

extension HomeSectionsLabel on HomeSection {
  String get label => switch (this) {
    HomeSection.units => 'My Money',
    HomeSection.lately => 'Lately',
    HomeSection.weekPeek => 'Week Peek',
  };

  String get description => switch (this) {
    HomeSection.units => 'The scrolling row of units cards.',
    HomeSection.lately => 'Your most recent transactions.',
  // Not built yet (design.md open item) — the toggle exists so the
  // preference survives until the widget does.
    HomeSection.weekPeek => 'A tiny 7-day bar strip. Coming soon',
  };
}

///#17 The big number in the banner's collapsed line (ui-design-brief.md 7.9).
enum BannerHeadline { leftToday, spentToday, totalIHave }

extension BannerHeadlineLabel on BannerHeadline {
  String get label => switch (this) {
    BannerHeadline.leftToday => 'Left today',
    BannerHeadline.spentToday => 'Spent today',
    BannerHeadline.totalIHave => 'Total I have',
  };
}

/// Light / dark / follow system (design brief section 3). A dedicated
/// enum, rather than reusing Flutter's ThemeMode directly, keeps the
/// domain model independent of *which* widget toolkit reads it.
enum AppThemeMode { system, light, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
    AppThemeMode.system => 'Follow system',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };

  IconData get icon => switch (this) {
    AppThemeMode.system => Icons.brightness_auto_rounded,
    AppThemeMode.light => Icons.light_mode_rounded,
    AppThemeMode.dark => Icons.dark_mode_outlined,
  };

  ThemeMode get flutterThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// The accent swatches offered in Onboarding and Me (design brief:
/// "~8 warm/cool options, plus custom"). Named, not just a raw list, so
/// "custom" can still be recognised as "not one of these" elsewhere.
class AppAccents {
  AppAccents._();

  static const teal = Color(0xFF006762); // default
  static const coral = Color(0xFFE07A5F);
  static const purple = Color(0xFF7B5EA7);
  static const blue = Color(0xFF277DA1);
  static const green = Color(0xFF2E9E6B);
  static const amber = Color(0xFFE8A317);
  static const berry = Color(0xFFB3123F);
  static const slate = Color(0xFF3E4948);

  static const swatches = <Color>[
    teal,
    coral,
    purple,
    blue,
    green,
    amber,
    berry,
    slate,
  ];
}

/// Everything the person controls about how the app looks and behaves,
/// as opposed to *their money* (units/transactions/limits, which live in
/// their own repositories). One bundle, one repository, one provider —
/// same "fewer moving parts" reasoning as HomeState in app_providers.dart.
@immutable
class AppSettings {
  final String name;
  final Color accent;
  final AppThemeMode themeMode;
  final HomeHeadline homeHeadline;
  final Set<HomeSection> homeSections;
  final DetailLevel detailLevel;

  // Privacy toggles (requirements.md US-16, design brief 7.12). These are
  // *preferences* the person sets here; the two that need OS-level
  // enforcement (redacting the lock-screen banner, hiding amounts in
  // Android's Recents screen) are wired up on the platform side in a
  // later issue — this screen is where the person turns them on.
  final bool amountsHiddenInRecents;
  final bool redactedLockScreenBanner;

  // Review-inbox toggle (ui-design-brief.md 7.6's header setting,
  // US-11): when on, captures are inserted as confirmed and skip the
  // Looks-right step entirely. Off by default — caught money should be
  // eyeballed at least once.
  final bool autoAcceptCaptures;

  // Banner options (issue #17). Empty bannerUnitIds means "all units".
  final bool bannerEnabled;
  final BannerHeadline bannerHeadline;
  final Set<String> bannerUnitIds;
  final bool bannerShowProgress;
  final bool bannerShowQuickAdd;

  // Limit alerts (issue #63, US-06). Alert *levels* live on each LimitRule
  // (warnAt / dangerAt); these are the switches around them. Quiet hours
  // are minutes after local midnight and may wrap (22:00 -> 07:00).
  final bool alertsEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinute;
  final int quietEndMinute;

  const AppSettings({
    required this.name,
    required this.accent,
    required this.themeMode,
    required this.homeHeadline,
    required this.homeSections,
    required this.detailLevel,
    required this.amountsHiddenInRecents,
    required this.redactedLockScreenBanner,
    required this.autoAcceptCaptures,
    required this.bannerEnabled,
    required this.bannerHeadline,
    required this.bannerUnitIds,
    required this.bannerShowProgress,
    required this.bannerShowQuickAdd,
    this.alertsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartMinute = 22 * 60,
    this.quietEndMinute = 7 * 60,
  });

  static final defaults = AppSettings(
    name: 'Amina',
    accent: AppAccents.teal,
    themeMode: AppThemeMode.system,
    homeHeadline: HomeHeadline.leftToday,
    homeSections: {HomeSection.units, HomeSection.lately},
    detailLevel: DetailLevel.balanced,
    amountsHiddenInRecents: false,
    redactedLockScreenBanner: true,
    autoAcceptCaptures: false,
    bannerEnabled: false, // turned on by onboarding (#7) or this screen
    bannerHeadline: BannerHeadline.leftToday,
    bannerUnitIds: <String>{},
    bannerShowProgress: true,
    bannerShowQuickAdd: true,
    alertsEnabled: true,
    quietHoursEnabled: false,
    quietStartMinute: 22 * 60,
    quietEndMinute: 7 * 60,
  );

  AppSettings copyWith({
    String? name,
    Color? accent,
    AppThemeMode? themeMode,
    HomeHeadline? homeHeadline,
    Set<HomeSection>? homeSections,
    DetailLevel? detailLevel,
    bool? amountsHiddenInRecents,
    bool? redactedLockScreenBanner,
    bool? autoAcceptCaptures,
    bool? bannerEnabled,
    BannerHeadline? bannerHeadline,
    Set<String>? bannerUnitIds,
    bool? bannerShowProgress,
    bool? bannerShowQuickAdd,
    bool? alertsEnabled,
    bool? quietHoursEnabled,
    int? quietStartMinute,
    int? quietEndMinute,
  }) {
    return AppSettings(
      name: name ?? this.name,
      accent: accent ?? this.accent,
      themeMode: themeMode ?? this.themeMode,
      homeHeadline: homeHeadline ?? this.homeHeadline,
      homeSections: homeSections ?? this.homeSections,
      detailLevel: detailLevel ?? this.detailLevel,
      amountsHiddenInRecents:
      amountsHiddenInRecents ?? this.amountsHiddenInRecents,
      redactedLockScreenBanner:
      redactedLockScreenBanner ?? this.redactedLockScreenBanner,
      autoAcceptCaptures: autoAcceptCaptures ?? this.autoAcceptCaptures,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      bannerHeadline: bannerHeadline ?? this.bannerHeadline,
      bannerUnitIds: bannerUnitIds ?? this.bannerUnitIds,
      bannerShowProgress: bannerShowProgress ?? this.bannerShowProgress,
      bannerShowQuickAdd: bannerShowQuickAdd ?? this.bannerShowQuickAdd,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinute: quietStartMinute ?? this.quietStartMinute,
      quietEndMinute: quietEndMinute ?? this.quietEndMinute,
    );
  }
}