// ---------------------------------------------------------------------------
// Deciding what an import would do, before it does anything (issue #24,
// US-15: "import is validated and never overwrites silently").
//
// Pure Dart. The planner compares a decoded file with what is already on
// the phone and sorts every record into one of three piles:
//
//   added      - nothing on the phone has that id: safe to add.
//   identical  - already here, exactly the same: nothing to do.
//   conflicts  - same id, different content: needs a decision.
//
// The person sees those counts (and the conflicts by name) *before*
// choosing. Nothing is written by planning, and nothing is overwritten
// unless they pick [ConflictPolicy.useFile] on purpose.
//
// It also checks that every reference resolves (a transaction's unit, a
// template's source, a limit's unit...) against the file *and* the phone
// together, so a partial backup can be merged into an existing phone but a
// dangling reference can never reach the database's foreign keys.
// ---------------------------------------------------------------------------

import 'dart:convert';

import '../models/backup_snapshot.dart';
import '../models/capture_source.dart';
import '../models/limit_rule.dart';
import '../models/settings.dart';
import '../models/template.dart';
import '../models/transaction.dart';
import '../models/unit.dart';
import 'backup_codec.dart';

/// What to do with a record that exists on both sides but differs.
enum ConflictPolicy {
  /// Leave the phone's version alone. The default.
  keepMine,

  /// Replace the phone's version with the file's.
  useFile,
}

class Conflict<T> {
  final T existing;
  final T incoming;
  const Conflict(this.existing, this.incoming);
}

class TablePlan<T> {
  final List<T> added;
  final int identicalCount;
  final List<Conflict<T>> conflicts;

  const TablePlan({
    this.added = const [],
    this.identicalCount = 0,
    this.conflicts = const [],
  });

  bool get isEmpty => added.isEmpty && identicalCount == 0 && conflicts.isEmpty;
}

class ImportPlan {
  final TablePlan<BackupCategory> categories;
  final TablePlan<MoneyUnit> units;
  final TablePlan<CaptureSource> captureSources;
  final TablePlan<CaptureTemplate> templates;
  final TablePlan<MoneyTransaction> transactions;
  final TablePlan<LimitRule> limits;

  /// The file's settings, if it had any. Applied only when the person
  /// asks for it — never as part of "merge my records".
  final AppSettings? incomingSettings;

  /// References that don't resolve. Any problem means the import can't run.
  final List<String> problems;
  final int moreProblems;

  const ImportPlan({
    required this.categories,
    required this.units,
    required this.captureSources,
    required this.templates,
    required this.transactions,
    required this.limits,
    required this.incomingSettings,
    this.problems = const [],
    this.moreProblems = 0,
  });

  bool get canApply => problems.isEmpty;

  int get addedCount =>
      categories.added.length +
      units.added.length +
      captureSources.added.length +
      templates.added.length +
      transactions.added.length +
      limits.added.length;

  int get identicalCount =>
      categories.identicalCount +
      units.identicalCount +
      captureSources.identicalCount +
      templates.identicalCount +
      transactions.identicalCount +
      limits.identicalCount;

  int get conflictCount =>
      categories.conflicts.length +
      units.conflicts.length +
      captureSources.conflicts.length +
      templates.conflicts.length +
      transactions.conflicts.length +
      limits.conflicts.length;

  bool get hasConflicts => conflictCount > 0;

  /// True when applying (with either policy) could not change any record.
  bool get changesNothing => addedCount == 0 && conflictCount == 0;

  /// The records that would be written under [policy]: everything new,
  /// plus — only for [ConflictPolicy.useFile] — the file's side of each
  /// conflict. Settings are not included; they are a separate choice.
  BackupSnapshot recordsToWrite(ConflictPolicy policy) {
    List<T> pick<T>(TablePlan<T> t) => [
      ...t.added,
      if (policy == ConflictPolicy.useFile)
        for (final c in t.conflicts) c.incoming,
    ];
    return BackupSnapshot(
      categories: pick(categories),
      units: pick(units),
      captureSources: pick(captureSources),
      templates: pick(templates),
      transactions: pick(transactions),
      limits: pick(limits),
    );
  }
}

class ImportPlanner {
  ImportPlanner._();

  static const _maxListedProblems = 20;

