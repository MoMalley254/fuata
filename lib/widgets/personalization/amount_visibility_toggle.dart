import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/providers/app_providers.dart';

/// The eye that hides every amount in the app (issue #81, finding F7).
///
/// Used on Today, My money and the unit page. All three toggle the *same*
/// stored setting, so hiding on one hides on all of them — and the choice
/// survives navigation and a restart, because it is a setting, not widget
/// state.
class AmountVisibilityToggle extends ConsumerWidget {
  const AmountVisibilityToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(currentSettingsProvider);
    final hidden = settings.amountsHidden;
    return IconButton(
      tooltip: hidden ? 'Show amounts' : 'Hide amounts',
      icon: Icon(
        hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      ),
      onPressed: () => ref
          .read(settingsRepositoryProvider)
          .updateSettings(settings.copyWith(amountsHidden: !hidden)),
    );
  }
}