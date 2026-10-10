import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/category.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/label.dart';

/// Add/edit sheet: name, emoji, colour. Nothing else — an id is derived on
/// save (new) or kept (edit).
class CategorySheet extends ConsumerStatefulWidget {
  const CategorySheet({super.key, this.existing});
  final Category? existing;

  @override
  ConsumerState<CategorySheet> createState() => CategorySheetState();
}

class CategorySheetState extends ConsumerState<CategorySheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _emoji = widget.existing?.emoji ?? '🍲';
  late Color _color = widget.existing?.color ?? const Color(0xFFE07A5F);
  bool _saving = false;
  String? _error;

  static const _emojiOptions = [
    '🍲', '🚌', '📶', '🧾', '🏠', '🛍️', '💊', '🎬', '📦',
    '🍔', '☕', '🛒', '🚗', '⛽', '✈️', '🎓', '💡', '💧',
  ];

  static const _palette = [
    Color(0xFFE07A5F),
    Color(0xFF277DA1),
    Color(0xFF7B5EA7),
    Color(0xFF2E9E6B),
    Color(0xFF9A442D),
    Color(0xFFE8A317),
    Color(0xFFB3123F),
    Color(0xFF3D7FE0),
    Color(0xFF6E7978),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final existing = widget.existing;
    final nextSortOrder = existing?.sortOrder ??
        (ref.read(allCategoriesProvider).value?.length ?? 0);
    final cat = Category(
      id: existing?.id ?? 'cat_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      emoji: _emoji,
      color: _color,
      sortOrder: nextSortOrder,
      archived: existing?.archived ?? false,
    );

    try {
      await ref.read(categoryRepositoryProvider).saveCategory(cat);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
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
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                  widget.existing == null
                      ? 'New category'
                      : 'Edit ${widget.existing!.name}',
                  style: AppTypography.headlineSm.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(hintText: 'What is it?'),
                  style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: AppSpacing.md),
                const Label('Icon'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final e in _emojiOptions)
                      InkWell(
                        onTap: () => setState(() => _emoji = e),
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _emoji == e
                                ? c.primary.withValues(alpha: 0.15)
                                : c.surfaceContainer,
                            border: Border.all(
                              color: _emoji == e
                                  ? c.primary
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(e, style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Label('Colour'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final swatch in _palette)
                      InkWell(
                        onTap: () => setState(() => _color = swatch),
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: swatch,
                            border: Border.all(
                              color: _color.toARGB32() == swatch.toARGB32()
                                  ? c.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: AppTypography.bodySm.copyWith(color: c.statusDanger),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(widget.existing == null ? 'Add' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}