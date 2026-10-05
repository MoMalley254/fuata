import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/capture_source.dart';
import '../../domain/models/limit_alert.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/template.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/unparsed_capture.dart';
import '../../domain/repositories/repositories.dart';
import '../constants/captures_constants.dart';

/// Sample data matching docs/ui-design-brief.md section 6, so screens
/// look real while the drift database (#13) isn't built yet.
class MockData {
  static final now = DateTime.now();

  static final units = <MoneyUnit>[
    MoneyUnit(
      id: 'u_cash',
      name: 'Cash',
      kind: UnitKind.cash,
      currencyCode: 'KES',
      iconEmoji: '💵',
      color: const Color(0xFF2E9E6B),
      openingBalanceMinor: 76000,
      sortOrder: 0,
      createdAt: now,
    ),
    MoneyUnit(
      id: 'u_mm',
      name: 'Mobile money',
      kind: UnitKind.mobileMoney,
      currencyCode: 'KES',
      iconEmoji: '📱',
      color: const Color(0xFF3D7FE0),
      openingBalanceMinor: 345000,
      sortOrder: 1,
      createdAt: now,
    ),
    MoneyUnit(
      id: 'u_bankx',
      name: 'Bank X',
      kind: UnitKind.bank,
      currencyCode: 'KES',
      iconEmoji: '🏦',
      color: const Color(0xFF8B5CF6),
      openingBalanceMinor: 1200000,
      sortOrder: 2,
      createdAt: now,
    ),
    MoneyUnit(
      id: 'u_cardc',
      name: 'Card C',
      kind: UnitKind.card,
      currencyCode: 'KES',
      iconEmoji: '💳',
      color: const Color(0xFFE8A317),
      openingBalanceMinor: 12000,
      sortOrder: 3,
      createdAt: now,
    ),
  ];

  static final transactions = <MoneyTransaction>[
    MoneyTransaction(
      id: 't1',
      unitId: 'u_mm',
      type: TxType.spent,
      amountMinor: -35000,
      counterparty: 'Java House',
      occurredAt: DateTime(now.year, now.month, now.day, 13, 12),
      createdAt: now,
      code: 'QW12ABC3',
      source: TxSource.notification,
    ),
    MoneyTransaction(
      id: 't2',
      unitId: 'u_cash',
      type: TxType.spent,
      amountMinor: -15000,
      counterparty: 'Matatu fare',
      occurredAt: DateTime(now.year, now.month, now.day, 8, 5),
      createdAt: now,
    ),
    MoneyTransaction(
      id: 't3',
      unitId: 'u_bankx',
      type: TxType.got,
      amountMinor: 500000,
      counterparty: 'Salary',
      occurredAt: now.subtract(const Duration(days: 1)),
      createdAt: now,
    ),
    MoneyTransaction(
      id: 't4a',
      unitId: 'u_bankx',
      type: TxType.moved,
      amountMinor: -200000,
      counterparty: 'To Cash',
      occurredAt: now.subtract(const Duration(days: 1)),
      createdAt: now,
      transferGroupId: 'g1',
    ),
    MoneyTransaction(
      id: 't4b',
      unitId: 'u_cash',
      type: TxType.moved,
      amountMinor: 200000,
      counterparty: 'From Bank X',
      occurredAt: now.subtract(const Duration(days: 1)),
      createdAt: now,
      transferGroupId: 'g1',
    ),
  ];

  static final limits = <LimitRule>[
    LimitRule(
      id: 'l_daily',
      scope: LimitScope.overall,
      period: LimitPeriod.day,
      amountMinor: 200000, // 2,000 KES
      currencyCode: 'KES',
    ),
    LimitRule(
      id: 'l_monthly',
      scope: LimitScope.overall,
      period: LimitPeriod.month,
      amountMinor: 4500000, // 45,000 KES
      currencyCode: 'KES',
    ),
  ];
}

/// A tiny in-memory reactive store: keeps a mutable list and a broadcast
/// stream that emits a fresh snapshot on every mutation. `watch()` yields
/// the current snapshot immediately, then every subsequent one.
///
/// This fixes a real bug: the previous mock repos used `async* { yield
/// ...; }`, which emits exactly ONCE and then the stream closes. Riverpod's
/// StreamProvider got that one snapshot and nothing ever told it a mutation
/// had happened, so Home never updated after adding a transaction (only
/// looked right after a full app restart, when the provider re-ran fresh).
class _Store<T> {
  _Store(List<T> initial) : _items = List<T>.from(initial);

  final List<T> _items;
  final _controller = StreamController<List<T>>.broadcast();

  List<T> get _snapshot => List<T>.unmodifiable(_items);

  List<T> get items => List<T>.unmodifiable(_items);

  Stream<List<T>> watch() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  void add(T item) {
    _items.add(item);
    _controller.add(_snapshot);
  }

  /// Updates the first item matching [test]. No-op if none match.
  void update(bool Function(T) test, T Function(T) updater) {
    final i = _items.indexWhere(test);
    if (i == -1) return;
    _items[i] = updater(_items[i]);
    _controller.add(_snapshot);
  }

  /// Updates the first item matching [test], or appends [item] if none do.
  void upsert(bool Function(T) test, T item) {
    final i = _items.indexWhere(test);
    if (i == -1) {
      _items.add(item);
    } else {
      _items[i] = item;
    }
    _controller.add(_snapshot);
  }

  void removeWhere(bool Function(T) test) {
    _items.removeWhere(test);
    _controller.add(_snapshot);
  }

