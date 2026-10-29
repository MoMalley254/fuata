import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/constants/preset_template_packs.dart';
import '../../domain/logic/template_pack_codec.dart';
import '../../domain/models/template_pack.dart';
import '../../domain/models/unit.dart';
import '../../platform/backup_files.dart';
import '../../widgets/sheets/template_pack_sheet.dart';
import '../providers/app_providers.dart';
import '../providers/backup_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'qr_scan_screen.dart';

/// Message reading packs (issue #34).
///
/// Two jobs, deliberately the same screen: browse what the app already
/// ships, and bring a pack in from outside (file or QR). The person sees
/// "M-PESA Kenya · 6 rules" as one thing either way; splitting "browse
/// presets" and "import a pack" into two screens would make the second
/// feel like a system operation instead of the same kind of thing.
class TemplatePacksScreen extends ConsumerWidget {
  const TemplatePacksScreen({super.key});

  Future<void> _openPack(
    BuildContext context,
    WidgetRef ref,
    TemplatePack pack,
  ) async {
    final allUnits = ref.read(unitsProvider).value ?? const <MoneyUnit>[];
    final units = allUnits.where((u) => !u.archived).toList();
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Add some money first — a pack's rules belong to a unit.",
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatePackSheet(pack: pack, units: units),
    );
  }

  Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
    try {
      final text = await ref.read(backupFilesProvider).pickText();
      if (text == null) return;
      if (!context.mounted) return;
      _handleIncoming(context, ref, text, 'file');
    } on BackupFileException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _scanQr(BuildContext context, WidgetRef ref) async {
    final text = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (text == null) return;
    if (!context.mounted) return;
    _handleIncoming(context, ref, text, 'QR');
  }

  void _handleIncoming(
    BuildContext context,
    WidgetRef ref,
    String text,
    String source,
  ) {
    final result = TemplatePackCodec.decode(text);
    if (!result.ok || result.pack == null) {
      final message = result.errors.isEmpty
          ? "That $source didn't hold a Fuata pack."
          : result.errors.first;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _openPack(context, ref, result.pack!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    // Watched so the "from someone else" import buttons can be disabled
    // while units are loading — otherwise the first tap in a cold start
    // hits `_openPack` before `unitsProvider` has emitted, and the person
    // is told to "add some money" they already have.
    final unitsAsync = ref.watch(unitsProvider);
    final unitsReady = unitsAsync.hasValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message reading packs'),
        actions: [
          IconButton(
            tooltip: 'Import a pack from a file',
            icon: const Icon(Icons.file_open_outlined),
            onPressed: unitsReady ? () => _importFromFile(context, ref) : null,
          ),
          IconButton(
            tooltip: 'Scan a pack',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: unitsReady ? () => _scanQr(context, ref) : null,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin,
            AppSpacing.sm,
            AppSpacing.margin,
            AppSpacing.xl,
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What\'s a pack?',
                    style: AppTypography.labelLg.copyWith(color: c.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'A ready-made set of message reading rules — one rule per '
                    'message shape. Add a pack to a unit and Fuata starts '
                    'reading that provider\'s messages straight away. Nothing '
                    'is caught until you confirm it.',
                    style: AppTypography.bodySm.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Built-in packs',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final pack in presetTemplatePacks) ...[
              _PackTile(pack: pack, onTap: () => _openPack(context, ref, pack)),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'From someone else',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A friend can share a pack with you as a file, or show you a '
              'QR. Use the icons above to import one — the rules land in a '
              'unit of your choosing, and their unit does not come with it.',
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({required this.pack, required this.onTap});
  final TemplatePack pack;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = pack.templates.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: c.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.name,
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    if (pack.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        pack.description!,
                        style: AppTypography.bodySm.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      n == 1 ? '1 rule' : '$n rules',
                      style: AppTypography.labelSm.copyWith(
                        color: c.onSurfaceTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
