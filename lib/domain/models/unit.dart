import 'package:flutter/material.dart';

enum UnitKind { cash, mobileMoney, bank, card, other }

/// A pot of money the user has defined themselves: cash, mobile money,
/// a bank account, a card, or anything else, with their own name,
/// icon and colour (see design.md UNIT table; ADR-003 for currency).
class MoneyUnit {
  final String id;
  final String name;
  final UnitKind kind;

  /// Vestigial as of #114: the app has a single currency
  /// (`AppSettings.currencyCode`), and every unit is created with it and
  /// kept in step with `UnitRepository.updateAllCurrencies`. Kept on the
  /// model, the schema and the backup format so nothing churns; a screen
  /// may still read it (it drives per-unit `Money` formatting), but it is
  /// always equal to the app-wide setting.
  final String currencyCode;

  final String iconEmoji; // v0.1: emoji only; photo/icon-pack deferred
  final Color color;
  final int openingBalanceMinor;
  final int sortOrder;
  final bool archived;

  /// When the unit was archived; null when it isn't, or when the install
  /// predates the field. Presentation-only — the domain never reasons
  /// about "how long ago".
  final DateTime? archivedAt;
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
    this.archivedAt,
    this.lastVerifiedAt,
  });

  /// Sentinel for the two nullable-with-meaning fields: passing `null`
  /// explicitly means "clear it", omitting the argument means "leave it".
  /// Same trick freezed generates; without it there is no way to tell
  /// `copyWith(archivedAt: null)` from a call that didn't mention it.
  static const _unset = Object();

  MoneyUnit copyWith({
    String? name,
    String? iconEmoji,
    Color? color,
    int? sortOrder,
    bool? archived,
    Object? archivedAt = _unset,
    Object? lastVerifiedAt = _unset,
    String? currencyCode,
  }) {
    return MoneyUnit(
      id: id,
      name: name ?? this.name,
      kind: kind,
      currencyCode: currencyCode ?? this.currencyCode,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      color: color ?? this.color,
      openingBalanceMinor: openingBalanceMinor,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      archived: archived ?? this.archived,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      lastVerifiedAt: identical(lastVerifiedAt, _unset)
          ? this.lastVerifiedAt
          : lastVerifiedAt as DateTime?,
    );
  }
}

/// The name to show a unit by once it's been put away: "Cash (archived)".
/// Only the row labels in history use this — the unit page has its own,
/// longer notice. See Activity and the transaction detail sheet.
extension MoneyUnitDisplay on MoneyUnit {
  String get displayName => archived ? '$name (archived)' : name;
}