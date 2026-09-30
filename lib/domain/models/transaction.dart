enum TxType { spent, got, moved, adjustment }

enum TxSource { manual, shared, notification }

enum TxStatus { confirmed, pending }

/// A single ledger entry. amountMinor is the SIGNED effect on the unit's
/// balance (outflows negative) — see design.md ADR-004/ADR-005.
/// Transfers are two rows sharing transferGroupId; fees are a separate
/// `spent` row with parentId pointing at the transaction they belong to.
class MoneyTransaction {
  final String id;
  final String unitId;
  final TxType type;
  final int amountMinor;
  final String? counterparty;
  final String? categoryId;
  final String? note;
  final String? code;
  final DateTime occurredAt;
  final DateTime createdAt;
  final TxSource source;
  final TxStatus status;
  final String? transferGroupId;
  final String? parentId;
  final String? templateId;
  final int? balanceAfterMinor;
  final String? rawText; // null by default (privacy) — see ADR-009

  const MoneyTransaction({
    required this.id,
    required this.unitId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    required this.createdAt,
    this.counterparty,
    this.categoryId,
    this.note,
    this.code,
    this.source = TxSource.manual,
    this.status = TxStatus.confirmed,
    this.transferGroupId,
    this.parentId,
    this.templateId,
    this.balanceAfterMinor,
    this.rawText,
  });

  bool get isConfirmed => status == TxStatus.confirmed;
  bool get countsAsSpending => type == TxType.spent && isConfirmed;
  bool get countsAsIncome => type == TxType.got && isConfirmed;

  MoneyTransaction copyWith({TxStatus? status, String? rawText}) {
    return MoneyTransaction(
      id: id,
      unitId: unitId,
      type: type,
      amountMinor: amountMinor,
      counterparty: counterparty,
      categoryId: categoryId,
      note: note,
      code: code,
      occurredAt: occurredAt,
      createdAt: createdAt,
      source: source,
      status: status ?? this.status,
      transferGroupId: transferGroupId,
      parentId: parentId,
      templateId: templateId,
      balanceAfterMinor: balanceAfterMinor,
      rawText: rawText ?? this.rawText,
    );
  }
}
