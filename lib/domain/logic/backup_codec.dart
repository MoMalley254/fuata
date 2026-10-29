// ---------------------------------------------------------------------------
// The backup file format (issue #24, US-15).
//
//   {
//     "format": "fuata-backup",
//     "formatVersion": 1,
//     "exportedAt": "2026-09-30T09:12:00.000Z",
//     "includesRawText": false,
//     "data": { "units": [...], "transactions": [...], ... }
//   }
//
// Pure Dart. `encode` never fails; `decode` never throws — every problem
// in a file comes back as a readable message, and a file with *any* error
// is rejected whole (a half-read backup is worse than none: balances are
// derived from every transaction, so a silently dropped row is a silently
// wrong balance).
//
// Rules the format keeps:
//  - Enums are written as their `.name`, never an index (same reasoning as
//    data/db/mappers.dart: reordering a case must not reinterpret old files).
//  - Times are UTC ISO-8601 strings; money is integer minor units (ADR-003).
//  - `formatVersion` only ever goes up. A newer file is refused with a
//    message asking the person to update, rather than half-understood.
//  - Unknown extra keys are ignored, so a later Fuata can add fields
//    without breaking an older reader of the same formatVersion.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:ui' show Color;

import '../models/backup_snapshot.dart';
import '../models/capture_source.dart';
import '../models/limit_rule.dart';
import '../models/outing.dart';
import '../models/settings.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/unit.dart';

/// What [BackupCodec.decode] found. Either [snapshot] is set and [errors]
/// is empty, or [errors] explains why the file was refused.
class BackupDecodeResult {
  final BackupSnapshot? snapshot;
  final List<String> errors;

  /// Things that were fixed up or ignored without rejecting the file
  /// (e.g. a limit whose id had to be normalised).
  final List<String> warnings;

  /// How many further errors were found but not listed.
  final int moreErrors;

  final DateTime? exportedAt;
  final bool includesRawText;

  const BackupDecodeResult({
    required this.snapshot,
    required this.errors,
    this.warnings = const [],
    this.moreErrors = 0,
    this.exportedAt,
    this.includesRawText = false,
  });

  factory BackupDecodeResult.failed(String message) =>
      BackupDecodeResult(snapshot: null, errors: [message]);

  bool get ok => snapshot != null && errors.isEmpty;
}

class BackupCodec {
  BackupCodec._();

  static const formatName = 'fuata-backup';
  static const currentVersion = 1;

  static const _maxListedErrors = 40;
  static const _maxListedWarnings = 40;

  // ---------------------------------------------------------------- encode

