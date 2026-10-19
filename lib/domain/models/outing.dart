// ---------------------------------------------------------------------------
// An outing (issue #30): a temporary, named budget with its own window.
//
// "I'm going to Mombasa for 3 days, I have 15,000 for the trip."
//
// Deliberately not a LimitRule: a limit's window is derived from `now`
// (today / this week / this month), while an outing's window is explicit
// and can be any span. The two share *status computation*, not storage —
// `Outing.asLimit()` presents an outing in the shape the limit engine,
// the alert engine and the banner already understand, so none of them
// grows a special case for outings.
//
// No Flutter imports. The whole model is testable without a device.
// ---------------------------------------------------------------------------
import 'limit_rule.dart';

class Outing {
  final String id;
  final String name;

  /// The trip's budget in minor units, in [currencyCode].
  final int amountMinor;

  /// Carried from `AppSettings.currencyCode` at creation. The app is
  /// single-currency (#114), so this equals the app's currency until the
  /// person changes it — at which point the outing keeps the *amount*
  /// they chose (15,000 of whatever was current), which is the honest
  /// reading of "I set my trip budget to 15,000 KES".
  final String currencyCode;

  final DateTime startAt;
  final DateTime endAt;

  /// The units this outing counts, or empty for "every unit". Empty is
  /// the common case: a person on a trip spends across cash, mobile
  /// money and their card, and doesn't want to configure that.
  final Set<String> unitIds;

  /// Whether the ongoing banner shows the outing while active. Also
  /// respects the master `AppSettings.bannerEnabled` — that off means
  /// no banner at all.
  final bool bannerEnabled;

  /// False when the person cancelled the outing early. History stays
  /// (their transactions), but the outing stops counting as active,
  /// stops showing on the banner, and stops alerting.
  final bool enabled;

  final DateTime createdAt;

  const Outing({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
    this.unitIds = const <String>{},
    this.bannerEnabled = true,
    this.enabled = true,
  });

  /// True when [now] is inside [startAt, endAt) and the outing is enabled.
  /// `endAt` is exclusive — an outing that ends at 11am has ended at 11am,
  /// matching how Ledger treats period ends.
  bool isActive(DateTime now) =>
      enabled && !now.isBefore(startAt) && now.isBefore(endAt);

  bool get isPast => DateTime.now().isAfter(endAt);
  bool get isUpcoming => DateTime.now().isBefore(startAt);
  bool get hasStarted => !isUpcoming;

  /// How many days the outing runs for, rounded up — the "3-day trip"
  /// figure shown on the tile.
  int get dayCount {
    final ms = endAt.difference(startAt).inMilliseconds;
    final days = (ms / const Duration(days: 1).inMilliseconds).ceil();
    return days < 1 ? 1 : days;
  }

  Outing copyWith({
    String? name,
    int? amountMinor,
    String? currencyCode,
    DateTime? startAt,
    DateTime? endAt,
    Set<String>? unitIds,
    bool? bannerEnabled,
    bool? enabled,
  }) {
    return Outing(
      id: id,
      name: name ?? this.name,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      unitIds: unitIds ?? this.unitIds,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
    );
  }

  /// The outing presented as a LimitRule. Every downstream consumer that
  /// already accepts a LimitRule — `LimitRule.statusFor`, `Ledger.statusFor`,
  /// `BannerContent.build`, `AlertEngine.levelFor`, `AlertText.build` —
  /// works unchanged on this.
  ///
  /// The `period` field is a placeholder (`day`): outings have no
  /// `LimitPeriod`, and no code that receives an outing's limit ever
  /// reads `period` (they read `startAt`/`endAt` from the outing they
  /// came from).
  LimitRule asLimit() => LimitRule(
    id: id,
    scope: LimitScope.overall,
    period: LimitPeriod.day,
    amountMinor: amountMinor,
    currencyCode: currencyCode,
    enabled: enabled,
  );
}