  static ImportPlan plan({
    required BackupSnapshot incoming,
    required BackupSnapshot existing,
  }) {
    final categories = _diff<BackupCategory>(
      incoming.categories,
      existing.categories,
      (c) => c.id,
      (c) => jsonEncode(BackupCodec.categoryToJson(c)),
    );
    final units = _diff<MoneyUnit>(
      incoming.units,
      existing.units,
      (u) => u.id,
      (u) => jsonEncode(BackupCodec.unitToJson(u)),
    );
    final sources = _diff<CaptureSource>(
      incoming.captureSources,
      existing.captureSources,
      (s) => s.id,
      (s) => jsonEncode(BackupCodec.captureSourceToJson(s)),
    );
    final templates = _diff<CaptureTemplate>(
      incoming.templates,
      existing.templates,
      (t) => t.id,
      (t) => jsonEncode(t.toJson()),
    );
    final limits = _diff<LimitRule>(
      incoming.limits,
      existing.limits,
      (l) => l.id,
      (l) => jsonEncode(BackupCodec.limitToJson(l)),
    );

    // Original message text is opt-in in a file, so a file without it must
    // not look "different" from a phone that kept it — and replacing the
    // phone's version must not throw the kept text away.
    final rawTx = _diff<MoneyTransaction>(
      incoming.transactions,
      existing.transactions,
      (t) => t.id,
      (t) => jsonEncode(BackupCodec.transactionToJson(t)),
    );
    final transactions = TablePlan<MoneyTransaction>(
      added: rawTx.added,
      identicalCount: rawTx.identicalCount,
      conflicts: [
        for (final c in rawTx.conflicts)
          Conflict(
            c.existing,
            c.incoming.rawText == null && c.existing.rawText != null
                ? c.incoming.copyWith(rawText: c.existing.rawText)
                : c.incoming,
          ),
      ],
    );

    final problems = <String>[];
    var more = 0;
    void problem(String m) {
      if (problems.length < _maxListedProblems) {
        problems.add(m);
      } else {
        more++;
      }
    }

    // A reference resolves if the target is in the file or already here.
    final unitIds = {
      ...incoming.units.map((u) => u.id),
      ...existing.units.map((u) => u.id),
    };
    final categoryIds = {
      ...incoming.categories.map((c) => c.id),
      ...existing.categories.map((c) => c.id),
    };
    final sourceIds = {
      ...incoming.captureSources.map((s) => s.id),
      ...existing.captureSources.map((s) => s.id),
    };
    final templateIds = {
      ...incoming.templates.map((t) => t.id),
      ...existing.templates.map((t) => t.id),
    };

    for (final t in incoming.templates) {
      if (!unitIds.contains(t.unitId)) {
        problem(
          'The rule "${t.name}" belongs to a money unit that is neither in '
          'the file nor on this phone.',
        );
      }
      final src = t.captureSourceId;
      if (src != null && !sourceIds.contains(src)) {
        problem(
          'The rule "${t.name}" points at an app that is neither in the '
          'file nor on this phone.',
        );
      }
    }
    for (final l in incoming.limits) {
      final u = l.unitId;
      if (u != null && !unitIds.contains(u)) {
        problem(
          'A ${l.period.name} limit belongs to a money unit that is '
          'neither in the file nor on this phone.',
        );
      }
    }
    for (final t in incoming.transactions) {
      final label = _txLabel(t);
      if (!unitIds.contains(t.unitId)) {
        problem(
          '$label belongs to a money unit that is neither in the file nor '
          'on this phone.',
        );
      }
      final cat = t.categoryId;
      if (cat != null && !categoryIds.contains(cat)) {
        problem('$label uses a category that is not in the file or here.');
      }
      final tpl = t.templateId;
      if (tpl != null && !templateIds.contains(tpl)) {
        problem('$label points at a rule that is not in the file or here.');
      }
    }

    return ImportPlan(
      categories: categories,
      units: units,
      captureSources: sources,
      templates: templates,
      transactions: transactions,
      limits: limits,
      incomingSettings: incoming.settings,
      problems: problems,
      moreProblems: more,
    );
  }

  static String _txLabel(MoneyTransaction t) {
    final who = t.counterparty;
    final base = who == null || who.isEmpty
        ? 'A transaction'
        : 'The "$who" entry';
    return base;
  }

  static TablePlan<T> _diff<T>(
    List<T> incoming,
    List<T> existing,
    String Function(T) idOf,
    String Function(T) fingerprint,
  ) {
    final byId = {for (final e in existing) idOf(e): e};
    final added = <T>[];
    final conflicts = <Conflict<T>>[];
    var identical = 0;
    for (final item in incoming) {
      final match = byId[idOf(item)];
      if (match == null) {
        added.add(item);
      } else if (fingerprint(match) == fingerprint(item)) {
        identical++;
      } else {
        conflicts.add(Conflict(match, item));
      }
    }
    return TablePlan(
      added: added,
      identicalCount: identical,
      conflicts: conflicts,
    );
  }
}
