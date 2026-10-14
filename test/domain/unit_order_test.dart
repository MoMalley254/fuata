// Issue #117: the sortOrder values written when units are reordered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/domain/logic/unit_order.dart';
import 'package:fuata/domain/models/unit.dart';

MoneyUnit _unit(String id, int sortOrder, {bool archived = false}) => MoneyUnit(
  id: id,
  name: id,
  kind: UnitKind.cash,
  currencyCode: 'KES',
  iconEmoji: '💵',
  color: const Color(0xFF000000),
  openingBalanceMinor: 0,
  sortOrder: sortOrder,
  archived: archived,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('units trade the sort values they already hold', () {
    final units = [_unit('a', 100), _unit('b', 200), _unit('c', 300)];

    final next = unitSortOrdersFor(units, ['c', 'a', 'b']);

    expect(next, {'c': 100, 'a': 200, 'b': 300});
  });

  test('units that do not move are left out', () {
    final units = [_unit('a', 100), _unit('b', 200), _unit('c', 300)];

    final next = unitSortOrdersFor(units, ['a', 'c', 'b']);

    expect(next, {'c': 200, 'b': 300});
  });

  test('an archived unit keeps its place between the others', () {
    // 'x' was archived from between a and b; reordering the active two
    // must not move it, so restoring it still lands between them.
    final units = [_unit('a', 100), _unit('x', 150, archived: true), _unit('b', 200)];

    final next = unitSortOrdersFor(units, ['b', 'a']);

    expect(next, {'b': 100, 'a': 200});
    expect(next.containsKey('x'), isFalse);
  });

  test('tied sort values fall back to their position', () {
    final units = [_unit('a', 0), _unit('b', 0), _unit('c', 0)];

    final next = unitSortOrdersFor(units, ['c', 'a', 'b']);

    // 'c' is first so it gets 0, which it already had: left out.
    expect(next, {'a': 1, 'b': 2});
  });

  test('unknown and repeated ids are ignored', () {
    final units = [_unit('a', 1), _unit('b', 2)];

    final next = unitSortOrdersFor(units, ['b', 'nope', 'a', 'b']);

    expect(next, {'b': 1, 'a': 2});
  });
}
