import 'package:flutter/material.dart';
import 'package:fuata/widgets/personalization/section_card.dart';

import '../../domain/models/settings.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'label.dart';

class ProfileBlock extends StatefulWidget {
  final AppSettings settings;
  final void Function(AppSettings Function(AppSettings)) onChanged;
  const ProfileBlock({super.key, required this.settings, required this.onChanged});

  @override
  State<ProfileBlock> createState() => _ProfileBlockState();
}

class _ProfileBlockState extends State<ProfileBlock> {
  late final _nameController = TextEditingController(text: widget.settings.name);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _commitName() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty || trimmed == widget.settings.name) return;
    widget.onChanged((s) => s.copyWith(name: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SectionCard(
      title: 'Profile',
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: widget.settings.accent.withValues(alpha: 0.18),
              child: Text(
                widget.settings.name.isEmpty
                    ? '🙂'
                    : widget.settings.name.substring(0, 1).toUpperCase(),
                style: AppTypography.headlineSm.copyWith(color: widget.settings.accent),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _nameController,
                onSubmitted: (_) => _commitName(),
                onTapOutside: (_) => _commitName(),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Your name'),
                style: AppTypography.bodyLg.copyWith(color: c.onSurface),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Label('Accent colour'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: AppAccents.swatches.map((swatch) {
            final selected = widget.settings.accent.toARGB32() == swatch.toARGB32();
            return InkWell(
              onTap: () => widget.onChanged((s) => s.copyWith(accent: swatch)),
              borderRadius: BorderRadius.circular(AppSpacing.pill),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: swatch,
                  border: Border.all(
                    color: selected ? c.onSurface : Colors.transparent,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // A free-pick custom colour needs a colour-picker widget this
          // project doesn't have yet — flagged rather than silently
          // dropped, same pattern as the currency picker in
          // edit_unit_sheet.dart.
          'A custom colour picker is coming later — pick the closest one for now.',
          style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}