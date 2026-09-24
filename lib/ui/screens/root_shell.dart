import 'package:flutter/material.dart';
import 'package:fuata/ui/screens/home_screen.dart';
import 'package:fuata/ui/screens/my_money_screen.dart';
import 'package:fuata/ui/screens/placeholder_tab_screen.dart';

import 'activity_screen.dart';

/// Persistent bottom nav across the app's 4 main tabs
/// (ui-design-brief.md section 7.2). Today, My Money and Activity are real;
/// Me is a lightweight placeholders until #12 builds it properly.
/// Each tab keeps its own Scaffold/AppBar; this shell only owns the nav bar,
/// so switching tabs doesn't rebuild the others (IndexedStack keeps state).
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

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
          ),
          const ActivityScreen(),
          const MyMoneyScreen(),
          const PlaceholderTabScreen(
            title: 'Me',
            emoji: '⚙️',
            message: 'Personalisation, limits and privacy settings land here.',
            issueRef: '#12',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: 'My money'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Me'),
        ],
      ),
    );
  }
}
