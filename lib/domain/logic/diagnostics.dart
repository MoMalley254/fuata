// ---------------------------------------------------------------------------
// Opt-in redacted diagnostics (issue #37).
//
// Gathers a summary of the app's state for troubleshooting, explicitly
// excluding any personal, financial, or message text data. The user must
// explicitly tap to copy this to the clipboard.
// ---------------------------------------------------------------------------

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/diagnostics_data.dart';
import '../repositories/repositories.dart';

Future<DiagnosticsData> gatherDiagnostics({
  required UnitRepository units,
  required TransactionRepository transactions,
  required TemplateRepository templates,
  required OutingRepository outings,
  required CaptureSourceRepository sources,
  required CaptureRepository captures,
  required LimitRepository limits,
  required CategoryRepository categories,
  required SettingsRepository settings,
}) async {
  final unitList = await units.watchUnits().first;
  final txList = await transactions.watchTransactions().first;
  final templateList = await templates.watchTemplates().first;
  final outingList = await outings.watchOutings().first;
  final sourceList = await sources.watchSources().first;
  final unparsedList = await captures.watchUnparsed().first;
  final limitList = await limits.watchLimits().first;
  final categoryList = await categories.watchCategories().first;
  final currentSettings = await settings.watchSettings().first;

  final appVersion = await getAppVersion();

  return DiagnosticsData(
    appVersion: appVersion,
    unitCount: unitList.length,
    transactionCount: txList.length,
    templateCount: templateList.length,
    outingCount: outingList.length,
    allowedAppsCount: sourceList.where((s) => s.enabled).length,
    unparsedCapturesCount: unparsedList.length,
    activeLimitsCount: limitList.where((l) => l.enabled).length,
    categoriesCount: categoryList.length,
    currencyCode: currentSettings.currencyCode,
    themeMode: currentSettings.themeMode.name,
    detailLevel: currentSettings.detailLevel.name,
    homeHeadline: currentSettings.homeHeadline.name,
    bannerEnabled: currentSettings.bannerEnabled,
    bannerShowProgress: currentSettings.bannerShowProgress,
    bannerShowQuickAdd: currentSettings.bannerShowQuickAdd,
    widgetShowProgress: currentSettings.widgetShowProgress,
    widgetShowSplit: currentSettings.widgetShowSplit,
    widgetVariant: currentSettings.widgetVariant.name,
    appLockEnabled: currentSettings.appLockEnabled,
    autoAcceptCaptures: currentSettings.autoAcceptCaptures,
    amountsHidden: currentSettings.amountsHidden,
    amountsHiddenInRecents: currentSettings.amountsHiddenInRecents,
    redactedLockScreenBanner: currentSettings.redactedLockScreenBanner,
    summaryNotificationsEnabled: currentSettings.summaryNotificationsEnabled,
    scheduledExportEnabled: currentSettings.scheduledExportEnabled,
  );
}

Future<void> copyDiagnosticsToClipboard({
  required UnitRepository units,
  required TransactionRepository transactions,
  required TemplateRepository templates,
  required OutingRepository outings,
  required CaptureSourceRepository sources,
  required CaptureRepository captures,
  required LimitRepository limits,
  required CategoryRepository categories,
  required SettingsRepository settings,
  required String appVersion,
}) async {
  final data = await gatherDiagnostics(
    units: units,
    transactions: transactions,
    templates: templates,
    outings: outings,
    sources: sources,
    captures: captures,
    limits: limits,
    categories: categories,
    settings: settings,
  );
  await Clipboard.setData(ClipboardData(text: data.toString()));
}

Future<String> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
}
