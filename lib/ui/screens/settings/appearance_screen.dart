import 'package:currency_picker/currency_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/settings.dart';
import '../../../widgets/app_chips.dart';
import '../../../widgets/personalization/action_row.dart';
import '../../../widgets/personalization/section_card.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';


/// Appearance (issue #79, finding F3): light / dark / follow system.
///
/// The accent colour is on the Profile screen, next to the name and
/// avatar — both are "how the app is mine". This screen is only the
/// theme, which is a choice about the phone, not about the person.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final repo = ref.read(settingsRepositoryProvider);

    void update(AppSettings Function(AppSettings) fn) {
      repo.updateSettings(fn(settings));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            SectionCard(
              title: 'Theme',
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: AppThemeMode.values.map((mode) {
                    return AppChoiceChip(
                      label: mode.label,
                      leading: Icon(
                        mode.icon,
                        size: 16,
                        color: settings.themeMode == mode
                            ? c.primary
                            : c.onSurfaceVariant,
                      ),
                      selected: settings.themeMode == mode,
                      onTap: () => update((s) => s.copyWith(themeMode: mode)),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              title: 'Currency',
              children: [
                Text(
                  'Fuata uses one currency everywhere. Changing it changes how every '
                      'amount is shown, including units you already have.',
                  style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                ActionRow(
                  icon: Icons.attach_money_rounded,
                  title: 'Currency',
                  subtitle: (() {
                    // CurrencyService.findByCode returns Currency? — null when the
                    // stored code isn't in the package's list (an older backup, a
                    // hand-edited file). Fall back to the code itself.
                    final info = CurrencyService().findByCode(settings.currencyCode);
                    return info == null
                        ? settings.currencyCode
                        : '${info.name} (${info.code})';
                  })(),
                  onTap: () {
                    showCurrencyPicker(
                      context: context,
                      showFlag: false,
                      showCurrencyName: true,
                      showCurrencyCode: true,
                      onSelect: (Currency currency) async {
                        final current = ref.read(currentSettingsProvider);
                        if (current.currencyCode == currency.code) return;
                        await ref.read(settingsRepositoryProvider).updateSettings(
                          current.copyWith(currencyCode: currency.code),
                        );
                        // Settings stream emits first (every screen rebuilds with the
                        // new symbol); units follow a beat later. Amounts never change
                        // — only the code and the symbol.
                        await ref
                            .read(unitRepositoryProvider)
                            .updateAllCurrencies(currency.code);
                      },
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}