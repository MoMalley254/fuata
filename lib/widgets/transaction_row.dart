import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/providers/app_providers.dart';

import '../domain/models/money.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

class TransactionRow extends ConsumerWidget {
  const TransactionRow({
    super.key,
    required this.title,
    required this.amount,
    required this.emoji,
    this.subtitle,
    this.accent,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final double amount;
  final String emoji;
  final Color? accent;
  final VoidCallback? onTap;

  bool get _isInflow => amount >= 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final amountColor = _isInflow ? c.statusSafe : c.onSurface;
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: a.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelLg.copyWith(color: c.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySm
                            .copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                hidden
                    ? kHiddenAmountMask
                    : '${_isInflow ? '+' : '-'}${_fmt(amount.abs())}',
                style: AppTypography.labelLg.copyWith(
                  color: amountColor,
                  fontFeatures: AppTypography.numericKeypad.fontFeatures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}