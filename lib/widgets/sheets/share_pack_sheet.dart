import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/logic/template_pack_codec.dart';
import '../../domain/models/template.dart';
import '../../domain/models/template_pack.dart';
import '../../domain/models/unit.dart';
import '../../platform/backup_files.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/providers/backup_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../personalization/action_row.dart';

/// Share a unit's rules as a pack (issue #34). Two routes: a file the
/// receiver opens via Settings → Message reading packs → import, or a QR
/// they scan in the same place. The QR is bounded by its capacity — the
/// sheet says so rather than showing an unscannable code.
///
/// NOTE: this sheet is hosted by flutter_smart_dialog, so its `BuildContext`
/// has **no Navigator ancestor**. Never call `showDialog`/`Navigator.of`
/// with it — render any follow-up UI inline in this sheet instead.
Future<void> showSharePackSheet({
  required String unitId,
  required List<CaptureTemplate> templates,
}) {
  return SmartDialog.show(
    builder: (_) => _SharePackSheet(unitId: unitId, templates: templates),
  );
}

class _SharePackSheet extends ConsumerStatefulWidget {
  const _SharePackSheet({required this.unitId, required this.templates});
  final String unitId;
  final List<CaptureTemplate> templates;

  @override
  ConsumerState<_SharePackSheet> createState() => _SharePackSheetState();
}

class _SharePackSheetState extends ConsumerState<_SharePackSheet> {
  bool _busy = false;

  /// Set once the user asks for a QR: the compact payload to encode, or an
  /// explanation of why it can't be encoded. Rendered inline — pushing a
  /// route from this context would fail (no Navigator ancestor).
  String? _qrPayload;
  String? _qrError;
  String _qrTitle = '';

  TemplatePack _buildPack(String unitName) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return TemplatePack(
      id: 'exported_$ts',
      name: '$unitName rules',
      templates: [
        for (final t in widget.templates)
          PackTemplate(
            name: t.name,
            direction: t.direction,
            pattern: t.pattern,
            fieldMap: t.fieldMap,
            sampleText: t.sampleText,
            enabled: t.enabled,
          ),
      ],
    );
  }

  String _suggestedFileName(String unitName) {
    final safe = unitName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final d = DateFormat('yyyyMMdd').format(DateTime.now());
    return 'fuata-pack-${safe.isEmpty ? 'rules' : safe}-$d.json';
  }

  Future<void> _saveToFile() async {
    // Capture the messenger *before* dismissing: once SmartDialog removes
    // this sheet the context is deactivated and lookups on it throw.
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final unitName = _unitName();
      final pack = _buildPack(unitName);
      final content = TemplatePackCodec.encode(pack);
      final saved = await ref.read(backupFilesProvider).saveText(
        suggestedName: _suggestedFileName(unitName),
        content: content,
      );
      SmartDialog.dismiss();
      if (saved) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Saved. The receiver imports it from Settings → Message reading packs.',
            ),
          ),
        );
      }
    } on BackupFileException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showQr() {
    final unitName = _unitName();
    final pack = _buildPack(unitName);
    final payload = TemplatePackCodec.encodeCompact(pack);
    // 2500 bytes is comfortably under the L-error-correction ceiling
    // (2953) and leaves the code small enough to be readable on a
    // phone screen. Beyond that the person is better off sharing a file.
    const maxQrBytes = 2500;
    final utf8Len = payload.length;

    setState(() {
      _qrTitle = pack.name;
      if (utf8Len > maxQrBytes) {
        _qrPayload = null;
        _qrError =
        'This pack is $utf8Len bytes — more than a single QR can carry '
            'reliably. Share it as a file instead; the receiver imports it '
            'the same way.';
      } else {
        _qrError = null;
        _qrPayload = payload;
      }
    });
  }

  String _unitName() =>
      _resolveUnitName(ref.read(unitsProvider).value ?? const []);

  String _resolveUnitName(List<MoneyUnit> units) {
    for (final u in units) {
      if (u.id == widget.unitId) return u.name;
    }
    return 'rules';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.templates.length;

    // Watched to keep the units provider alive while the share sheet is
    // open — `_saveToFile` and `_showQr` read it to name the file after
    // the unit, and a cold-start race would otherwise fall back to
    // "rules" in the filename.
    final unitsAsync = ref.watch(unitsProvider);
    final unitName = _resolveUnitName(unitsAsync.value ?? const []);

    final showingQr = _qrPayload != null || _qrError != null;

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
            if (showingQr)
              ..._buildQrView(c)
            else
              ..._buildChooser(c, unitName, n),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChooser(AppColors c, String unitName, int n) {
    return [
      Text(
        'Share these rules',
        style: AppTypography.headlineSm.copyWith(color: c.onSurface),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        n == 1
            ? 'One rule will be shared. The receiver adds it to a unit '
            'of their own.'
            : '$n rules will be shared. The receiver adds them to a '
            'unit of their own.',
        style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
      ),
      const SizedBox(height: AppSpacing.md),
      ActionRow(
        icon: Icons.save_outlined,
        title: 'Save as a file',
        subtitle: 'A .json pack the receiver opens in Fuata',
        // _busy guard, expressed the way ActionRow allows
        onTap: () {
          if (_busy) return;
          _saveToFile();
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      ActionRow(
        icon: Icons.qr_code_rounded,
        title: 'Show as a QR',
        subtitle: 'The receiver scans it in Fuata',
        // _busy guard, expressed the way ActionRow allows
        onTap: () {
          if (_busy) return;
          _showQr();
        },
      ),
    ];
  }

  List<Widget> _buildQrView(AppColors c) {
    final error = _qrError;
    if (error != null) {
      return [
        Text(
          'Too big for a QR',
          style: AppTypography.headlineSm.copyWith(color: c.onSurface),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          error,
          style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => SmartDialog.dismiss(),
            child: const Text('OK'),
          ),
        ),
      ];
    }

    return [
      Text(
        'Scan this to get $_qrTitle',
        style: AppTypography.headlineSm.copyWith(color: c.onSurface),
      ),
      const SizedBox(height: AppSpacing.md),
      Center(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: QrImageView(
            data: _qrPayload!,
            version: QrVersions.auto,
            size: 260,
            // Lowest error correction: the pack is at the edge of QR
            // capacity, and a screen-to-camera read at arm's length
            // doesn't need the redundancy of H. If a code doesn't
            // scan, "share as file" is the fallback.
            errorCorrectionLevel: QrErrorCorrectLevel.L,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Open Fuata → Settings → Message reading packs → Scan a QR.',
        textAlign: TextAlign.center,
        style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => SmartDialog.dismiss(),
          child: const Text('Close'),
        ),
      ),
    ];
  }
}