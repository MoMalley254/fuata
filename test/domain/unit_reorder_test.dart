// Issue #117: long-press and drag reorders the My money row on Home.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/mock/mock_repositories.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/screens/home_screen.dart';
import 'package:fuata/ui/theme/app_theme.dart';

void main() {
  MoneyUnit unit(String id, String name, int sortOrder) => MoneyUnit(
    id: id,
    name: name,
    kind: UnitKind.cash,
    currencyCode: 'KES',
    iconEmoji: '💵',
    color: const Color(0xFF2E9E6B),
    openingBalanceMinor: 0,
    sortOrder: sortOrder,
    createdAt: DateTime(2026, 1, 1),
  );

  HomeState stateOf(List<MoneyUnit> units) => HomeState(
    units: units,
    balanceByUnit: {for (final u in units) u.id: 1000},
    spentToday: 0,
    dailyLimit: null,
    status: SpendStatus.safe,
    lately: const [],
  );

  setUp(() {
    // HapticFeedback goes through the platform channel, which has no
    // handler under flutter_test.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<void> pumpRow(
    WidgetTester tester,
    HomeState state, {
    ValueChanged<List<String>>? onReorder,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360 dp wide
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            MockSettingsRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: UnitRow(state: state, onReorder: onReorder),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long-press and drag a card reports the new order', (
    tester,
  ) async {
    final state = stateOf([unit('a', 'Alpha', 1), unit('b', 'Bravo', 2)]);
    List<String>? reported;
    await pumpRow(tester, state, onReorder: (ids) => reported = ids);

    final from = tester.getCenter(find.text('Alpha'));
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Far enough to pass Bravo's midpoint.
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reported, ['b', 'a']);
    // The row shows the new order straight away, before any database
    // round trip.
    expect(
      tester.getCenter(find.text('Bravo')).dx,
      lessThan(tester.getCenter(find.text('Alpha')).dx),
    );
  });

  testWidgets('a quick drag scrolls instead of reordering', (tester) async {
    final state = stateOf([unit('a', 'Alpha', 1), unit('b', 'Bravo', 2)]);
    var calls = 0;
    await pumpRow(tester, state, onReorder: (_) => calls++);

    await tester.drag(find.text('Alpha'), const Offset(-150, 0));
    await tester.pumpAndSettle();

    expect(calls, 0);
  });

  testWidgets('without onReorder the row is the plain list', (tester) async {
    final state = stateOf([unit('a', 'Alpha', 1), unit('b', 'Bravo', 2)]);
    await pumpRow(tester, state);

    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Bravo'), findsOneWidget);
  });
}
