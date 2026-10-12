import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:fuata/platform/banner.dart';
import 'package:fuata/routing/routes.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/screens/lock_screen.dart';
import 'package:go_router/go_router.dart';

import '../domain/logic/summary.dart';
import '../domain/models/template.dart';
import '../ui/screens/activity_screen.dart';
import '../ui/screens/archived_units_screen.dart';
import '../ui/screens/auto_catch_screen.dart';
import '../ui/screens/banner_setup_screen.dart';
import '../ui/screens/data_backup_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/limits_screen.dart';
import '../ui/screens/manage_rules_screen.dart';
import '../ui/screens/my_money_screen.dart';
import '../ui/screens/onboarding_screen.dart';
import '../ui/screens/profile_screen.dart';
import '../ui/screens/review_inbox_screen.dart';
import '../ui/screens/root_shell.dart';
import '../ui/screens/rule_builder_screen.dart';
import '../ui/screens/settings/appearance_screen.dart';
import '../ui/screens/settings/detail_level_screen.dart';
import '../ui/screens/settings/home_settings_screen.dart';
import '../ui/screens/settings/manage_categories_screen.dart';
import '../ui/screens/settings/privacy_data_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/summary_screen.dart';
import '../ui/screens/unit_detail_screen.dart';
import '../widgets/sheets/add_transaction_sheet.dart';
import 'app_keys.dart';

/// Set once from `main()`, before `runApp`: the banner action that launched
/// a *terminated* app, if any. Read by [routerProvider] to choose the
/// initial location; the redirect decides whether that location is allowed
/// yet (e.g. not while onboarding).
final initialBannerActionProvider = Provider<BannerAction?>((ref) => null);
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// True only once the person has unlocked *this session*. A cold start
/// is false; backgrounding the app flips it back to false (see Fuata's
/// lifecycle observer in main.dart).
final unlockedThisSessionProvider = StateProvider<bool>((ref) => false);

/// Whether the lock screen should be showing right now: the person asked
/// for it, and they haven't unlocked yet. Derived, so nothing has to keep
/// two booleans in sync by hand.
final lockedProvider = Provider<bool>((ref) {
  final appLock = ref.watch(currentSettingsProvider).appLockEnabled;
  return appLock && !ref.watch(unlockedThisSessionProvider);
});

