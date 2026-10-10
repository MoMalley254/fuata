// Shared fixtures for the #24 backup tests (not a test file itself).

import 'package:flutter/material.dart';
import 'package:fuata/domain/models/backup_snapshot.dart';
import 'package:fuata/domain/models/capture_source.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

final exportedAt = DateTime.utc(2026, 9, 30, 9, 12);

MoneyUnit unit(
    String id, {
      String name = 'Cash',
      int sortOrder = 0,
      int opening = 0,
    }) =>
    MoneyUnit(
      id: id,
      name: name,
      kind: UnitKind.cash,
      currencyCode: 'KES',
      iconEmoji: '💵',
      color: const Color(0xFF2E9E6B),
      openingBalanceMinor: opening,
      sortOrder: sortOrder,
      createdAt: DateTime.utc(2026, 9, 1),
    );

MoneyTransaction tx(
    String id, {
      String unitId = 'u1',
      int amount = -35000,
      String? who = 'Naivas',
      String? raw,
      int minute = 0,
    }) =>
    MoneyTransaction(
      id: id,
      unitId: unitId,
      type: amount < 0 ? TxType.spent : TxType.got,
      amountMinor: amount,
      counterparty: who,
      occurredAt: DateTime.utc(2026, 9, 20, 8, minute),
      createdAt: DateTime.utc(2026, 9, 20, 8, minute),
      rawText: raw,
    );

CaptureSource source() => CaptureSource(
  id: CaptureSource.idFor('com.example.messages'),
  packageName: 'com.example.messages',
  displayName: 'Messages',
);

CaptureTemplate template({String unitId = 'u1'}) =>
    CaptureTemplate.fromLabeledSample(
      id: 't1',
      unitId: unitId,
      captureSourceId: CaptureSource.idFor('com.example.messages'),
      name: 'paid',
      direction: TemplateDirection.spent,
      sampleText: 'Paid Ksh350.00',
      labels: const [
        LabeledSpan(start: 5, end: 14, type: TemplateFieldType.amount),
      ],
    );

LimitRule overallDayLimit({int amount = 100000}) => LimitRule(
  id: LimitRule.idFor(LimitScope.overall, LimitPeriod.day),
  scope: LimitScope.overall,
  period: LimitPeriod.day,
  amountMinor: amount,
  currencyCode: 'KES',
);

LimitRule unitWeekLimit(String unitId) => LimitRule(
  id: LimitRule.idFor(LimitScope.unit, LimitPeriod.week, unitId),
  scope: LimitScope.unit,
  unitId: unitId,
  period: LimitPeriod.week,
  amountMinor: 500000,
  currencyCode: 'KES',
  warnAt: 0.6,
  dangerAt: 0.85,
);

AppSettings customSettings() => AppSettings.defaults.copyWith(
  name: 'Wanjiru',
  accent: AppAccents.coral,
  themeMode: AppThemeMode.dark,
  homeSections: {HomeSection.units},
  bannerEnabled: true,
  bannerUnitIds: {'u1'},
  quietHoursEnabled: true,
);

/// A snapshot exercising every table.
BackupSnapshot fullSnapshot({bool withSettings = true}) => BackupSnapshot(
  categories: const [
    BackupCategory(
      id: 'c1',
      name: 'Food',
      emoji: '🍲',
      colorValue: 0xFFE07A5F,
      sortOrder: 0,
      archived: false,
    ),
  ],
  units: [unit('u1'), unit('u2', name: 'M-Pesa', sortOrder: 1)],
  captureSources: [source()],
  templates: [template()],
  transactions: [
    tx('t1', raw: 'secret message', minute: 1),
    tx('t2', amount: 120000, who: 'Employer', minute: 2),
  ],
  limits: [overallDayLimit(), unitWeekLimit('u2')],
  settings: withSettings ? customSettings() : null,
);