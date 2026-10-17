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
    HomeSection.weekPeek => 'A tiny 7-day bar strip, tap for the week',
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

/// Which units appear in the banner's expanded body (issue #86, finding
/// F2). Replaces the old "empty bannerUnitIds means all" trick with an
/// explicit choice, so "all", "these two" and "none" are three distinct
/// states instead of two states plus an implicit default.
enum BannerUnitsMode { all, selected, none }

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

  /// True when [c] is one of the presets. Used by the profile and
  /// welcome screens to decide whether the custom swatch should show
  /// itself as the current selection (issue #118).
  ///
  /// Compares ARGB ints rather than `Color` instances, matching how
  /// every other colour comparison in the app is done — `Color` has an
  /// extended-gamut representation that `==` is sensitive to, and these
  /// are all plain sRGB so the integer is the reliable form.
  static bool isPreset(Color c) =>
      swatches.any((s) => s.toARGB32() == c.toARGB32());
}

/// How much the home-screen widget shows (issue #113). [auto] is the
/// default: the launcher reports the cell size and the widget picks
/// compact or rich itself (see FuataWidgetProvider.shouldShowSplit).
/// [compact] and [rich] force one, for a person who wants the number
/// alone on a wide cell, or the split on a narrow one.
enum WidgetVariant { auto, compact, rich }

extension WidgetVariantLabel on WidgetVariant {
  String get label => switch (this) {
    WidgetVariant.auto => 'Automatic',
    WidgetVariant.compact => 'Compact',
    WidgetVariant.rich => 'Rich',
  };

  String get description => switch (this) {
    WidgetVariant.auto =>
    'Compact on a small cell, with the unit split on a wider one.',
    WidgetVariant.compact => 'Just the headline number and progress bar.',
    WidgetVariant.rich => 'The number, progress bar and a unit split line.',
  };
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

  /// Issue #31: scheduled daily / weekly / monthly summary notifications.
  /// The master switch gates all three; each period has its own toggle
  /// and its own time (minutes after local midnight).
  final bool summaryNotificationsEnabled;
  final bool summaryDailyEnabled;
  final int summaryDailyMinute;
  final bool summaryWeeklyEnabled;
  /// 1 = Monday … 7 = Sunday (matches Dart's `DateTime.weekday`).
  final int summaryWeeklyWeekday;
  final int summaryWeeklyMinute;
  final bool summaryMonthlyEnabled;
  /// 1–28, so every month has one. Days 29–31 are deliberately excluded:
  /// a monthly summary that silently skips February would be worse than
  /// one that fires slightly early.
  final int summaryMonthlyDay;
  final int summaryMonthlyMinute;

  // Limit alerts (issue #63, US-06). Alert *levels* live on each LimitRule
  // (warnAt / dangerAt); these are the switches around them. Quiet hours
  // are minutes after local midnight and may wrap (22:00 -> 07:00).
  final bool alertsEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinute;
  final int quietEndMinute;

  // Onboarding (issue #7). False on a fresh install, so the first launch
  // shows the onboarding flow; flipped to true when it is finished or
  // skipped, and never shown again. Installs that predate #7 have settings
  // rows but no such key, and are read as true (see DriftSettingsRepository).
  final bool onboardingComplete;

  /// Whether every amount the app shows is replaced by a mask (issue #81,
  /// finding F7). Set by the eye on Today, My money and a unit page, and
  /// by the toggle on Privacy & data.
  ///
  /// Deliberately separate from [amountsHiddenInRecents] (which blanks the
  /// app switcher) and [redactedLockScreenBanner] (which redacts the posted
  /// notification): three different places money could be seen, three
  /// different switches.
  final bool amountsHidden;

  /// Whether the banner's expanded body lists every active unit, only
  /// [bannerUnitIds], or none at all. The old "empty means all" reading
  /// of [bannerUnitIds] is gone — an empty set in `selected` mode now
  /// means an empty selection, which reads the same as `none`.
  final BannerUnitsMode bannerUnitsMode;

  final bool appLockEnabled;
  final bool appLockBiometric;  // false = device credential only

  // Home-screen widget (issue #113). The widget and the banner are the
  // same "at-a-glance number" in two places, so the option vocabulary is
  // shared (BannerUnitsMode / BannerHeadline) — but the two have
  // independent lives: someone who muted the banner can still want a
  // home-screen glance, and vice versa.
  final BannerUnitsMode widgetUnitsMode;
  final Set<String> widgetUnitIds;
  final BannerHeadline widgetHeadline;
  final bool widgetShowProgress;

  /// The unit split line under the number ("Cash 760 · Mobile 3,450").
  /// Only drawn on the rich layout or a wide auto cell — see [widgetVariant].
  final bool widgetShowSplit;
  final WidgetVariant widgetVariant;

  /// The single currency the app shows (issue #114). Any ISO 4217 code is
  /// valid — display is entirely intl's job. `MoneyUnit.currencyCode` is
  /// kept on the schema and the backup format but is vestigial: units are
  /// created with this code, and changing this value updates every unit.
  final String currencyCode;

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

    this.summaryNotificationsEnabled = false,
    this.summaryDailyEnabled = false,
    this.summaryDailyMinute = 20 * 60,          // 20:00
    this.summaryWeeklyEnabled = false,
    this.summaryWeeklyWeekday = DateTime.sunday, // 7
    this.summaryWeeklyMinute = 20 * 60,
    this.summaryMonthlyEnabled = false,
    this.summaryMonthlyDay = 1,
    this.summaryMonthlyMinute = 20 * 60,

