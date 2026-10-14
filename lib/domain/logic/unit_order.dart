import '../models/unit.dart';

/// Issue #117: the new `sortOrder` for each unit after the person drags
/// them into [orderedIds] (first id = first on Home and My money).
///
/// Rather than renumbering everything 0..n, the units being reordered
/// trade the sort values they already hold, handed out in ascending order
/// down the new list. That leaves every unit *not* in [orderedIds]
/// (archived ones, chiefly) exactly where it was, so a restored unit still
/// comes back to roughly the place it left from (finding F9).
///
/// When the existing values aren't all distinct (units seeded with 0, or
/// an older backup), trading them would leave ties and the new order
/// wouldn't stick, so those fall back to 0..n-1 by position.
///
/// Ids that match no unit, and repeated ids, are ignored. Returns only
/// the units whose value actually changes.
Map<String, int> unitSortOrdersFor(
  Iterable<MoneyUnit> units,
  List<String> orderedIds,
) {
  final byId = {for (final u in units) u.id: u};
  final ids = <String>[];
  for (final id in orderedIds) {
    if (byId.containsKey(id) && !ids.contains(id)) ids.add(id);
  }

  final slots = [for (final id in ids) byId[id]!.sortOrder]..sort();
  final distinct = slots.toSet().length == slots.length;

  final result = <String, int>{};
  for (var i = 0; i < ids.length; i++) {
    final next = distinct ? slots[i] : i;
    if (byId[ids[i]]!.sortOrder != next) result[ids[i]] = next;
  }
  return result;
}
