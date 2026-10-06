import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fuata/widgets/rule_builder/rule_card.dart';

import '../../domain/models/unit.dart';
import '../../routing/routes.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../personalization/action_row.dart';
import '../personalization/educational_empty_state.dart';

class RulesBody extends ConsumerWidget {
  final MoneyUnit unit;
  const RulesBody({super.key, required this.unit});

  /// Push (not replace) so the builder's "Saved…" pop returns here and the
  /// new rule shows up in the list immediately, via the stream.
  ///
  /// Was a raw `Navigator.push`; #73 moved the app onto go_router, so the
  /// builder is reached through its named route now. The unit travels as a
  /// query parameter, which is what pre-selects it in the builder.
  void _openBuilder(BuildContext context) {
    context.push(Routes.ruleBuilderNewFor(unit.id));
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
          return EducationalEmptyState(
            emoji: '📖',
            headline: 'Teach Fuata to read your bank messages',
            description:
            'A rule shows Fuata what one kind of message looks like, so '
                'it can pull out the amount, who it was to and when.',
            steps: const [
              'Paste a message',
              'Tap the words',
              'Save it',
            ],
            example: const _LabelledExample(),
            primaryLabel: 'Teach a message',
            onPrimary: () => _openBuilder(context),
            footer:
            'Rules stay on this phone. You can switch them off or '
                'delete them any time.',
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

/// The coloured-chip example under the numbered steps: one made-up message
/// with two labelled words, built from the same [WordLabelChip] the rule
/// builder itself uses.
///
/// The point is to show the *shape* of the thing in one line: read a
/// message, tap the words that matter, and each one takes a colour. The two
/// labelled words are the two fields the rule builder's palette puts first
/// (amount, then payee), so the example reads as "this is where you start".
class _LabelledExample extends StatelessWidget {
  const _LabelledExample();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Confirmed.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const WordLabelChip(word: 'Ksh350.00', assignedField: 'Amount'),
          Text(
            'paid to',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
          const WordLabelChip(word: 'JAVA HOUSE', assignedField: 'Payee'),
          Text(
            'on 21/9/26.',
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}