    this.alertsEnabled = true,
    this.quietHoursEnabled = false,
    this.quietStartMinute = 22 * 60,
    this.quietEndMinute = 7 * 60,
    this.onboardingComplete = false,
    this.amountsHidden = false,
    this.bannerUnitsMode = BannerUnitsMode.all,
    this.appLockBiometric = false,
    this.appLockEnabled = false,
    this.widgetUnitsMode = BannerUnitsMode.all,
    this.widgetUnitIds = const <String>{},
    this.widgetHeadline = BannerHeadline.leftToday,
    this.widgetShowProgress = true,
    this.widgetShowSplit = true,
    this.widgetVariant = WidgetVariant.auto,
    this.currencyCode = 'KES'
  });

  static final defaults = AppSettings(
    name: 'Martha',
    accent: AppAccents.teal,
    themeMode: AppThemeMode.system,
    homeHeadline: HomeHeadline.leftToday,
    homeSections: {HomeSection.units, HomeSection.lately, HomeSection.weekPeek},
    detailLevel: DetailLevel.balanced,
    amountsHiddenInRecents: false,
    redactedLockScreenBanner: true,
    autoAcceptCaptures: false,
    bannerEnabled: false, // turned on by onboarding (#7) or the Banner screen
    bannerHeadline: BannerHeadline.leftToday,
    bannerUnitIds: <String>{},
    bannerUnitsMode: BannerUnitsMode.all,
    bannerShowProgress: true,
    bannerShowQuickAdd: true,
    summaryNotificationsEnabled: false,
    summaryDailyEnabled: false,
    summaryDailyMinute: 20 * 60,          // 20:00
    summaryWeeklyEnabled: false,
    summaryWeeklyWeekday: DateTime.sunday, // 7
    summaryWeeklyMinute: 20 * 60,
    summaryMonthlyEnabled: false,
    summaryMonthlyDay: 1,
    summaryMonthlyMinute: 20 * 60,
    alertsEnabled: true,
    quietHoursEnabled: false,
    quietStartMinute: 22 * 60,
    quietEndMinute: 7 * 60,
    onboardingComplete: false,
    amountsHidden: false,
    appLockEnabled: false,
    appLockBiometric: false,
    widgetUnitsMode: BannerUnitsMode.all,
    widgetUnitIds: <String>{},
    widgetHeadline: BannerHeadline.leftToday,
    widgetShowProgress: true,
    widgetShowSplit: true,
    widgetVariant: WidgetVariant.auto,
    currencyCode: 'KES',
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
    BannerUnitsMode? bannerUnitsMode,
    bool? bannerShowProgress,
    bool? bannerShowQuickAdd,
    bool?  summaryNotificationsEnabled,
    bool?  summaryDailyEnabled,
    int ? summaryDailyMinute,
    bool?  summaryWeeklyEnabled,
    int ? summaryWeeklyWeekday,
    int ? summaryWeeklyMinute,
    bool?  summaryMonthlyEnabled,
    int ? summaryMonthlyDay,
    int ? summaryMonthlyMinute,
    bool? alertsEnabled,
    bool? quietHoursEnabled,
    int? quietStartMinute,
    int? quietEndMinute,
    bool? onboardingComplete,
    bool? amountsHidden,
    bool? appLockBiometric,
    bool? appLockEnabled,
    BannerUnitsMode? widgetUnitsMode,
    Set<String>? widgetUnitIds,
    BannerHeadline? widgetHeadline,
    bool? widgetShowProgress,
    bool? widgetShowSplit,
    WidgetVariant? widgetVariant,
    String? currencyCode,
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
      bannerUnitsMode: bannerUnitsMode ?? this.bannerUnitsMode,
      bannerShowProgress: bannerShowProgress ?? this.bannerShowProgress,
      bannerShowQuickAdd: bannerShowQuickAdd ?? this.bannerShowQuickAdd,
      summaryNotificationsEnabled: summaryNotificationsEnabled ?? this.summaryNotificationsEnabled,
      summaryDailyEnabled: summaryDailyEnabled ?? this.summaryDailyEnabled,
      summaryDailyMinute: summaryDailyMinute ?? this.summaryDailyMinute,
      summaryWeeklyEnabled: summaryWeeklyEnabled ?? this.summaryWeeklyEnabled,
      summaryWeeklyWeekday: summaryWeeklyWeekday ?? this.summaryWeeklyWeekday,
      summaryWeeklyMinute: summaryWeeklyMinute ?? this.summaryWeeklyMinute,
      summaryMonthlyEnabled: summaryMonthlyEnabled ?? this.summaryMonthlyEnabled,
      summaryMonthlyDay: summaryMonthlyDay ?? this.summaryMonthlyDay,
      summaryMonthlyMinute: summaryMonthlyMinute ?? this.summaryMonthlyMinute,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinute: quietStartMinute ?? this.quietStartMinute,
      quietEndMinute: quietEndMinute ?? this.quietEndMinute,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      amountsHidden: amountsHidden ?? this.amountsHidden,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockBiometric: appLockBiometric ?? this.appLockBiometric,
      widgetUnitsMode: widgetUnitsMode ?? this.widgetUnitsMode,
      widgetUnitIds: widgetUnitIds ?? this.widgetUnitIds,
      widgetHeadline: widgetHeadline ?? this.widgetHeadline,
      widgetShowProgress: widgetShowProgress ?? this.widgetShowProgress,
      widgetShowSplit: widgetShowSplit ?? this.widgetShowSplit,
      widgetVariant: widgetVariant ?? this.widgetVariant,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
