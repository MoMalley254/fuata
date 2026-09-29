import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:intl/intl.dart';

import '../../domain/models/unparsed_capture.dart';
import '../../ui/providers/capture_providers.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';

class UnparsedCard extends ConsumerWidget {
  final UnparsedCapture entry;
  final VoidCallback onTeachMe;
  const UnparsedCard({super.key, required this.entry, required this.onTeachMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c= context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.rawText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd.copyWith(color: c.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'from ${entry.sourcePackage} · '
                      '${DateFormat('d MMM, h:mm a').format(entry.receivedAt)}',
                  style: AppTypography.labelSm
                      .copyWith(color: c.onSurfaceTertiary),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded,
                    size: 16, color: c.onSurfaceTertiary),
                onPressed: () => ref
                    .read(captureRepositoryProvider)
                    .deleteUnparsed(entry.id),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onTeachMe,
              child: const Text('Teach me'),
            ),
          ),
        ],
      ),
    );
  }
}