  void dispose() => _controller.close();
}

class MockUnitRepository implements UnitRepository {
  final _store = _Store<MoneyUnit>(MockData.units);

  @override
  Stream<List<MoneyUnit>> watchUnits({bool includeArchived = false}) {
    return _store.watch().map((list) {
      return list.where((u) => includeArchived || !u.archived).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  @override
  Future<void> addUnit(MoneyUnit unit) async => _store.add(unit);

  @override
  Future<void> updateUnit(MoneyUnit unit) async =>
      _store.update((u) => u.id == unit.id, (_) => unit);

  @override
  Future<void> archiveUnit(String unitId) async =>
      _store.update((u) => u.id == unitId, (u) => u.copyWith(archived: true));
}

class MockTransactionRepository implements TransactionRepository {
  final _store = _Store<MoneyTransaction>(MockData.transactions);

  @override
  Stream<List<MoneyTransaction>> watchTransactions({String? unitId}) {
    return _store.watch().map((list) {
      return list.where((t) => unitId == null || t.unitId == unitId).toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    });
  }

  @override
  Future<void> addTransaction(MoneyTransaction transaction) async =>
      _store.add(transaction);

  @override
  Future<void> updateTransaction(MoneyTransaction transaction) async =>
      _store.update((t) => t.id == transaction.id, (_) => transaction);

  @override
  Future<void> confirmTransaction(String transactionId) async {
    _store.update(
          (t) => t.id == transactionId,
          (t) => t.copyWith(status: TxStatus.confirmed),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) async =>
      _store.removeWhere((t) => t.id == transactionId);
}

class MockLimitRepository implements LimitRepository {
  final _store = _Store<LimitRule>(MockData.limits);

  @override
  Stream<List<LimitRule>> watchLimits() => _store.watch();

  @override
  Future<void> setLimit(LimitRule limit) async =>
      _store.upsert((l) => l.id == limit.id, limit);

  @override
  Future<void> deleteLimit(String limitId) async =>
      _store.removeWhere((l) => l.id == limitId);
}

/// `_Store<T>` is built around lists, but reusing it here (with a
/// permanently one-item list) keeps this repo the same shape and the
/// same "broadcast on every mutation" behaviour as the other three,
/// rather than a bespoke ValueNotifier just for this one case.
/// In-memory alert log for widget tests/previews. Same contract as the
/// drift one: a key can be claimed once.
class MockAlertLogRepository implements AlertLogRepository {
  final _claimed = <AlertKey, DateTime>{};

  @override
  Future<Set<AlertKey>> firedKeys() async => _claimed.keys.toSet();

  @override
  Future<bool> claim(AlertKey key, DateTime at) async {
    if (_claimed.containsKey(key)) return false;
    _claimed[key] = at;
    return true;
  }

  @override
  Future<void> purgeBefore(DateTime cutoff) async =>
      _claimed.removeWhere((_, at) => at.isBefore(cutoff));
}

class MockSettingsRepository implements SettingsRepository {
  final _store = _Store<AppSettings>([AppSettings.defaults]);

  @override
  Stream<AppSettings> watchSettings() => _store.watch().map((list) => list.first);

  @override
  Future<void> updateSettings(AppSettings settings) async =>
      _store.update((_) => true, (_) => settings);
}

class MockTemplateRepository implements TemplateRepository {
  final _store = _Store<CaptureTemplate>([]);

  @override
  Stream<List<CaptureTemplate>> watchTemplates({String? unitId}) {
    return _store.watch().map(
          (list) => list.where((t) => unitId == null || t.unitId == unitId).toList(),
    );
  }

  @override
  Future<void> saveTemplate(CaptureTemplate template) async =>
      _store.upsert((t) => t.id == template.id, template);

  @override
  Future<void> deleteTemplate(String templateId) async =>
      _store.removeWhere((t) => t.id == templateId);
}

/// In-memory unparsed captures (#21) — same store semantics as the
/// others, including the 7-day auto-purge the drift repo enforces.
class MockCaptureRepository implements CaptureRepository {
  final _store = _Store<UnparsedCapture>([]);

  @override
  Stream<List<UnparsedCapture>> watchUnparsed() => _store.watch();

  @override
  Future<void> recordUnparsed({
    required String id,
    required String sourcePackage,
    required String rawText,
  }) async {
    _store.add(
      UnparsedCapture(
        id: id,
        receivedAt: DateTime.now().toUtc(),
        sourcePackage: sourcePackage,
        rawText: rawText,
      ),
    );
    final cutoff = DateTime.now().toUtc().subtract(unparsedCaptureRetention);
    _store.removeWhere((u) => u.receivedAt.isBefore(cutoff));

    // Cap by newest: keep the same 200-row ceiling the drift repo enforces.
    final sorted = [..._store.items]
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    if (sorted.length > unparsedCaptureCap) {
      final keep = sorted.take(unparsedCaptureCap).map((u) => u.id).toSet();
      _store.removeWhere((u) => !keep.contains(u.id));
    }
  }

  @override
  Future<void> deleteUnparsed(String captureId) async =>
      _store.removeWhere((u) => u.id == captureId);
}
/// In-memory allow-list (#22), same store semantics as the others.
class MockCaptureSourceRepository implements CaptureSourceRepository {
  final _store = _Store<CaptureSource>([]);

  @override
  Stream<List<CaptureSource>> watchSources() => _store.watch();

  @override
  Future<void> saveSource(CaptureSource source) async =>
      _store.upsert((s) => s.id == source.id, source);
}