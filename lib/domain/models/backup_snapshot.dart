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
import 'outing.dart';

/// A row of the `categories` table (issue #83). Was previously a raw
/// shape with no domain model — now that categories are user-editable,
/// the fields are the same ones the domain model carries.
class BackupCategory {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;
  final int sortOrder;
  final bool archived;

  const BackupCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    this.sortOrder = 0,
    this.archived = false,
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

  /// Outings (issue #30). No FKs to units — an outing's `unitIds` is a
  /// soft set, and a missing id at import just means that unit wasn't
  /// restored. The outing itself always imports.
  final List<Outing> outings;

  const BackupSnapshot({
    this.categories = const [],
    this.units = const [],
    this.captureSources = const [],
    this.templates = const [],
    this.transactions = const [],
    this.limits = const [],
    this.settings,
    this.outings = const [],
  });

  static const empty = BackupSnapshot();

  /// Number of money records (settings not counted).
  int get recordCount =>
      categories.length +
      units.length +
      captureSources.length +
      templates.length +
      transactions.length +
      limits.length +
      outings.length;

  bool get isEmpty => recordCount == 0;
}
