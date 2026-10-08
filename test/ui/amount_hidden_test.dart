// Issue #81 (finding F7): one switch hides every amount in the app.
//
// Overrides the settings repository with an in-memory one so the toggle
// writes somewhere real (without a database) and the setting streams back
// through the providers the screens actually read.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/mock/mock_repositories.dart';
import 'package:fuata/domain/models/limit_rule.dart';
import 'package:fuata/domain/models/money.dart';
import 'package:fuata/domain/models/settings.dart';
import 'package:fuata/domain/models/unit.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/theme/app_theme.dart';
import 'package:fuata/widgets/amount_text.dart';
import 'package:fuata/widgets/personalization/amount_visibility_toggle.dart';
import 'package:fuata/widgets/status_ring_card.dart';
import 'package:fuata/widgets/transaction_row.dart';
import 'package:fuata/widgets/unit_card.dart';

Future<MockSettingsRepository> _repo({required bool hidden}) async {
  final repo = MockSettingsRepository();
  await repo.updateSettings(
    AppSettings.defaults.copyWith(amountsHidden: hidden),
  );
  return repo;
}

Widget _app(MockSettingsRepository repo, Widget body, {List<Widget> actions = const []}) {
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(appBar: AppBar(actions: actions), body: body),
    ),
  );
}

class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) => const SingleChildScrollView(
    child: Column(
      children: [
        UnitCard(
          kind: UnitKind.cash,
          title: 'Cash',
          balance: 1250,
          currencySymbol: 'KSh ',
        ),
        TransactionRow(title: 'Java House', amount: -350, emoji: '🍲'),
        StatusRingCard(
          remaining: 1500,
          spent: 500,
          limit: 2000,
          status: SpendStatus.safe,
          currencySymbol: 'KSh ',
        ),
        AmountText(minor: 842000, currencyCode: 'KES'),
      ],
    ),
  );
}

void main() {
  testWidgets('amounts show normally when the switch is off', (tester) async {
    await tester.pumpWidget(_app(await _repo(hidden: false), const _Sample()));
    await tester.pumpAndSettle();

    expect(find.textContaining('KSh'), findsWidgets);
    expect(find.textContaining('1,500'), findsOneWidget);
    expect(find.textContaining(kHiddenAmountMask), findsNothing);
  });

  testWidgets('no amount survives while hidden (issue #81 acceptance)',
          (tester) async {
        await tester.pumpWidget(_app(await _repo(hidden: true), const _Sample()));
        await tester.pumpAndSettle();

        expect(find.textContaining('KSh'), findsNothing);
        expect(find.textContaining('1,250'), findsNothing);
        expect(find.textContaining('1,500'), findsNothing);
        expect(find.textContaining('350'), findsNothing);
        expect(find.textContaining('8,420'), findsNothing);
        expect(find.textContaining(kHiddenAmountMask), findsWidgets);
      });

  testWidgets('the eye toggles the one stored setting', (tester) async {
    final repo = await _repo(hidden: false);
    await tester.pumpWidget(
      _app(
        repo,
        const _Sample(),
        actions: const [AmountVisibilityToggle()],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('KSh'), findsWidgets);

    await tester.tap(find.byType(AmountVisibilityToggle));
    await tester.pumpAndSettle();

    expect(find.textContaining('KSh'), findsNothing);
    expect(find.textContaining(kHiddenAmountMask), findsWidgets);
    expect((await repo.watchSettings().first).amountsHidden, isTrue);
  });
}