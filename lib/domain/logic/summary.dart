import '../models/money.dart';
import '../models/transaction.dart';
import 'ledger.dart';

/// Issue #23 / US-12: Today, this week, this month.
///
/// Pure Dart like the rest of `domain/logic` — no Flutter, no I/O — so the
/// figures can be unit-tested against hand-calculated totals
/// (testing.md, "Summaries").
enum SummaryPeriod { day, week, month }

extension SummaryPeriodWords on SummaryPeriod {
  /// Segmented-control label (ui-design-brief.md 7.11).
  String get label => switch (this) {
    SummaryPeriod.day => 'Day',
    SummaryPeriod.week => 'Week',
    SummaryPeriod.month => 'Month',
  };

  String get thisWord => switch (this) {
    SummaryPeriod.day => 'today',
    SummaryPeriod.week => 'this week',
    SummaryPeriod.month => 'this month',
  };

  String get previousWord => switch (this) {
    SummaryPeriod.day => 'yesterday',
    SummaryPeriod.week => 'last week',
    SummaryPeriod.month => 'last month',
  };
}

/// One line in "Where it went" / "Where it came from".
class RankedTotal {
  final String label;
  final int minor;
  final int count;
  const RankedTotal({
    required this.label,
    required this.minor,
    required this.count,
  });
}

/// One slice of the per-unit split.
class UnitTotal {
  final String unitId;
  final int minor;
  const UnitTotal({required this.unitId, required this.minor});
}

/// "KSh 8,420" — whole amounts drop the ".00" so a story reads like a
/// sentence. Display only; nothing is computed from the string.
String friendlyMoney(
    int minor,
    String currencyCode, {
      bool masked = false,
    }) {
  if (masked) return kHiddenAmountMask;
  var text = Money(minor, currencyCode).format();
  if (text.endsWith('.00')) text = text.substring(0, text.length - 3);
  return '${currencySymbol(currencyCode)}$text';
}

class PeriodSummary {
  final SummaryPeriod period;

  /// [from, to) of the period being summarised, local time.
  final DateTime from;
  final DateTime to;

  final int spentMinor;
  final int gotMinor;

  /// The same stretch of the previous period (see [build]) so "so far"
  /// is compared with "so far" rather than with a finished week.
  final int previousSpentMinor;
  final int previousGotMinor;

  /// Ranked, biggest first. Only named counterparties appear.
  final List<RankedTotal> spentTo;
  final List<RankedTotal> gotFrom;

  /// Spending with no counterparty, so "See all" plus this adds up to
  /// [spentMinor].
  final int unnamedSpentMinor;

  final List<UnitTotal> spentByUnit;

  /// Confirmed spent/got entries in the period. Fee rows belong to their
  /// parent and are not counted separately.
  final int transactionCount;

  /// Days from [from] up to today, counting today. Used for the average.
  final int daysSoFar;

  const PeriodSummary({
    required this.period,
    required this.from,
    required this.to,
    required this.spentMinor,
    required this.gotMinor,
    required this.previousSpentMinor,
    required this.previousGotMinor,
    required this.spentTo,
    required this.gotFrom,
    required this.unnamedSpentMinor,
    required this.spentByUnit,
    required this.transactionCount,
    required this.daysSoFar,
  });

  bool get hasActivity => transactionCount > 0;

  int get netMinor => gotMinor - spentMinor;

  /// Average spent per day so far. Integer division: display only.
  int get averageSpentPerDayMinor =>
      daysSoFar <= 0 ? 0 : spentMinor ~/ daysSoFar;

