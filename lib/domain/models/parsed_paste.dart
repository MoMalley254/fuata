import 'package:fuata/domain/models/transaction.dart';

/// What was extracted from a pasted message.
class ParsedPaste {
  final String rawText;
  final int amountMinor;
  final TxType type;
  final String? counterparty;
  final DateTime? occurredAt;
  final String? code;
  final int? feeMinor;
  final int? balanceAfterMinor;
  final String unitId;
  final String currencyCode;
  const ParsedPaste({
    required this.rawText,
    required this.amountMinor,
    required this.type,
    required this.unitId,
    required this.currencyCode,
    this.counterparty,
    this.occurredAt,
    this.code,
    this.feeMinor,
    this.balanceAfterMinor,
  });
}
