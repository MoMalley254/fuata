// ---------------------------------------------------------------------------
// Category (issue #83, finding F19).
//
// Until now the `categories` table existed but had no domain model or
// repository — it was there so `MoneyTransaction.categoryId` had somewhere
// real to point. This file is the missing half. The design language: a
// category is user-owned, renameable and archivable, and it lives on the
// transaction rather than replacing the counterparty.
//
// The default set is seeded once on first run (see
// AppDatabase._seedDefaultCategories). It is deliberately small and
// general-purpose — a person who wants more can add more, and the ones
// they never use can be archived away.
// ---------------------------------------------------------------------------
import 'dart:ui';

class Category {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final int sortOrder;

  /// Archived categories keep their history on transactions that already
  /// point at them, but stop appearing in the picker. Same reasoning as
  /// archived units (finding F9): the FK stays valid, the UI just stops
  /// offering it.
  final bool archived;

  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.sortOrder,
    this.archived = false,
  });

  Category copyWith({
    String? name,
    String? emoji,
    Color? color,
    int? sortOrder,
    bool? archived,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
    );
  }
}

/// The categories a fresh install starts with.
///
/// Kept short and general: a person who cooks a lot might want a "Food"
/// that says "Groceries", and one who doesn't cook might archive it. That
/// is the point of making them editable.
final defaultCategories = <Category>[
  Category(
    id: 'cat_food',
    name: 'Food',
    emoji: '🍲',
    color: const Color(0xFFE07A5F),
    sortOrder: 0,
  ),
  Category(
    id: 'cat_transport',
    name: 'Transport',
    emoji: '🚌',
    color: const Color(0xFF277DA1),
    sortOrder: 1,
  ),
  Category(
    id: 'cat_airtime',
    name: 'Airtime',
    emoji: '📶',
    color: const Color(0xFF7B5EA7),
    sortOrder: 2,
  ),
  Category(
    id: 'cat_bills',
    name: 'Bills',
    emoji: '🧾',
    color: const Color(0xFF2E9E6B),
    sortOrder: 3,
  ),
  Category(
    id: 'cat_rent',
    name: 'Rent',
    emoji: '🏠',
    color: const Color(0xFF9A442D),
    sortOrder: 4,
  ),
  Category(
    id: 'cat_shopping',
    name: 'Shopping',
    emoji: '🛍️',
    color: const Color(0xFFE8A317),
    sortOrder: 5,
  ),
  Category(
    id: 'cat_health',
    name: 'Health',
    emoji: '💊',
    color: const Color(0xFFB3123F),
    sortOrder: 6,
  ),
  Category(
    id: 'cat_fun',
    name: 'Fun',
    emoji: '🎬',
    color: const Color(0xFF3D7FE0),
    sortOrder: 7,
  ),
  Category(
    id: 'cat_other',
    name: 'Other',
    emoji: '📦',
    color: const Color(0xFF6E7978),
    sortOrder: 8,
  ),
];