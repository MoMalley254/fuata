class DiagnosticsData {
  final String appVersion;
  final int unitCount;
  final int transactionCount;
  final int templateCount;
  final int outingCount;
  final int allowedAppsCount;
  final int unparsedCapturesCount;
  final int activeLimitsCount;
  final int categoriesCount;

  final String currencyCode;
  final String themeMode;
  final String detailLevel;
  final String homeHeadline;

  final bool bannerEnabled;
  final bool bannerShowProgress;
  final bool bannerShowQuickAdd;

  final bool widgetShowProgress;
  final bool widgetShowSplit;
  final String widgetVariant;

  final bool appLockEnabled;
  final bool autoAcceptCaptures;
  final bool amountsHidden;
  final bool amountsHiddenInRecents;
  final bool redactedLockScreenBanner;
  final bool summaryNotificationsEnabled;
  final bool scheduledExportEnabled;

  DiagnosticsData({
    required this.appVersion,
    required this.unitCount,
    required this.transactionCount,
    required this.templateCount,
    required this.outingCount,
    required this.allowedAppsCount,
    required this.unparsedCapturesCount,
    required this.activeLimitsCount,
    required this.categoriesCount,
    required this.currencyCode,
    required this.themeMode,
    required this.detailLevel,
    required this.homeHeadline,
    required this.bannerEnabled,
    required this.bannerShowProgress,
    required this.bannerShowQuickAdd,
    required this.widgetShowProgress,
    required this.widgetShowSplit,
    required this.widgetVariant,
    required this.appLockEnabled,
    required this.autoAcceptCaptures,
    required this.amountsHidden,
    required this.amountsHiddenInRecents,
    required this.redactedLockScreenBanner,
    required this.summaryNotificationsEnabled,
    required this.scheduledExportEnabled,
  });

  @override
  String toString() {
    return '=== FUATA DIAGNOSTICS REPORT ===\n'
        'App Version: $appVersion\n'
        '\n--- DATA COUNTS ---\n'
        'Units: $unitCount\n'
        'Transactions: $transactionCount\n'
        'Message Rules (Templates): $templateCount\n'
        'Outings: $outingCount\n'
        'Allowed Notification Apps: $allowedAppsCount\n'
        'Unparsed Captures (Review Inbox): $unparsedCapturesCount\n'
        'Active Limits: $activeLimitsCount\n'
        'Categories: $categoriesCount\n'
        '\n--- CORE SETTINGS ---\n'
        'Currency: $currencyCode\n'
        'Theme: $themeMode\n'
        'Detail Level: $detailLevel\n'
        'Home Headline: $homeHeadline\n'
        '\n--- BANNER & WIDGET ---\n'
        'Banner Enabled: $bannerEnabled\n'
        'Banner Progress Bar: $bannerShowProgress\n'
        'Banner Quick Add: $bannerShowQuickAdd\n'
        'Widget Progress Bar: $widgetShowProgress\n'
        'Widget Split Line: $widgetShowSplit\n'
        'Widget Layout Variant: $widgetVariant\n'
        '\n--- PRIVACY & SECURITY ---\n'
        'App Lock Enabled: $appLockEnabled\n'
        'Amounts Hidden in App: $amountsHidden\n'
        'Amounts Hidden in Recents: $amountsHiddenInRecents\n'
        'Lock Screen Banner Redacted: $redactedLockScreenBanner\n'
        '\n--- AUTOMATION ---\n'
        'Auto-Accept Captures: $autoAcceptCaptures\n'
        'Summary Notifications: $summaryNotificationsEnabled\n'
        'Scheduled Encrypted Export: $scheduledExportEnabled\n'
        '================================\n'
        'Note: This report contains ONLY counts and feature flags. '
        'No personal data, financial amounts, or message text is included.';
  }
}
