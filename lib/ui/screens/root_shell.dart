import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/transaction.dart';
import 'package:fuata/platform/share_intake.dart';
import 'package:fuata/ui/providers/capture_providers.dart';
import 'package:fuata/ui/screens/home_screen.dart';
import 'package:fuata/ui/screens/me_screen.dart';
import 'package:fuata/ui/screens/my_money_screen.dart';
import 'package:fuata/ui/screens/review_inbox_screen.dart';

import 'activity_screen.dart';

/// Persistent bottom nav across the app's 4 main tabs
/// (ui-design-brief.md section 7.2). Today, My Money and Activity are real;
/// Me is a lightweight placeholders until #12 builds it properly.
/// Each tab keeps its own Scaffold/AppBar; this shell only owns the nav bar,
/// so switching tabs doesn't rebuild the others (IndexedStack keeps state).
///
/// #21: this shell also listens for text shared into the app, captures it
/// through CaptureService, and lands the person on the review inbox so
/// they can see what happened.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    for (final queued in drainShareQueue()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSharedText(queued);
      });
    }

    // Cold start from a share sheet: the text arrived before this widget
    // existed, so drain the stash now. Post-frame so the first
    // Navigator.push happens after the first frame.
    final pending = consumePendingSharedText();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onSharedText(pending);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _onSharedText(String text) async {
    CaptureOutcome outcome;
    try {
      outcome = await ref
          .read(captureServiceProvider)
          .capture(text, source: TxSource.shared);
    } catch (e, st) {
      debugPrint('[root_shell] capture failed: $e\n$st');
      return;
    }
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ReviewInboxScreen()));
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case Captured(:final autoAccepted):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              autoAccepted
                  ? 'Caught it — already added to your money.'
                  : 'Caught it — waiting for your check.',
            ),
          ),
        );
      case CaptureDuplicate():
        messenger.showSnackBar(
          const SnackBar(content: Text('Already caught that one.')),
        );
      case CaptureUnparsed():
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't read that one yet — tap Teach me."),
          ),
        );
      case CaptureIgnored():
        break;
    }
  }

  void _openInbox() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ReviewInboxScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onSeeAllActivity: () => setState(() {
              _index = 1;
            }),
            onOpenInbox: _openInbox,
          ),
          const ActivityScreen(),
          const MyMoneyScreen(),
          const MeScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'My money',
          ),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
