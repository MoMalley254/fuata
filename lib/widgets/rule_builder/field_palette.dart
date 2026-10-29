import 'package:flutter/material.dart';
import 'package:fuata/ui/theme/app_colors.dart';

import '../../data/constants/rule_builder_constants.dart';
import '../../domain/models/template.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../app_chips.dart';
import '../dialogs/enter_custom_field_name_dialog.dart';

class FieldPalette extends StatelessWidget {
  final String selectionText;
  final Set<String> existingCustomNames;

  const FieldPalette({
    super.key,
    required this.selectionText,
    this.existingCustomNames = const {},
  });

  Future<void> _addCustom(BuildContext context) async {
    final selection = await askForCustomFieldName(
      context,
      existingCustomNames: existingCustomNames,
    );
    if (selection != null && context.mounted) {
      Navigator.of(context).pop(selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadiusHero),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'What is “$selectionText”?',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (type, name, desc) in palette)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          Navigator.of(context).pop(FieldSelection(type)),
                      borderRadius: BorderRadius.circular(AppSpacing.pill),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: WordLabelChip.fieldTint(
                            name,
                            c,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppSpacing.pill),
                          border: Border.all(
                            color: WordLabelChip.fieldTint(
                              name,
                              c,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: AppTypography.labelMd.copyWith(
                                color: WordLabelChip.fieldTint(name, c),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              desc,
                              style: AppTypography.bodySm.copyWith(
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                AppChoiceChip(
                  label: '+ Add my own field',
                  selected: false,
                  onTap: () => _addCustom(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FieldSelection {
  final TemplateFieldType type;
  final String? customName;

  const FieldSelection(this.type, {this.customName});

  const FieldSelection.custom(String name)
    : type = TemplateFieldType.custom,
      customName = name;
}

Future<FieldSelection?> askForCustomFieldName(
  BuildContext context, {
  required Set<String> existingCustomNames,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => CustomFieldNameDialog(existing: existingCustomNames),
  );
  return name == null ? null : FieldSelection.custom(name);
}
