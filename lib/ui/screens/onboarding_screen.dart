import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/onboarding/hello_step.dart';

import '../../domain/logic/onboarding.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/unit.dart';
import '../../platform/banner.dart';
import '../../routing/app_router.dart';
import '../../routing/routes.dart';
import '../../widgets/onboarding/auto_catch_step.dart';
import '../../widgets/onboarding/banner_step.dart';
import '../../widgets/onboarding/limit_step.dart';
import '../../widgets/onboarding/money_step.dart';
import '../../widgets/onboarding/step_frame.dart';
import '../../widgets/onboarding/welcome_step.dart';
import '../providers/app_providers.dart';

/// First-run onboarding (issue #7, US-14, ui-design-brief.md 7.1):
/// welcome → add your money → daily limit → banner → auto-catch.
///
/// Every step can be skipped. Answers collect in an [OnboardingDraft]; the
/// only thing written as the person goes is the accent colour (so they see
/// it apply at once). Units, the limit and the settings are saved together
/// when the flow finishes, and saving `onboardingComplete` is what swaps
/// this screen for the app (see AppGate).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 6;

  final _name = TextEditingController();
  late OnboardingDraft _draft = OnboardingDraft(
    accent: ref.read(currentSettingsProvider).accent,
  );
  int _step = 0;
  int _limitValue = LimitStepper.initial;
  bool _finishing = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isLast => _step == _stepCount - 1;

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _step++);
    }
  }

  void _back() {
    if (_step == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _step--);
  }

  void _setAccent(Color accent) {
    setState(() => _draft = _draft.copyWith(accent: accent));
    // Applied to the whole app straight away, so the person sees it.
    ref
        .read(settingsRepositoryProvider)
        .updateSettings(
          ref.read(currentSettingsProvider).copyWith(accent: accent),
        );
  }

  void _saveUnit(MoneyUnit unit) =>
      setState(() => _draft = _draft.withUnit(unit));

  void _removeUnit(String id) =>
      setState(() => _draft = _draft.withoutUnit(id));

  void _setLimit(int? majorUnits) {
    setState(() {
      _draft = _draft.withDailyLimit(
        majorUnits == null ? null : LimitStepper.toMinor(majorUnits),
      );
    });
    _next();
  }

  Future<void> _setBanner(bool on) async {
    if (!on) {
      setState(() => _draft = _draft.copyWith(bannerOn: false));
      _next();
      return;
    }

    // F15: ask for the permission *now*, while the person is looking at the
    // banner explainer, instead of implicitly on the first post after
    // onboarding. If they say no, the banner is switched off — not left on
    // and silently doing nothing.
    final granted = await BannerPlatform.instance
        .requestNotificationPermission();
    if (!mounted) return;

    setState(() => _draft = _draft.copyWith(bannerOn: granted));
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No problem. You can turn the banner on later in Me → Banner.',
          ),
        ),
      );
    }
    _next();
  }

  /// Saves everything collected, then marks onboarding done. With
  /// [openAutoCatch], Auto-catch is opened on top of the app once the
  /// redirect has moved us off /onboarding.
  ///
  /// #111: the settings write is what flips `onboardingComplete`, which is
  /// what makes the router's redirect move us off /onboarding. A
  /// `Navigator.push` issued from here raced that redirect and lost — on
  /// device the pushed route was dropped or landed behind the shell.
  /// Instead, push through go_router *after* the redirect has settled:
  /// one frame later, on top of whatever the redirect landed on (Home).
  Future<void> _finish({bool openAutoCatch = false}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    // Captured before the await: the router outlives this screen (it's
    // created once by routerProvider for the app's lifetime), so this
    // reference stays valid even after the redirect unmounts us.
    // Deliberately *not* Navigator.of(context): pushing on the raw
    // Navigator is what bypassed go_router and lost the race in the first
    // place.
    final router = ref.read(routerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final draft = _draft.copyWith(name: _name.text);

    try {
      final units = ref.read(unitRepositoryProvider);
      for (final unit in draft.units) {
        await units.addUnit(unit);
      }
      final limit = draft.dailyLimit(
        ref.read(limitsProvider).value ?? const <LimitRule>[],
      );
      if (limit != null) {
        await ref.read(limitRepositoryProvider).setLimit(limit);
      }
      // Last, because this is what leaves onboarding. If anything above
      // failed, the person is still here and can try again (units and the
      // limit are saved by id, so a retry doesn't duplicate them).
      await ref
          .read(settingsRepositoryProvider)
          .updateSettings(draft.settingsFor(ref.read(currentSettingsProvider)));
    } catch (e) {
      if (mounted) {
        setState(() => _finishing = false);
        messenger.showSnackBar(
          SnackBar(content: Text("Couldn't save that. Please try again. ($e)")),
        );
      }
      return;
    }

    // The settings write has committed, so onboarded is now true and the
    // redirect will allow any destination. Wait one frame for the
    // redirect's own navigation to settle, then push Auto-catch on top of
    // it. `router.push` is context-free, so no `context.mounted` check is
    // needed — and none would help, since the redirect will have unmounted
    // this screen by then.
    if (openAutoCatch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        router.push(Routes.autoCatchPath);
      });
    }
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => HelloStep(onContinue: _next,),
      1 => WelcomeStep(
        nameController: _name,
        accent: _draft.accent,
        onAccent: _setAccent,
        onContinue: _next,
        onSkip: _next,
      ),
      2 => MoneyStep(
        units: _draft.units,
        onSaveUnit: _saveUnit,
        onRemoveUnit: _removeUnit,
        onContinue: _next,
        onSkip: _next,
      ),
      3 => LimitStep(
        value: _limitValue,
        onChanged: (v) => setState(() => _limitValue = v),
        onSet: () => _setLimit(_limitValue),
        onSkip: () => _setLimit(null),
      ),
      4 => BannerStep(
        draft: _draft,
        onYes: () => _setBanner(true),
        onNotNow: () => _setBanner(false),
      ),
      _ => AutoCatchStep(
        busy: _finishing,
        onTurnOn: () => _finish(openAutoCatch: true),
        onLater: _finish,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back steps through the flow; only on the first step does it leave.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: _step == 0
                          ? null
                          : IconButton(
                              tooltip: 'Back',
                              onPressed: _finishing ? null : _back,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                    ),
                    Expanded(
                      // F12: no step dots on the welcome screen.
                      child: _step == 0
                          ? const SizedBox.shrink()
                          : StepDots(count: _stepCount, index: _step),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
