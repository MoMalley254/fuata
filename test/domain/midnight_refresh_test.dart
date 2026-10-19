import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/data/mock/mock_repositories.dart';
import 'package:fuata/ui/providers/app_providers.dart';

void main() {
  testWidgets('crossing a day boundary refreshes the derived state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        unitRepositoryProvider.overrideWithValue(MockUnitRepository()),
        transactionRepositoryProvider.overrideWithValue(
          MockTransactionRepository(),
        ),
        limitRepositoryProvider.overrideWithValue(MockLimitRepository()),
        settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
      ],
    );

    var recomputes = 0;
    container.listen<AsyncValue<HomeState>>(
      homeStateProvider,
      (_, _) => recomputes++,
      fireImmediately: true,
    );
    await tester.pumpAndSettle();

    final initial = recomputes;

    // A day, a week, a month — no transaction added, no setting edited.
    await tester.pump(const Duration(days: 40));

    // Dispose inside the body, before the assertion. addTearDown runs
    // *after* flutter_test checks for pending timers, so the ticker's
    // armed Timer would be caught by that check first. Disposing here
    // lets ref.onDispose cancel it while we're still in the fake-async
    // zone, and then the assertion runs on a clean slate.
    container.dispose();
    // Let drift's stream-close timer fire. `StreamQueryStore.markAsClosed`
    // schedules a zero-duration timer to release the query's listener map;
    // without pumping, flutter_test's `_verifyInvariants` sees a pending
    // timer and fails the test even though the assertion below passes.
    await tester.pump(Duration.zero);

    expect(
      recomputes,
      greaterThan(initial),
      reason:
          'issue #107: the app never recomputes its limits and totals '
          'when the date moves. Nothing watches the clock — the derived '
          'state only refreshes on user action.',
    );
  });
}
