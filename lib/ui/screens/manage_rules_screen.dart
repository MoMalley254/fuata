import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../../widgets/rule_builder/rules_body.dart';
import '../theme/app_typography.dart';

/// Manage the message-reading rules for a unit  #20.
///
/// The unit page's "Reading messages" row used to say "N rules · add or
/// review" but only supported "add" — tapping it opened the rule builder
/// directly. This screen is the "review" half: it lists every template
/// saved for [unitId], lets the person enable/disable each one and
/// delete ones they no longer want, and links into the builder to add
/// another. It's the only place `deleteTemplate` and
/// `CaptureTemplate.enabled` are actually used.
class ManageRulesScreen extends ConsumerWidget {
  final String unitId;
  const ManageRulesScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unitsAsync = ref.read(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Rules'),
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator.adaptive(),),
          error: (e, st) => Center(
            child: Text(
              'Something went wrong: $e'
            ),
          ),
          data: (units) {
            final unit = units.where((u) => u.id == unitId).firstOrNull;
            if (unit == null) {
              return Center(
                child: Text(
                  "This unit's gone.",
                  style:
                  AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
                ),
              );
            }
            return RulesBody(unit: unit);
          }
        ),
      ),
    );
  }
}