final routerProvider = Provider<GoRouter>((ref) {
  // go_router wants a Listenable for the redirect. The settings stream is
  // the only thing that changes whether onboarding is done, so a small
  // counter bumped on every settings emission is enough.
  final refresh = ValueNotifier<int>(0);
  ref.listen(settingsProvider, (_, _) => refresh.value++);
  // Without this, unlocking never re-runs the redirect and the person
  // stares at the lock screen until they force-quit.
  ref.listen(lockedProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final initialAction = ref.read(initialBannerActionProvider);
  // What the user asked for on a cold start; also what /splash returns to
  // once settings have loaded.
  final intendedLocation = initialAction == BannerAction.quickAdd
      ? Routes.addPath
      : Routes.homePath;
  
  return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: intendedLocation,
      refreshListenable: refresh,
      observers: [FlutterSmartDialog.observer],
      redirect: (context, state) {
        final settings = ref.read(settingsProvider);
        final loc = state.matchedLocation;

        // 1. Settings are still being read: show splash.
        if (settings.isLoading) {
          return loc == Routes.splashPath ? null : Routes.splashPath;
        }
        // 2. Settings failed to load: never trap the person outside their
        // own money. Fall through and let whatever screen handle it.
        if (settings.hasError) return null;

        final s = settings.value!;

        // 3. Not onboarded -> onboarding, and only onboarding. Comes before the
        //    lock check so a fresh install (where appLockEnabled is false
        //    anyway, but still) can never be gated by a lock it never set.
        if (!s.onboardingComplete) {
          return loc == Routes.onboardingPath ? null : Routes.onboardingPath;
        }

        // 4. Locked -> lock, and only lock.
        if (ref.read(lockedProvider)) {
          return loc == Routes.lockPath ? null : Routes.lockPath;
        }

        // 5. Unlocked: bounce off the transient routes.
        if (loc == Routes.lockPath) return Routes.homePath;
        if (loc == Routes.splashPath) return intendedLocation;
        if (loc == Routes.onboardingPath) return Routes.homePath;

        return null;
      },
      routes: [
        GoRoute(
          path: Routes.splashPath,
          name: Routes.splash,
          builder: (_, _) => const _SplashScreen(),
        ),
        GoRoute(
          path: Routes.onboardingPath,
          name: Routes.onboarding,
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: Routes.lockPath,
          name: Routes.lock,
          builder: (_, _) => LockScreen(
            onUnlocked: () =>
            ref.read(unlockedThisSessionProvider.notifier).state = true,
          )
        ),

        // The four tabs. StatefulShellRoute keeps each branch's state, like
        // the IndexedStack it replaces.
        StatefulShellRoute.indexedStack(
          builder: (_, _, navigationShell) =>
              RootShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              navigatorKey: _shellNavigatorKey,
              routes: [
                GoRoute(
                  path: Routes.homePath,
                  name: Routes.home,
                  builder: (_, _) => const HomeScreen(),
                  routes: [
                    // Full path is '/add'. Nested so go_router always builds Home
                    // underneath it — including on a cold start where '/add' is the
                    // initial location (issue-26 F1: banner + Add from a swiped-away
                    // app). Popping the sheet then lands on Today, never a black
                    // screen.
                    GoRoute(
                      path: 'add',
                      name: Routes.add,
                      parentNavigatorKey: rootNavigatorKey,
                      pageBuilder: (_, state) => _SheetPage<void>(
                        key: state.pageKey,
                        child: AddTransactionSheet(
                          initialUnitId: state.uri.queryParameters['unitId'],
                        ),
                      ),
                    ),
                  ]
                ),
              ],
            ),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.activityPath,
                name: Routes.activity,
                builder: (_, _) => const ActivityScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.myMoneyPath,
                name: Routes.myMoney,
                builder: (_, _) => const MyMoneyScreen(),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.settingsPath,
                name: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
              ),
            ]),
          ]
        ),

        // Full-screen routes on top of the shell.
        GoRoute(
          path: Routes.unitPath,
          name: Routes.unit,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => UnitDetailScreen(
            unitId: state.pathParameters['id']!,
          ),
          routes: [
            GoRoute(
              path: 'rules',
              name: Routes.manageRules,
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => ManageRulesScreen(
                unitId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: Routes.inboxPath,
          name: Routes.inbox,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const ReviewInboxScreen(),
        ),
        GoRoute(
          path: Routes.summaryPath,
          name: Routes.summary,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final raw = state.uri.queryParameters['period'];
            final period = raw == null
                ? SummaryPeriod.day
                : SummaryPeriod.values.firstWhere(
                  (p) => p.name == raw,
              orElse: () => SummaryPeriod.day,
            );
            return SummaryScreen(initialPeriod: period);
          },
        ),
        GoRoute(
          path: Routes.ruleBuilderNewPath,
          name: Routes.ruleBuilderNew,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => RuleBuilderScreen(
            unitId: state.uri.queryParameters['unitId'],
            sampleText: state.extra is String ? state.extra as String : null,
          ),
        ),
        GoRoute(
          path: Routes.ruleBuilderEditPath,
          name: Routes.ruleBuilderEdit,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => RuleBuilderScreen(
            existing: state.extra is CaptureTemplate
                ? state.extra as CaptureTemplate
                : null,
          ),
        ),
        GoRoute(
          path: Routes.limitsPath,
          name: Routes.limits,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const LimitsScreen(),
        ),
        GoRoute(
          path: Routes.bannerPath,
          name: Routes.banner,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const BannerSetupScreen(),
        ),
        GoRoute(
          path: Routes.autoCatchPath,
          name: Routes.autoCatch,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const AutoCatchScreen(),
        ),
        GoRoute(
          path: Routes.backupPath,
          name: Routes.backup,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const DataBackupScreen(),
        ),
        GoRoute(
          path: Routes.profilePath,
          name: Routes.profile,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const ProfileScreen(),
        ),
        GoRoute(
          path: Routes.settingsHomePath,
          name: Routes.settingsHome,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const HomeSettingsScreen(),
        ),
        GoRoute(
          path: Routes.settingsDetailPath,
          name: Routes.settingsDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const DetailLevelScreen(),
        ),
        GoRoute(
          path: Routes.settingsAppearancePath,
          name: Routes.settingsAppearance,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const AppearanceScreen(),
        ),
        GoRoute(
          path: Routes.settingsPrivacyPath,
          name: Routes.settingsPrivacy,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const PrivacyDataScreen(),
        ),
        GoRoute(
          path: Routes.archivedUnitsPath,
          name: Routes.archivedUnits,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const ArchivedUnitsScreen(),
        ),
        GoRoute(
          path: Routes.settingsCategoriesPath,
          name: Routes.settingsCategories,
          parentNavigatorKey: rootNavigatorKey,
          builder: (_, _) => const ManageCategoriesScreen(),
        ),
      ]
  );
});

/// A go_router `Page` that renders its child as a modal bottom sheet.
/// `ModalBottomSheetRoute` gives the sheet its look, its drag-to-dismiss,
/// and its tap-scrim-dismiss; go_router keeps it on the route stack so it
/// is deep-linkable and back-button-aware.
class _SheetPage<T> extends Page<T> {
  const _SheetPage({required this.child, super.key});
  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => ModalBottomSheetRoute<T>(
    builder: (_) => child,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    settings: this,
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator.adaptive()),
  );
}
