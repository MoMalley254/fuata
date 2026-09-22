import 'package:flutter/material.dart';

import '../../domain/models/limit_rule.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../domain/repositories/repositories.dart';

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

class MockUnitRepository implements UnitRepository {
  final _units = List<MoneyUnit>.from(MockData.units);
  final _controller = Stream<List<MoneyUnit>>.empty();

  @override
  Stream<List<MoneyUnit>> watchUnits({bool includeArchived = false}) async* {
    yield _units.where((u) => includeArchived || !u.archived).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> addUnit(MoneyUnit unit) async => _units.add(unit);

  @override
  Future<void> updateUnit(MoneyUnit unit) async {
    final i = _units.indexWhere((u) => u.id == unit.id);
    if (i != -1) _units[i] = unit;
  }

  @override
  Future<void> archiveUnit(String unitId) async {
    final i = _units.indexWhere((u) => u.id == unitId);
    if (i != -1) _units[i] = _units[i].copyWith(archived: true);
  }
}

class MockTransactionRepository implements TransactionRepository {
  final _transactions = List<MoneyTransaction>.from(MockData.transactions);

  @override
  Stream<List<MoneyTransaction>> watchTransactions({String? unitId}) async* {
    yield _transactions.where((t) => unitId == null || t.unitId == unitId).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<void> addTransaction(MoneyTransaction transaction) async {
    _transactions.add(transaction);
  }

  @override
  Future<void> confirmTransaction(String transactionId) async {
    final i = _transactions.indexWhere((t) => t.id == transactionId);
    // Records are immutable; a real (drift) repo updates the row in place.
    // Mock keeps this a no-op placeholder for UI wiring purposes.
    assert(i != -1 || true);
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    _transactions.removeWhere((t) => t.id == transactionId);
  }
}

class MockLimitRepository implements LimitRepository {
  final _limits = List<LimitRule>.from(MockData.limits);

  @override
  Stream<List<LimitRule>> watchLimits() async* {
    yield _limits;
  }

  @override
  Future<void> setLimit(LimitRule limit) async {
    final i = _limits.indexWhere((l) => l.id == limit.id);
    if (i == -1) {
      _limits.add(limit);
    } else {
      _limits[i] = limit;
    }
  }
}