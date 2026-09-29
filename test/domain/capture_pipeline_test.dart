// Issue #22: the capture pipeline as the notification listener uses it.
// Runs the real CaptureProcessor against real drift repositories on an
// in-memory database — the same wiring the background isolate builds —
// so testing.md's P-07/P-08 (dedupe) and US-10 (allow-list; non-allowed
// notifications are never stored) are exercised end to end without a
// device. Fake messages only.
//
// Needs code generation first: dart run build_runner build

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/db/app_database.dart';
import 'package:fuata/data/db/drift_repositories.dart';
import 'package:fuata/domain/logic/capture_pipeline.dart';
import 'package:fuata/domain/models/capture_source.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

void main() {
  const messages = 'com.example.messages';
  const bankApp = 'com.example.bankapp';
  const strangerApp = 'com.example.stranger';

  const withCode =
      'Confirmed. Ksh350.00 paid to JAVA HOUSE on 21/9/26 at 1:12 PM. '
      'Code QW12ABC3.';
  const withoutCode = 'Payment of Ksh350.00 to JAVA HOUSE';

  late AppDatabase db;
  late DriftTransactionRepository txs;
  late DriftCaptureRepository captures;
  late DriftCaptureSourceRepository sources;
  late CaptureProcessor processor;

  // A clock that ticks one second per call, so ids never collide and two
  // captures always land inside the 2-minute no-code dedupe window.
  var tick = DateTime(2026, 9, 29, 10, 0);
  DateTime clock() {
    tick = tick.add(const Duration(seconds: 1));
    return tick;
  }

  CaptureTemplate template(String id, String sample, List<(String, TemplateFieldType)> labels) {
    return CaptureTemplate.fromLabeledSample(
      id: id,
      unitId: 'u_mm',
      name: id,
      direction: TemplateDirection.spent,
      sampleText: sample,
      labels: [
        for (final (needle, type) in labels)
          LabeledSpan(
            start: sample.indexOf(needle),
            end: sample.indexOf(needle) + needle.length,
            type: type,
          ),
      ],
    );
  }

  Future<void> allow(String pkg, {bool enabled = true}) => sources.saveSource(
    CaptureSource(
      id: CaptureSource.idFor(pkg),
      packageName: pkg,
      displayName: pkg,
      enabled: enabled,
    ),
  );

  setUp(() async {
    tick = DateTime(2026, 9, 29, 10, 0);
    db = AppDatabase(NativeDatabase.memory());
    txs = DriftTransactionRepository(db);
    captures = DriftCaptureRepository(db);
    sources = DriftCaptureSourceRepository(db);
    final templates = DriftTemplateRepository(db);
    final settings = DriftSettingsRepository(db);

    await DriftUnitRepository(db).addUnit(
      MoneyUnit(
        id: 'u_mm',
        name: 'Mobile money',
        kind: UnitKind.mobileMoney,
        currencyCode: 'KES',
        iconEmoji: '📱',
        color: const Color(0xFF3D7FE0),
        openingBalanceMinor: 0,
        sortOrder: 0,
        createdAt: DateTime(2026, 9, 21),
      ),
    );
    await templates.saveTemplate(
      template('t_code', withCode, [
        ('Ksh350.00', TemplateFieldType.amount),
        ('JAVA HOUSE', TemplateFieldType.person),
        ('21/9/26 at 1:12 PM', TemplateFieldType.date),
        ('QW12ABC3', TemplateFieldType.code),
      ]),
    );
    await templates.saveTemplate(
      template('t_nocode', withoutCode, [
        ('Ksh350.00', TemplateFieldType.amount),
        ('JAVA HOUSE', TemplateFieldType.person),
      ]),
    );

    processor = CaptureProcessor(
      units: DriftUnitRepository(db),
      templates: templates,
      transactions: txs,
      captures: captures,
      sources: sources,
      settings: settings,
      now: clock,
    );
  });

  tearDown(() => db.close());

  group('US-10 allow-list: non-allowed notifications are never stored', () {
    test('an app that was never allowed creates nothing at all', () async {
      await allow(messages);

      final outcome = await processor.captureNotification(strangerApp, withCode);

      expect(outcome, isA<CaptureIgnored>());
      expect(await txs.watchTransactions().first, isEmpty);
      // Not even as an "unparsed" entry: no trace of the text.
      expect(await captures.watchUnparsed().first, isEmpty);
    });

    test('an unreadable message from a non-allowed app is not kept either', () async {
      await allow(messages);

      await processor.captureNotification(strangerApp, 'hello, no money here');

      expect(await captures.watchUnparsed().first, isEmpty);
    });

    test('an app switched off is treated like one never allowed', () async {
      await allow(messages, enabled: false);

      final outcome = await processor.captureNotification(messages, withCode);

      expect(outcome, isA<CaptureIgnored>());
      expect(await txs.watchTransactions().first, isEmpty);
    });

    test('an empty notification is ignored', () async {
      await allow(messages);
      expect(await processor.captureNotification(messages, '   '), isA<CaptureIgnored>());
    });
  });

  group('allowed notification -> pending transaction', () {
    test('matches a template and lands pending, sourced as a notification', () async {
      await allow(messages);

      final outcome = await processor.captureNotification(messages, withCode);

      expect(outcome, isA<Captured>());
      expect((outcome as Captured).autoAccepted, isFalse);
      final rows = await txs.watchTransactions().first;
      expect(rows, hasLength(1));
      expect(rows.single.source, TxSource.notification);
      expect(rows.single.status, TxStatus.pending);
      expect(rows.single.amountMinor, -35000);
      expect(rows.single.code, 'QW12ABC3');
      expect(rows.single.rawText, isNull); // ADR-009: raw text is not kept
    });

    test('auto-accept confirms it straight away', () async {
      await allow(messages);
      await DriftSettingsRepository(db).updateSettings(
        AppSettings.defaults.copyWith(autoAcceptCaptures: true),
      );

      final outcome = await processor.captureNotification(messages, withCode);

      expect((outcome as Captured).autoAccepted, isTrue);
      expect((await txs.watchTransactions().first).single.status, TxStatus.confirmed);
    });
  });

  group('dedupe', () {
    test('P-07: the same code arriving twice creates one row', () async {
      await allow(messages);

      final first = await processor.captureNotification(messages, withCode);
      final second = await processor.captureNotification(messages, withCode);

      expect(first, isA<Captured>());
      expect(second, isA<CaptureDuplicate>());
      expect(await txs.watchTransactions().first, hasLength(1));
    });

    test('P-08: SMS then push of one payment, no code, creates one row', () async {
      await allow(messages);
      await allow(bankApp);

      final sms = await processor.captureNotification(messages, withoutCode);
      final push = await processor.captureNotification(bankApp, withoutCode);

      expect(sms, isA<Captured>());
      expect(push, isA<CaptureDuplicate>());
      expect(await txs.watchTransactions().first, hasLength(1));
    });

    test('two notifications arriving together still create one row', () async {
      // The race the serial queue exists for: both would otherwise read
      // "nothing stored yet" before either writes.
      await allow(messages);
      await allow(bankApp);

      final outcomes = await Future.wait([
        processor.captureNotification(messages, withCode),
        processor.captureNotification(bankApp, withCode),
      ]);

      expect(outcomes.whereType<Captured>(), hasLength(1));
      expect(outcomes.whereType<CaptureDuplicate>(), hasLength(1));
      expect(await txs.watchTransactions().first, hasLength(1));
    });

    test('an unreadable message re-posted is one entry, not one per arrival', () async {
      await allow(messages);

      for (var i = 0; i < 3; i++) {
        expect(
          await processor.captureNotification(messages, 'Your OTP is 123456'),
          isA<CaptureUnparsed>(),
        );
      }

      final rows = await captures.watchUnparsed().first;
      expect(rows, hasLength(1));
      expect(rows.single.sourcePackage, messages);
      expect(rows.single.rawText, 'Your OTP is 123456');
    });

    test('the same unreadable text from a different app is kept separately', () async {
      await allow(messages);
      await allow(bankApp);

      await processor.captureNotification(messages, 'Your OTP is 123456');
      await processor.captureNotification(bankApp, 'Your OTP is 123456');

      expect(await captures.watchUnparsed().first, hasLength(2));
    });
  });
}
