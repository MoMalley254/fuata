import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/template.dart';
import '../../routing/routes.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

enum _RuleAction { edit, delete }

class RuleCard extends ConsumerWidget {
  final CaptureTemplate template;
  const RuleCard({super.key, required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final titleColor =
    template.enabled ? c.onSurface : c.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openEditor(context),
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border:
            Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: AppTypography.bodyLg.copyWith(color: titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _directionLabel(template.direction),
                      style: AppTypography.bodySm
                          .copyWith(color: c.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: template.enabled,
                onChanged: (v) => ref
                    .read(templateRepositoryProvider)
                    .saveTemplate(template.copyWith(enabled: v)),
              ),
              PopupMenuButton<_RuleAction>(
                tooltip: 'More',
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: c.onSurfaceVariant,
                ),
                onSelected: (a) => _onAction(context, ref, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _RuleAction.edit,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _RuleAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18),
                        SizedBox(width: AppSpacing.sm),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _directionLabel(TemplateDirection d) => switch (d) {
    TemplateDirection.spent => 'Counts as money out',
    TemplateDirection.got => 'Counts as money in',
    TemplateDirection.either => 'Decides per message',
  };

  void _onAction(BuildContext context, WidgetRef ref, _RuleAction action) {
    switch (action) {
      case _RuleAction.edit:
        _openEditor(context);
      case _RuleAction.delete:
        _confirmDelete(context, ref);
    }
  }

  void _openEditor(BuildContext context) {
    context.push(Routes.ruleBuilderEditPath, extra: template);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${template.name}"?'),
        content: const Text(
          "Future messages of this shape won't be read automatically. "
              'You can always teach it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(templateRepositoryProvider).deleteTemplate(template.id);
  }
}