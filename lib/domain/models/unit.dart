import 'package:flutter/material.dart';

enum UnitKind { cash, mobileMoney, bank, card, other }

/// A pot of money the user has defined themselves: cash, mobile money,
/// a bank account, a card, or anything else, with their own name,
/// icon and colour (see design.md UNIT table; ADR-003 for currency).
class MoneyUnit {
  final String id;
  final String name;
  final UnitKind kind;
  final String currencyCode;
  final String iconEmoji; // v0.1: emoji only; photo/icon-pack deferred
  final Color color;
  final int openingBalanceMinor;
  final int sortOrder;
  final bool archived;
  final DateTime? lastVerifiedAt;
  final DateTime createdAt;

  const MoneyUnit({
    required this.id,
    required this.name,
    required this.kind,
    required this.currencyCode,
    required this.iconEmoji,
    required this.color,
    required this.openingBalanceMinor,
    required this.sortOrder,
    required this.createdAt,
    this.archived = false,
    this.lastVerifiedAt,
  });

  MoneyUnit copyWith({
    String? name,
    String? iconEmoji,
    Color? color,
    int? sortOrder,
    bool? archived,
    DateTime? lastVerifiedAt,
  }) {
    return MoneyUnit(
      id: id,
      name: name ?? this.name,
      kind: kind,
      currencyCode: currencyCode,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      color: color ?? this.color,
      openingBalanceMinor: openingBalanceMinor,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      archived: archived ?? this.archived,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
    );
  }
}