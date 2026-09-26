import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/widgets/rule_builder/rule_card.dart';

import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/screens/rule_builder_screen.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/action_row.dart';

class RulesBody extends ConsumerWidget {
  final MoneyUnit unit;
  const RulesBody({super.key, required this.unit});

  /// Push (not replace) so the builder's "Saved..." pop returns here and
  /// the new rule shows up in the list immediately, via the stream.
  void _openBuilder(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RuleBuilderScreen(unitId: unit.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final templatesAsync = ref.watch(unitTemplatesProvider(unit.id));

    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, st) => Center(child: Text('Something went wrong: $e')),
      data: (templates) {
        if (templates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No rules yet for ${unit.name}.',
                  style:
                  AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => _openBuilder(context),
                  child: const Text('Teach a message'),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Text(
              'Rules for ${unit.name}',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final t in templates) ...[
              RuleCard(template: t),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.md),
            ActionRow(
              icon: Icons.add_rounded,
              title: 'Teach another message',
              subtitle: 'Add a new reading rule for ${unit.name}',
              onTap: () => _openBuilder(context),
            ),
          ],
        );
      },
    );
  }
}
