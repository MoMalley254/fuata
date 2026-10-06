import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Persistent bottom nav across the app's 4 main tabs
/// (ui-design-brief.md section 7.2).
///
/// All four are real screens now (Me is no longer a placeholder); the
/// shell only owns the nav bar and delegates everything else to the
/// `StatefulNavigationShell`, which keeps each branch's state alive like
/// the `IndexedStack` it replaces.
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        // initialLocation:true when re-tapping the current tab, so it
        // pops back to the branch root — the standard Android gesture.
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
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
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}