  /// [include] narrows which transactions count, e.g. only units in one
  /// currency (testing.md T-13: a different-currency unit is excluded
  /// rather than added to the total as if it were the same money).
  static PeriodSummary build( Iterable<MoneyTransaction> all,
SummaryPeriod period,
DateTime now, {
bool Function(MoneyTransaction)? include,}) {
    final list = all.where((t) => include?.call(t) ?? true).toList();

    final (from, to) = switch (period) {
      SummaryPeriod.day => Ledger.todayRange(now),
      SummaryPeriod.week => Ledger.weekRange(now),
      SummaryPeriod.month => Ledger.monthRange(now),
    };

    // Previous period, cut at the same elapsed time. DateTime's
    // constructor normalises day 0 / month 0 across month and year edges.
    final prevFrom = switch (period) {
      SummaryPeriod.day => DateTime(from.year, from.month, from.day - 1),
      SummaryPeriod.week => DateTime(from.year, from.month, from.day - 7),
      SummaryPeriod.month => DateTime(from.year, from.month - 1, 1),
    };
    final aligned = prevFrom.add(now.difference(from));
    final prevTo = aligned.isAfter(from) ? from : aligned;

    final byId = {for (final t in list) t.id: t};
    final spentTo = <String, _Acc>{};
    final gotFrom = <String, _Acc>{};
    final unitSpent = <String, int>{};
    var spent = 0;
    var got = 0;
    var unnamed = 0;
    var count = 0;

    for (final t in list) {
      if (!t.countsAsSpending && !t.countsAsIncome) continue;
      if (t.occurredAt.isBefore(from) || !t.occurredAt.isBefore(to)) continue;

      final isFee = t.parentId != null;
      if (!isFee) count++;
      final name = _nameOf(t, byId);

      if (t.countsAsSpending) {
        final amount = -t.amountMinor;
        spent += amount;
        unitSpent[t.unitId] = (unitSpent[t.unitId] ?? 0) + amount;
        if (name == null) {
          unnamed += amount;
        } else {
          spentTo
              .putIfAbsent(name.toLowerCase(), () => _Acc(name))
              .add(amount, isFee);
        }
      } else {
        got += t.amountMinor;
        if (name != null) {
          gotFrom
              .putIfAbsent(name.toLowerCase(), () => _Acc(name))
              .add(t.amountMinor, isFee);
        }
      }
    }

    return PeriodSummary(
      period: period,
      from: from,
      to: to,
      spentMinor: spent,
      gotMinor: got,
      previousSpentMinor: Ledger.spentInPeriod(list, prevFrom, prevTo),
      previousGotMinor: Ledger.gotInPeriod(list, prevFrom, prevTo),
      spentTo: _ranked(spentTo),
      gotFrom: _ranked(gotFrom),
      unnamedSpentMinor: unnamed,
      spentByUnit: [
        for (final e in unitSpent.entries)
          UnitTotal(unitId: e.key, minor: e.value),
      ]..sort((a, b) {
        final byAmount = b.minor.compareTo(a.minor);
        return byAmount != 0 ? byAmount : a.unitId.compareTo(b.unitId);
      }),
      transactionCount: count,
      daysSoFar: DateTime(now.year, now.month, now.day)
          .difference(DateTime(from.year, from.month, from.day))
          .inDays +
          1,
    );
  }

  /// The story card's copy (ui-design-brief.md 7.11): plain sentences,
  /// never guilt. Example: "This week you spent KSh 8,420. Java House was
  /// your top spot. A bit more than last week."
  String story(String currencyCode, {bool masked = false}) {
    final when = period.thisWord;

    if (!hasActivity) return 'Nothing recorded $when yet.';

    if (spentMinor == 0) {
      return "You haven't spent anything $when, and "
          '${friendlyMoney(gotMinor, currencyCode, masked: masked)} came in.';
    }

    final sentences = <String>[
      '${_capitalise(when)} you spent '
          '${friendlyMoney(spentMinor, currencyCode, masked: masked)}.',
      if (spentTo.isNotEmpty) '${spentTo.first.label} was your top spot.',
      ?_comparison(),
    ];
    return sentences.join(' ');
  }

  String? _comparison() {
    if (spentMinor <= 0 || previousSpentMinor <= 0) return null;
    final now100 = spentMinor * 100;
    final was = previousSpentMinor;
    final String phrase;
    if (now100 >= was * 125) {
      phrase = 'Quite a bit more than';
    } else if (now100 > was * 105) {
      phrase = 'A bit more than';
    } else if (now100 <= was * 75) {
      phrase = 'Quite a bit less than';
    } else if (now100 < was * 95) {
      phrase = 'A bit less than';
    } else {
      phrase = 'About the same as';
    }
    return '$phrase ${period.previousWord}.';
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// Counterparty of [t], or of its parent for a fee row (a fee belongs to
  /// the payment it came with). Null when nothing names it.
  static String? _nameOf(MoneyTransaction t, Map<String, MoneyTransaction> byId) {
    final own = t.counterparty?.trim();
    if (own != null && own.isNotEmpty) return own;
    final parentId = t.parentId;
    if (parentId == null) return null;
    final parent = byId[parentId]?.counterparty?.trim();
    return (parent != null && parent.isNotEmpty) ? parent : null;
  }

  static List<RankedTotal> _ranked(Map<String, _Acc> accs) {
    final out = [
      for (final a in accs.values)
        RankedTotal(label: a.label, minor: a.minor, count: a.count),
    ];
    out.sort((a, b) {
      final byAmount = b.minor.compareTo(a.minor);
      return byAmount != 0
          ? byAmount
          : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return out;
  }
}

/// Running total for one counterparty. Grouped case-insensitively; the
/// first spelling seen is the one shown.
class _Acc {
  final String label;
  int minor = 0;
  int count = 0;
  _Acc(this.label);

  void add(int amount, bool isFee) {
    minor += amount;
    if (!isFee) count++;
  }
}