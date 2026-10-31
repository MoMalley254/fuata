// test/domain/unit_reorder_test.dart

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
import 'package:fuata/widgets/unit_card.dart';

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

  testWidgets('long-press and drag a card reports the new order', (tester) async {
    final state = stateOf([unit('a', 'Alpha', 1), unit('b', 'Bravo', 2)]);
    List<String>? reported;
    await pumpRow(tester, state, onReorder: (ids) => reported = ids);

    final alphaCard = find.widgetWithText(UnitCard, 'Alpha');
    final bravoCard = find.widgetWithText(UnitCard, 'Bravo');
    final start = tester.getCenter(alphaCard);
    final target = tester.getCenter(bravoCard);

    // 1. Press and hold past the long-press delay (kLongPressTimeout = 500ms).
    final gesture = await tester.startGesture(start);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));

    // 2. Drag in small steps, pumping a frame each time, so the list
    //    recomputes its insert index as the proxy crosses Bravo's midpoint.
    final dx = (target.dx - start.dx) + 40; // a bit past Bravo's center
    const steps = 20;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));

    // 3. Drop.
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reported, ['b', 'a']);
    expect(
      tester.getCenter(find.text('Bravo')).dx,
      lessThan(tester.getCenter(find.text('Alpha')).dx),
    );
  });

  testWidgets('a quick drag scrolls instead of reordering', (tester) async {
    final state = stateOf([unit('a', 'Alpha', 1), unit('b', 'Bravo', 2)]);
    var calls = 0;
    await pumpRow(tester, state, onReorder: (_) => calls++);

    // A standard drag does NOT wait for kLongPressTimeout, so the
    // ReorderableDelayedDragStartListener will not activate, preventing reorder.
    await tester.drag(find.byType(UnitCard).first, const Offset(-150, 0));
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