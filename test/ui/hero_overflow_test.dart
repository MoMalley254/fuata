// Issue #110: the Home hero number must not clip, overflow its card, or
// push the status pill off it when the amount is very large.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/mock/mock_repositories.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/screens/home_screen.dart';
import 'package:fuata/ui/theme/app_theme.dart';
import 'package:fuata/widgets/status_ring_card.dart';

void main() {
  Future<void> usePhoneSize(WidgetTester tester) async {
    // 360 dp is the design width (ui-design-brief.md section 4).
    // Physical size is dp * dpr, so 360 x 3 = 1080.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(Widget child) => ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );

  final bigUnit = MoneyUnit(
    id: 'u1',
    name: 'Bank',
    kind: UnitKind.bank,
    currencyCode: 'KES',
    iconEmoji: '🏦',
    color: const Color(0xFF000000),
    openingBalanceMinor: 0,
    sortOrder: 0,
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets('StatusRingCard: a 9-figure balance does not overflow',
          (tester) async {
        await usePhoneSize(tester);
        await tester.pumpWidget(wrap(
          const StatusRingCard(
            // 123,456,789 — the number from the issue.
            remaining: 123456789,
            spent: 500,
            limit: 2000000,
            status: SpendStatus.safe,
            currencySymbol: 'KSh ',
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'a 9-figure hero number must not overflow its card',
        );
        // The number is still on screen, not clipped away.
        expect(find.textContaining('123,456,789'), findsOneWidget);
      });

  testWidgets('HeroSection fallback: a 9-figure balance does not overflow',
          (tester) async {
        await usePhoneSize(tester);
        final state = HomeState(
          units: [bigUnit],
          balanceByUnit: const {'u1': 12345678900},
          spentToday: 0,
          dailyLimit: null, // force the plain fallback card
          status: SpendStatus.safe,
          lately: const [],
        );
        await tester.pumpWidget(wrap(
          HeroSection(state: state, headline: HomeHeadline.totalIHave),
        ));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'a 9-figure hero number must not overflow its card',
        );
        expect(find.textContaining('123,456,789'), findsWidgets);
      });
}