  /// Serialises [snapshot]. Original message text on transactions is left
  /// out unless [includeRawText] is true — it is opt-in even when it was
  /// stored (ADR-009), and a backup file is easier to share by accident
  /// than a database.
  static String encode(
    BackupSnapshot snapshot, {
    required DateTime exportedAt,
    bool includeRawText = false,
  }) {
    final doc = <String, dynamic>{
      'format': formatName,
      'formatVersion': currentVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'includesRawText': includeRawText,
      'data': <String, dynamic>{
        'categories': [for (final c in snapshot.categories) categoryToJson(c)],
        'units': [for (final u in snapshot.units) unitToJson(u)],
        'captureSources': [
          for (final s in snapshot.captureSources) captureSourceToJson(s),
        ],
        'templates': [for (final t in snapshot.templates) t.toJson()],
        'transactions': [
          for (final t in snapshot.transactions)
            transactionToJson(t, includeRawText: includeRawText),
        ],
        'limits': [for (final l in snapshot.limits) limitToJson(l)],
        if (snapshot.settings != null)
          'settings': settingsToJson(snapshot.settings!),
        'outings': [for (final o in snapshot.outings) outingToJson(o)],
      },
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static Map<String, dynamic> categoryToJson(BackupCategory c) => {
    'id': c.id,
    'name': c.name,
    'emoji': c.emoji,
    'color': c.colorValue,
    'sortOrder': c.sortOrder,
    'archived': c.archived,
  };

  static Map<String, dynamic> unitToJson(MoneyUnit u) => {
    'id': u.id,
    'name': u.name,
    'kind': u.kind.name,
    'currency': u.currencyCode,
    'icon': u.iconEmoji,
    'color': u.color.toARGB32(),
    'openingBalanceMinor': u.openingBalanceMinor,
    'sortOrder': u.sortOrder,
    'archived': u.archived,
    'archivedAt': _iso(u.archivedAt),
    'lastVerifiedAt': _iso(u.lastVerifiedAt),
    'createdAt': _iso(u.createdAt),
  };

  static Map<String, dynamic> captureSourceToJson(CaptureSource s) => {
    'id': s.id,
    'packageName': s.packageName,
    'displayName': s.displayName,
    'enabled': s.enabled,
  };

  static Map<String, dynamic> transactionToJson(
    MoneyTransaction t, {
    bool includeRawText = false,
  }) => {
    'id': t.id,
    'unitId': t.unitId,
    'type': t.type.name,
    'amountMinor': t.amountMinor,
    'counterparty': t.counterparty,
    'categoryId': t.categoryId,
    'note': t.note,
    'code': t.code,
    'occurredAt': _iso(t.occurredAt),
    'createdAt': _iso(t.createdAt),
    'source': t.source.name,
    'status': t.status.name,
    'transferGroupId': t.transferGroupId,
    'parentId': t.parentId,
    'templateId': t.templateId,
    'balanceAfterMinor': t.balanceAfterMinor,
    if (includeRawText && t.rawText != null) 'rawText': t.rawText,
  };

  static Map<String, dynamic> limitToJson(LimitRule l) => {
    'id': l.id,
    'scope': l.scope.name,
    'unitId': l.unitId,
    'period': l.period.name,
    'amountMinor': l.amountMinor,
    'currency': l.currencyCode,
    'warnAt': l.warnAt,
    'dangerAt': l.dangerAt,
    'enabled': l.enabled,
  };

  static Map<String, dynamic> settingsToJson(AppSettings s) => {
    'name': s.name,
    'accent': s.accent.toARGB32(),
    'themeMode': s.themeMode.name,
    'homeHeadline': s.homeHeadline.name,
    'homeSections': (s.homeSections.map((e) => e.name).toList()..sort()),
    'detailLevel': s.detailLevel.name,
    'amountsHiddenInRecents': s.amountsHiddenInRecents,
    'redactedLockScreenBanner': s.redactedLockScreenBanner,
    'autoAcceptCaptures': s.autoAcceptCaptures,
    'bannerEnabled': s.bannerEnabled,
    'bannerHeadline': s.bannerHeadline.name,
    'bannerUnitIds': (s.bannerUnitIds.toList()..sort()),
    'bannerUnitsMode': s.bannerUnitsMode.name,
    'bannerShowProgress': s.bannerShowProgress,
    'bannerShowQuickAdd': s.bannerShowQuickAdd,
    'summaryNotificationsEnabled': s.summaryNotificationsEnabled,
    'summaryDailyEnabled': s.summaryDailyEnabled,
    'summaryDailyMinute': s.summaryDailyMinute,
    'summaryWeeklyEnabled': s.summaryWeeklyEnabled,
    'summaryWeeklyWeekday': s.summaryWeeklyWeekday,
    'summaryWeeklyMinute': s.summaryWeeklyMinute,
    'summaryMonthlyEnabled': s.summaryMonthlyEnabled,
    'summaryMonthlyDay': s.summaryMonthlyDay,
    'summaryMonthlyMinute': s.summaryMonthlyMinute,
    'alertsEnabled': s.alertsEnabled,
    'quietHoursEnabled': s.quietHoursEnabled,
    'quietStartMinute': s.quietStartMinute,
    'quietEndMinute': s.quietEndMinute,
    'amountsHidden': s.amountsHidden,
    'widgetUnitsMode': s.widgetUnitsMode.name,
    'widgetUnitIds': (s.widgetUnitIds.toList()..sort()),
    'widgetHeadline': s.widgetHeadline.name,
    'widgetShowProgress': s.widgetShowProgress,
    'widgetShowSplit': s.widgetShowSplit,
    'widgetVariant': s.widgetVariant.name,
    'currencyCode': s.currencyCode,
    'scheduledExportEnabled': s.scheduledExportEnabled,
    'scheduledExportFrequency': s.scheduledExportFrequency.name,
    'scheduledExportMinute': s.scheduledExportMinute,
    'scheduledExportWeekday': s.scheduledExportWeekday,
    'scheduledExportIncludeRawText': s.scheduledExportIncludeRawText,
  };

  static Map<String, dynamic> outingToJson(Outing o) => {
    'id': o.id,
    'name': o.name,
    'amountMinor': o.amountMinor,
    'currency': o.currencyCode,
    'startAt': _iso(o.startAt),
    'endAt': _iso(o.endAt),
    'unitIds': (o.unitIds.toList()..sort()),
    'bannerEnabled': o.bannerEnabled,
    'enabled': o.enabled,
    'createdAt': _iso(o.createdAt),
  };

  // ---------------------------------------------------------------- decode

  static BackupDecodeResult decode(String text) {
    Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return BackupDecodeResult.failed(
        "This file isn't readable JSON. It may be cut off, or it isn't a "
        'Fuata backup.',
      );
    }
    if (root is! Map<String, dynamic> || root['format'] != formatName) {
      return BackupDecodeResult.failed(
        "This doesn't look like a Fuata backup file.",
      );
    }

    final version = root['formatVersion'];
    if (version is! int || version < 1) {
      return BackupDecodeResult.failed(
        "This backup has no valid version number, so it can't be trusted.",
      );
    }
    if (version > currentVersion) {
      return BackupDecodeResult.failed(
        'This backup was made by a newer version of Fuata (file format '
        '$version). Update Fuata, then try again.',
      );
    }

    final data = root['data'];
    if (data is! Map<String, dynamic>) {
      return BackupDecodeResult.failed('This backup has no data section.');
    }

    final ctx = _Ctx();

    final categories = _table<BackupCategory>(
      data,
      'categories',
      ctx,
      (r) => BackupCategory(
        id: r.nonEmpty('id'),
        name: r.nonEmpty('name'),
        emoji: r.str('emoji'),
        colorValue: r.colorInt('color'),
        // Files from before #83 have neither. Defaults match the columns'
        // own defaults, so an old file imports without a warning.
        sortOrder: r.integer('sortOrder', orElse: 0),
        archived: r.boolean('archived', orElse: false),
      ),
      (c) => c.id,
    );

    final units = _table<MoneyUnit>(
      data,
      'units',
      ctx,
      (r) => MoneyUnit(
        id: r.nonEmpty('id'),
        name: r.nonEmpty('name'),
        kind: r.oneOf('kind', UnitKind.values),
        currencyCode: r.nonEmpty('currency'),
        iconEmoji: r.str('icon'),
        color: Color(r.colorInt('color')),
        openingBalanceMinor: r.integer('openingBalanceMinor', orElse: 0),
        sortOrder: r.integer('sortOrder', orElse: 0),
        archived: r.boolean('archived', orElse: false),
        // `dateOrNull` returns null both when the key is absent (a backup
        // made before #80) and when it is present-but-null (a unit that
        // isn't archived). The screen treats both the same way.
        archivedAt: r.dateOrNull('archivedAt'),
        lastVerifiedAt: r.dateOrNull('lastVerifiedAt'),
        createdAt: r.date('createdAt'),
      ),
      (u) => u.id,
    );

    final sources = _table<CaptureSource>(data, 'captureSources', ctx, (r) {
      final pkg = r.nonEmpty('packageName');
      final given = r.nonEmpty('id');
      // One package is one row, by construction (CaptureSource.idFor).
      final id = CaptureSource.idFor(pkg);
      if (pkg.isNotEmpty && given != id) {
        ctx.warn('${r.path}: id tidied to match its app "$pkg".');
      }
      return CaptureSource(
        id: id,
        packageName: pkg,
        displayName: r.str('displayName'),
        enabled: r.boolean('enabled', orElse: true),
      );
    }, (s) => s.id);

    final templates = _table<CaptureTemplate>(
      data,
      'templates',
      ctx,
      (r) => _template(r, ctx),
      (t) => t.id,
    );

    final transactions = _table<MoneyTransaction>(
      data,
      'transactions',
      ctx,
      (r) => MoneyTransaction(
        id: r.nonEmpty('id'),
        unitId: r.nonEmpty('unitId'),
        type: r.oneOf('type', TxType.values),
        amountMinor: r.integer('amountMinor'),
        counterparty: r.strOrNull('counterparty'),
        categoryId: r.strOrNull('categoryId'),
        note: r.strOrNull('note'),
        code: r.strOrNull('code'),
        occurredAt: r.date('occurredAt'),
        createdAt: r.date('createdAt'),
        source: r.oneOf('source', TxSource.values, orElse: TxSource.manual),
        status: r.oneOf('status', TxStatus.values, orElse: TxStatus.confirmed),
        transferGroupId: r.strOrNull('transferGroupId'),
        parentId: r.strOrNull('parentId'),
        templateId: r.strOrNull('templateId'),
        balanceAfterMinor: r.integerOrNull('balanceAfterMinor'),
        rawText: r.strOrNull('rawText'),
      ),
      (t) => t.id,
    );

    final limits = _table<LimitRule>(
      data,
      'limits',
      ctx,
      (r) => _limit(r, ctx),
      (l) => l.id,
    );

    final outings = _table<Outing>(
      data,
      'outings',
      ctx,
      (r) => Outing(
        id: r.nonEmpty('id'),
        name: r.nonEmpty('name'),
        amountMinor: r.integer('amountMinor'),
        currencyCode: r.nonEmpty('currency'),
        startAt: r.dateLocal('startAt'),
        endAt: r.dateLocal('endAt'),
        unitIds: r.strList('unitIds').toSet(),
        bannerEnabled: r.boolean('bannerEnabled', orElse: true),
        enabled: r.boolean('enabled', orElse: true),
        createdAt: r.dateLocal('createdAt'),
      ),
      (o) => o.id,
    );

    AppSettings? settings;
    final rawSettings = data['settings'];
    if (rawSettings != null) {
      if (rawSettings is Map<String, dynamic>) {
        settings = _settings(rawSettings, ctx);
      } else {
        ctx.error('settings: expected an object.');
      }
    }

    final exportedAt = root['exportedAt'] is String
        ? DateTime.tryParse(root['exportedAt'] as String)
        : null;

    if (ctx.errors.isNotEmpty) {
      return BackupDecodeResult(
        snapshot: null,
        errors: ctx.errors,
        warnings: ctx.warnings,
        moreErrors: ctx.droppedErrors,
        exportedAt: exportedAt,
      );
    }

    return BackupDecodeResult(
      snapshot: BackupSnapshot(
        categories: categories,
        units: units,
        captureSources: sources,
        templates: templates,
        transactions: transactions,
        limits: limits,
        settings: settings,
        outings: outings,
      ),
      errors: const [],
      warnings: ctx.warnings,
      exportedAt: exportedAt,
      includesRawText: root['includesRawText'] == true,
    );
  }

  // -------------------------------------------------------- record readers

  static CaptureTemplate _template(_Rec r, _Ctx ctx) {
    final fieldMap = <String, TemplateFieldType>{};

    final rawMap = r.map['fieldMap'];
    if (rawMap is Map<String, dynamic>) {
      rawMap.forEach((group, type) {
        final match = TemplateFieldType.values
            .where((v) => v.name == type)
            .firstOrNull;
        if (match == null) {
          ctx.error('${r.path}.fieldMap.$group: unknown field type.');
        } else {
          fieldMap[group] = match;
        }
      });
    } else {
      ctx.error('${r.path}.fieldMap: expected an object.');
    }

    // #56: custom-field names. Must come AFTER fieldMap is built, so the
    // "is this group a custom field?" check has something to check against.
    final customFieldNames = <String, String>{};
    final rawCustomNames = r.map['customFieldNames'];
    if (rawCustomNames is Map<String, dynamic>) {
      rawCustomNames.forEach((group, name) {
        if (name is! String || name.trim().isEmpty) {
          ctx.error('${r.path}.customFieldNames.$group: expected a name.');
        } else if (fieldMap[group] != TemplateFieldType.custom) {
          ctx.error('${r.path}.customFieldNames.$group: not a custom field.');
        } else {
          customFieldNames[group] = name.trim();
        }
      });
    } else if (rawCustomNames != null) {
      ctx.error('${r.path}.customFieldNames: expected an object.');
    }
    for (final e in fieldMap.entries) {
      if (e.value == TemplateFieldType.custom &&
          !customFieldNames.containsKey(e.key)) {
        ctx.error('${r.path}: custom field "${e.key}" has no name.');
      }
    }

    final pattern = r.str('pattern');
    try {
      RegExp(pattern, dotAll: true);
    } on FormatException {
      ctx.error('${r.path}.pattern: not a valid message pattern.');
    }
    for (final group in fieldMap.keys) {
      if (!pattern.contains('(?<$group>')) {
        ctx.warn('${r.path}: field "$group" is not in its pattern.');
      }
    }

    return CaptureTemplate(
      id: r.nonEmpty('id'),
      unitId: r.nonEmpty('unitId'),
      captureSourceId: r.strOrNull('captureSourceId'),
      name: r.str('name'),
      direction: r.oneOf('direction', TemplateDirection.values),
      pattern: pattern,
      fieldMap: fieldMap,
      sampleText: r.str('sampleText'),
      version: r.integer('version', orElse: 1),
      enabled: r.boolean('enabled', orElse: true),
      customFieldNames: customFieldNames,
    );
  }

  static LimitRule _limit(_Rec r, _Ctx ctx) {
    final scope = r.oneOf('scope', LimitScope.values);
    final period = r.oneOf('period', LimitPeriod.values);
    var unitId = r.strOrNull('unitId');

    if (scope == LimitScope.unit && (unitId == null || unitId.isEmpty)) {
      ctx.error('${r.path}.unitId: a per-unit limit needs a unit.');
    }
    if (scope == LimitScope.overall && unitId != null) {
      ctx.warn('${r.path}: an overall limit has no unit; ignoring it.');
      unitId = null;
    }

    final amount = r.integer('amountMinor');
    if (amount < 0) {
      ctx.error('${r.path}.amountMinor: a limit cannot be negative.');
    }
    final warnAt = r.number('warnAt', orElse: 0.7);
    final dangerAt = r.number('dangerAt', orElse: 0.9);
    if (!(warnAt > 0 && warnAt <= dangerAt && dangerAt <= 1)) {
      ctx.error(
        '${r.path}: alert levels must satisfy 0 < warn <= danger <= 1.',
      );
    }

    // One row per (scope, unit, period), by construction (LimitRule.idFor):
    // the app edits a limit in place by id, so a file with a differently
    // named id would otherwise create a second limit for the same slot.
    final given = r.nonEmpty('id');
    final id = LimitRule.idFor(scope, period, unitId);
    if (given.isNotEmpty && given != id) {
      ctx.warn('${r.path}: id tidied to match its scope and period.');
    }

    return LimitRule(
      id: id,
      scope: scope,
      unitId: unitId,
      period: period,
      amountMinor: amount,
      currencyCode: r.nonEmpty('currency'),
      warnAt: warnAt,
      dangerAt: dangerAt,
      enabled: r.boolean('enabled', orElse: true),
    );
  }

  /// Settings are preferences, so this reader is forgiving: anything
  /// missing or unrecognised keeps its default (with a warning) instead
  /// of rejecting an otherwise good backup.
  static AppSettings _settings(Map<String, dynamic> m, _Ctx ctx) {
    final d = AppSettings.defaults;

    T pick<T extends Enum>(String key, List<T> values, T fallback) {
      final raw = m[key];
      if (raw == null) return fallback;
      final match = values.where((v) => v.name == raw).firstOrNull;
      if (match == null) {
        ctx.warn('settings.$key: unknown value "$raw"; kept the default.');
        return fallback;
      }
      return match;
    }

    bool flag(String key, bool fallback) {
      final raw = m[key];
      if (raw is bool) return raw;
      if (raw != null) ctx.warn('settings.$key: expected true/false.');
      return fallback;
    }

    int minute(String key, int fallback) {
      final raw = m[key];
      if (raw is int && raw >= 0 && raw < 24 * 60) return raw;
      if (raw != null) ctx.warn('settings.$key: not a valid time.');
      return fallback;
    }

    List<String> names(String key) {
      final raw = m[key];
      if (raw is List) {
        return [
          for (final e in raw)
            if (e is String) e,
        ];
      }
      return const [];
    }

    final accentRaw = m['accent'];
    final accent = accentRaw is int && accentRaw >= 0 && accentRaw <= 0xFFFFFFFF
        ? Color(accentRaw)
        : d.accent;

    final sections = <HomeSection>{
      for (final n in names('homeSections'))
        ...HomeSection.values.where((v) => v.name == n),
    };

    final rawName = m['name'];

    final currencyRaw = m['currencyCode'];
    final currencyCode = currencyRaw is String && currencyRaw.trim().isNotEmpty
        ? currencyRaw.trim()
        : d.currencyCode;

    return AppSettings(
      name: rawName is String && rawName.trim().isNotEmpty ? rawName : d.name,
      accent: accent,
      themeMode: pick('themeMode', AppThemeMode.values, d.themeMode),
      homeHeadline: pick('homeHeadline', HomeHeadline.values, d.homeHeadline),
      homeSections: m.containsKey('homeSections') ? sections : d.homeSections,
      detailLevel: pick('detailLevel', DetailLevel.values, d.detailLevel),
      amountsHiddenInRecents: flag(
        'amountsHiddenInRecents',
        d.amountsHiddenInRecents,
      ),
      redactedLockScreenBanner: flag(
        'redactedLockScreenBanner',
        d.redactedLockScreenBanner,
      ),
      autoAcceptCaptures: flag('autoAcceptCaptures', d.autoAcceptCaptures),
      bannerEnabled: flag('bannerEnabled', d.bannerEnabled),
      bannerHeadline: pick(
        'bannerHeadline',
        BannerHeadline.values,
        d.bannerHeadline,
      ),
      bannerUnitIds: names('bannerUnitIds').toSet(),
      bannerUnitsMode: m['bannerUnitsMode'] == null
          ? (names('bannerUnitIds').isNotEmpty
                ? BannerUnitsMode.selected
                : d.bannerUnitsMode)
          : pick('bannerUnitsMode', BannerUnitsMode.values, d.bannerUnitsMode),
      bannerShowProgress: flag('bannerShowProgress', d.bannerShowProgress),
      bannerShowQuickAdd: flag('bannerShowQuickAdd', d.bannerShowQuickAdd),
      summaryNotificationsEnabled: flag(
        'summaryNotificationsEnabled',
        d.summaryNotificationsEnabled,
      ),
      summaryDailyEnabled: flag('summaryDailyEnabled', d.summaryDailyEnabled),
      summaryDailyMinute: minute('summaryDailyMinute', d.summaryDailyMinute),
      summaryWeeklyEnabled: flag(
        'summaryWeeklyEnabled',
        d.summaryWeeklyEnabled,
      ),
      summaryWeeklyWeekday:
          m['summaryWeeklyWeekday'] is int &&
              (m['summaryWeeklyWeekday'] as int >= 1) &&
              (m['summaryWeeklyWeekday'] as int <= 7)
          ? m['summaryWeeklyWeekday'] as int
          : d.summaryWeeklyWeekday,
      summaryWeeklyMinute: minute('summaryWeeklyMinute', d.summaryWeeklyMinute),
      summaryMonthlyEnabled: flag(
        'summaryMonthlyEnabled',
        d.summaryMonthlyEnabled,
      ),
      summaryMonthlyDay:
          m['summaryMonthlyDay'] is int &&
              (m['summaryMonthlyDay'] as int >= 1) &&
              (m['summaryMonthlyDay'] as int <= 31)
          ? m['summaryMonthlyDay'] as int
          : d.summaryMonthlyDay,
      summaryMonthlyMinute: minute(
        'summaryMonthlyMinute',
        d.summaryMonthlyMinute,
      ),

      alertsEnabled: flag('alertsEnabled', d.alertsEnabled),
      quietHoursEnabled: flag('quietHoursEnabled', d.quietHoursEnabled),
      quietStartMinute: minute('quietStartMinute', d.quietStartMinute),
      quietEndMinute: minute('quietEndMinute', d.quietEndMinute),
      // A backup only exists because the app was set up; restoring one
      // must never send the person back through onboarding (#7).
      onboardingComplete: true,
      amountsHidden: flag('amountsHidden', d.amountsHidden),
      widgetUnitsMode: pick(
        'widgetUnitsMode',
        BannerUnitsMode.values,
        d.widgetUnitsMode,
      ),
      widgetUnitIds: names('widgetUnitIds').toSet(),
      widgetHeadline: pick(
        'widgetHeadline',
        BannerHeadline.values,
        d.widgetHeadline,
      ),
      widgetShowProgress: flag('widgetShowProgress', d.widgetShowProgress),
      widgetShowSplit: flag('widgetShowSplit', d.widgetShowSplit),
      widgetVariant: pick(
        'widgetVariant',
        WidgetVariant.values,
        d.widgetVariant,
      ),
      currencyCode: currencyCode,
      scheduledExportEnabled: flag(
        'scheduledExportEnabled',
        d.scheduledExportEnabled,
      ),
      scheduledExportFrequency: pick(
        'scheduledExportFrequency',
        ScheduledExportFrequency.values,
        d.scheduledExportFrequency,
      ),
      scheduledExportMinute: minute(
        'scheduledExportMinute',
        d.scheduledExportMinute,
      ),
      scheduledExportWeekday:
          m['scheduledExportWeekday'] is int &&
              (m['scheduledExportWeekday'] as int >= 1) &&
              (m['scheduledExportWeekday'] as int <= 7)
          ? m['scheduledExportWeekday'] as int
          : d.scheduledExportWeekday,
      scheduledExportIncludeRawText: flag(
        'scheduledExportIncludeRawText',
        d.scheduledExportIncludeRawText,
      ),
    );
  }

  /// Reads one named list from `data`. A missing key is an empty table
  /// (an older or trimmed file is fine); a present-but-wrong-shaped one is
  /// an error. Duplicate ids inside a table are an error too — the later
  /// row would silently replace the earlier one on import.
  static List<T> _table<T>(
    Map<String, dynamic> data,
    String key,
    _Ctx ctx,
    T Function(_Rec r) build,
    String Function(T) idOf,
  ) {
    final raw = data[key];
    if (raw == null) return <T>[];
    if (raw is! List) {
      ctx.error('$key: expected a list.');
      return <T>[];
    }
    final out = <T>[];
    final seen = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) {
        ctx.error('$key[$i]: expected an object.');
        continue;
      }
      final built = build(_Rec(item, '$key[$i]', ctx));
      final id = idOf(built);
      if (id.isNotEmpty && !seen.add(id)) {
        ctx.error('$key[$i]: the id "$id" appears more than once.');
      }
      out.add(built);
    }
    return out;
  }
}

