// Issue #115: one error card, no exception text on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuata/ui/theme/app_theme.dart';
import 'package:fuata/widgets/provider_error_card.dart';

void main() {
  testWidgets('shows the headline, the runtime type and a working retry',
          (tester) async {
        var retried = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ProviderErrorCard(
                headline: "Couldn't load your money right now",
                error: StateError('the database is on fire'),
                onRetry: () => retried++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Couldn't load your money right now"), findsOneWidget);
        // Runtime type only — never the exception's own message, which can
        // echo the person's data.
        expect(find.text('StateError'), findsOneWidget);
        expect(find.textContaining('on fire'), findsNothing);

        await tester.tap(find.text('Try again'));
        expect(retried, 1);
      });

  testWidgets('no retry button when there is nothing to retry',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ProviderErrorCard(
                headline: "Couldn't load your money right now",
                error: StateError('nope'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Try again'), findsNothing);
        // The headline is still shown, so the person still gets the message.
        expect(find.text("Couldn't load your money right now"), findsOneWidget);
      });
}