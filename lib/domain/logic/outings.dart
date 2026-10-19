// ---------------------------------------------------------------------------
// Pure logic for outings (issue #30): which one is active, how much has
// been spent against it, and its status.
//
// Same rules the limit engine uses: only confirmed `spent` transactions
// count, `moved` and `adjustment` don't, and spending in a different
// currency is excluded rather than added as if it were the same money
// (design.md LIMIT_RULE / T-13). "How much has this trip cost" is the
// same question as "how much has today cost", only over a different
// window.
// ---------------------------------------------------------------------------
import '../models/limit_rule.dart';
import '../models/money.dart';
import '../models/outing.dart';
import '../models/transaction.dart';
import 'ledger.dart';

class Outings {
  Outings._();

  /// The outing the app should be showing right now, or null when none
  /// is active. When more than one is active (a weekend trip inside a
  /// longer one, say), the more recently created wins — starting a new
  /// outing is a person saying "this replaces the last one".
  static Outing? activeFrom(
      Iterable<Outing> outings, {
        required DateTime now,
      }) {
    final active = outings.where((o) => o.isActive(now)).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return active.first;
  }

  /// Total spending in [outing]'s window, counting only units in the
  /// outing's currency. [currencyByUnit] maps every unit (archived
  /// included) to its currency; a unit not in the map is counted (same
  /// fallback AlertEngine.due uses for archived units).
  static int spentIn(
      Outing outing,
      Iterable<MoneyTransaction> transactions, {
        required Map<String, String> currencyByUnit,
      }) {
    final inCurrency = transactions.where((t) {
      final code = currencyByUnit[t.unitId];
      return code == null || code == outing.currencyCode;
    });
    if (outing.unitIds.isEmpty) {
      return Ledger.spentInPeriod(inCurrency, outing.startAt, outing.endAt);
    }
    var total = 0;
    for (final id in outing.unitIds) {
      total += Ledger.spentInPeriod(
        inCurrency,
        outing.startAt,
        outing.endAt,
        unitId: id,
      );
    }
    return total;
  }

  /// Status of [outing] given [spentMinor]. Delegates to the limit rule
  /// so the thresholds can never disagree with the daily limit's — the
  /// two use the same safe/warning/danger/overdraft boundaries.
  static SpendStatus statusFor(Outing outing, int spentMinor) =>
      outing.asLimit().statusFor(spentMinor);

  /// Everything the banner and the hero card need, in one call, so
  /// neither has to re-derive it.
  static OutingState stateFor(
      Outing outing,
      Iterable<MoneyTransaction> transactions, {
        required Map<String, String> currencyByUnit,
        required DateTime now,
      }) {
    final spent = spentIn(outing, transactions, currencyByUnit: currencyByUnit);
    return OutingState(
      outing: outing,
      spentMinor: spent,
      remainingMinor: outing.amountMinor - spent,
      status: statusFor(outing, spent),
      isActive: outing.isActive(now),
    );
  }
}

class OutingState {
  final Outing outing;
  final int spentMinor;
  final int remainingMinor;
  final SpendStatus status;
  final bool isActive;

  const OutingState({
    required this.outing,
    required this.spentMinor,
    required this.remainingMinor,
    required this.status,
    required this.isActive,
  });

  /// "Mombasa trip · ends Fri 20:00" — a caption for the hero card.
  String caption(DateTime now) {
    if (isActive) return 'ends ${_shortEnd()}';
    if (outing.isUpcoming) return 'starts ${_shortStart()}';
    return 'ended ${_shortEnd()}';
  }

  String _shortEnd() => _format(outing.endAt);
  String _shortStart() => _format(outing.startAt);

  static String _format(DateTime at) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]}';
  }
}

/// Format an outing's amount for display. Whole numbers drop the ".00"
/// so a caption reads "3,500 left", not "3,500.00 left".
String friendlyOutingMoney(int minor, String currencyCode) {
  var text = Money(minor, currencyCode).format();
  if (text.endsWith('.00')) text = text.substring(0, text.length - 3);
  return '${currencySymbol(currencyCode)}$text';
}