class _Ctx {
  final errors = <String>[];
  final warnings = <String>[];
  int droppedErrors = 0;

  void error(String message) {
    if (errors.length < BackupCodec._maxListedErrors) {
      errors.add(message);
    } else {
      droppedErrors++;
    }
  }

  void warn(String message) {
    if (warnings.length < BackupCodec._maxListedWarnings) {
      warnings.add(message);
    }
  }
}

/// Typed, error-collecting access to one JSON object. Every getter records
/// a problem and returns a harmless placeholder rather than throwing, so
/// one pass reports everything wrong with a file, not just the first thing.
class _Rec {
  _Rec(this.map, this.path, this.ctx);

  final Map<String, dynamic> map;
  final String path;
  final _Ctx ctx;

  void _bad(String key, String expected) =>
      ctx.error('$path.$key: expected $expected.');

  String str(String key) {
    final v = map[key];
    if (v is String) return v;
    _bad(key, 'text');
    return '';
  }

  String nonEmpty(String key) {
    final v = str(key);
    if (v.trim().isEmpty && map[key] is String) {
      ctx.error('$path.$key: must not be empty.');
    }
    return v;
  }

  String? strOrNull(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is String) return v;
    _bad(key, 'text or null');
    return null;
  }

  int integer(String key, {int? orElse}) {
    final v = map[key];
    if (v is int) return v;
    if (v == null && orElse != null) return orElse;
    _bad(key, 'a whole number');
    return orElse ?? 0;
  }

  int? integerOrNull(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is int) return v;
    _bad(key, 'a whole number or null');
    return null;
  }

  /// 32-bit ARGB, as written by `Color.toARGB32()`.
  int colorInt(String key) {
    final v = map[key];
    if (v is int && v >= 0 && v <= 0xFFFFFFFF) return v;
    _bad(key, 'a colour value');
    return 0;
  }

  double number(String key, {double? orElse}) {
    final v = map[key];
    if (v is num) return v.toDouble();
    if (v == null && orElse != null) return orElse;
    _bad(key, 'a number');
    return orElse ?? 0;
  }

  bool boolean(String key, {bool? orElse}) {
    final v = map[key];
    if (v is bool) return v;
    if (v == null && orElse != null) return orElse;
    _bad(key, 'true or false');
    return orElse ?? false;
  }

  DateTime date(String key) {
    final v = map[key];
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    _bad(key, 'a date and time');
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  DateTime? dateOrNull(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    _bad(key, 'a date and time or null');
    return null;
  }

  T oneOf<T extends Enum>(String key, List<T> values, {T? orElse}) {
    final v = map[key];
    if (v == null && orElse != null) return orElse;
    final match = values.where((e) => e.name == v).firstOrNull;
    if (match != null) return match;
    ctx.error('$path.$key: unknown value "$v".');
    return orElse ?? values.first;
  }

  List<String> strList(String key) {
    final v = map[key];
    if (v == null) return const [];
    if (v is List) {
      return [
        for (final e in v)
          if (e is String) e,
      ];
    }
    _bad(key, 'a list of strings');
    return const [];
  }

  DateTime dateLocal(String key) => date(key).toLocal();
}
