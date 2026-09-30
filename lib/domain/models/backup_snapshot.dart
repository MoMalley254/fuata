// ---------------------------------------------------------------------------
// Everything a backup file carries, as plain domain objects (issue #24).
//
// Pure Dart, no I/O. The codec (logic/backup_codec.dart) turns one of these
// into JSON and back; the planner (logic/backup_import.dart) compares one
// read from a file with one read from the database; the repository
// (data/db/backup_repository.dart) reads and writes them.
//
// What is deliberately NOT in here:
//  - Unparsed captures: raw message text kept for 7 days by design (US-11),
//    never worth carrying to another phone.
//  - Alert firings: derived state. Importing limits on a new phone should
//    not silence alerts for a period that phone never showed.
//  - Balances: always computed from the opening balance plus transactions
//    (ADR-004), so there is nothing to store.
// ---------------------------------------------------------------------------

import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/template.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/domain/models/unit.dart';

import 'capture_source.dart';
import 'limit_rule.dart';

/// A row of the `categories` table. The table exists (transactions can
/// point at it) but no domain model or repository does yet — Me ->
/// Categories is "coming soon" — so backups carry the raw shape. Nothing
/// is lost, and a future categories screen picks the rows up as they are.
class BackupCategory {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;

  const BackupCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
  });
}

class BackupSnapshot {
  final List<BackupCategory> categories;
  final List<MoneyUnit> units;
  final List<CaptureSource> captureSources;
  final List<CaptureTemplate> templates;
  final List<MoneyTransaction> transactions;
  final List<LimitRule> limits;

  /// Null when the file has no settings section (or the caller left them
  /// out). Settings are preferences, not money, so they are handled
  /// separately from the records above on import.
  final AppSettings? settings;

  const BackupSnapshot({
    this.categories = const [],
    this.units = const [],
    this.captureSources = const [],
    this.templates = const [],
    this.transactions = const [],
    this.limits = const [],
    this.settings,
  });

  static const empty = BackupSnapshot();

  /// Number of money records (settings not counted).
  int get recordCount =>
      categories.length +
      units.length +
      captureSources.length +
      templates.length +
      transactions.length +
      limits.length;

  bool get isEmpty => recordCount == 0;
}
