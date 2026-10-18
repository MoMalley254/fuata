import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/template_pack_import.dart';
import '../../domain/models/template.dart';
import '../../domain/models/template_pack.dart';
import '../../domain/models/unit.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/providers/capture_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';

/// Preview a pack, pick a unit, and import (issue #34). The bottom-sheet
/// shape is deliberately the same one the rule builder's palette uses —
/// "choose then act" in one gesture, not a full-screen wizard for what is
/// usually a one-tap decision.
class TemplatePackSheet extends ConsumerStatefulWidget {
  const TemplatePackSheet({super.key, required this.pack, required this.units});
  final TemplatePack pack;
  final List<MoneyUnit> units;

  @override
  ConsumerState<TemplatePackSheet> createState() => _TemplatePackSheetState();
}

class _TemplatePackSheetState extends ConsumerState<TemplatePackSheet> {
  late String _unitId = widget.units.first.id;
  bool _importing = false;
  String? _error;

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      // Safe to read `.value` here: `build` watches both providers, so by
      // the time the button can be tapped, both have emitted at least once.
      // `.value ?? const []` also means a provider that somehow arrived
      // empty is treated as "no existing rules", which is the correct
      // behaviour for a first import.
      final templates =
          ref.read(unitTemplatesProvider(_unitId)).value ?? const [];
      final sources = ref.read(captureSourcesProvider).value ?? const [];

      final plan = TemplatePackImporter.plan(
        pack: widget.pack,
        targetUnitId: _unitId,
        existing: templates,
      );

      if (plan.changesNothing) {
        setState(() {
          _importing = false;
          _error = plan.duplicateCount == 1
              ? 'That rule is already on this unit.'
              : 'All ${plan.duplicateCount} rules are already on this unit.';
        });
        return;
      }

      // Timeout so a stuck DB write surfaces as an error instead of an
      // endless spinner. Fifteen seconds is generous for 6 small inserts;
      // anything past it is a bug we want to see.
      final n = await TemplatePackImporter.apply(
        plan: plan,
        sources: sources,
        repo: ref.read(templateRepositoryProvider),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      final unit = widget.units.firstWhere((u) => u.id == _unitId);

      // Grab the messenger before popping: `context` belongs to the sheet
      // and is no longer valid for showing a snackbar after the route
      // starts closing.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            n == 1
                ? 'Added 1 rule to ${unit.name}.'
                : 'Added $n rules to ${unit.name}.',
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = 'Saving took too long. Nothing was written — please try again.';
      });
    } catch (e) {
      print('Unable to save $e');
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = 'Could not save the rules, please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Watched so the providers stay subscribed while the sheet is open.
    // Without this, `_import`'s ref.read is the only reference to the
    // family provider — and on the very first tap it can still be in
    // AsyncLoading, which is what the previous "can't read your rules"
    // bug was, and what the `.future` fix turned into a hang. Watching
    // here means the button is enabled only once the data is in hand.
    final templatesAsync = ref.watch(unitTemplatesProvider(_unitId));
    final sourcesAsync = ref.watch(captureSourcesProvider);
    final providersReady =
        !templatesAsync.isLoading && !sourcesAsync.isLoading;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: c.outlineVariant,
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                      ),
                    ),
                  ),
                  Text(
                    widget.pack.name,
                    style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                  ),
                  if (widget.pack.description != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.pack.description!,
                      style: AppTypography.bodySm
                          .copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                children: [
                  Text(
                    'These rules will be added',
                    style: AppTypography.labelLg.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final t in widget.pack.templates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _TemplateRow(template: t),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Add to which unit?',
                    style: AppTypography.labelLg.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final u in widget.units)
                        AppChoiceChip(
                          label: '${u.iconEmoji} ${u.name}',
                          selected: _unitId == u.id,
                          onTap: () => setState(() => _unitId = u.id),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: AppTypography.bodySm
                          .copyWith(color: c.statusDanger),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      // Disabled while either provider is still loading. The person can't
                      // tap import before there's something to compare against, so
                      // `_import` never has to reason about AsyncLoading.
                      onPressed: (_importing || !providersReady) ? null : _import,
                      child: _importing
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(
                        widget.pack.templates.length == 1
                            ? 'Add this rule'
                            : 'Add these ${widget.pack.templates.length} rules',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});
  final PackTemplate template;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.name,
                  style: AppTypography.labelLg.copyWith(color: c.onSurface),
                ),
              ),
              Text(
                switch (template.direction) {
                  TemplateDirection.spent => 'out',
                  TemplateDirection.got => 'in',
                  TemplateDirection.either => 'auto',
                },
                style: AppTypography.labelSm
                    .copyWith(color: c.onSurfaceTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            template.sampleText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}