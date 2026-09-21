import 'package:flutter/material.dart';

import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

enum MoneyUnit { cash, mobileMoney, bank, card }

class UnitCard extends StatelessWidget {
  const UnitCard({
    super.key,
    required this.unit,
    required this.title,
    required this.balance,
    this.emoji,
    this.currencySymbol = '\$',
    this.onTap,
  });

  final MoneyUnit unit;
  final String title;
  final double balance;
  final String? emoji;
  final String currencySymbol;
  final VoidCallback? onTap;

  Color _accent(AppColors c) => switch (unit) {
    MoneyUnit.cash => c.unitCash,
    MoneyUnit.mobileMoney => c.unitMobileMoney,
    MoneyUnit.bank => c.unitBank,
    MoneyUnit.card => c.unitCard,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = _accent(c);

    return SizedBox(
      width: 130,
      height: 100,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
              border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: emoji != null
                            ? Text(emoji!, style: const TextStyle(fontSize: 18))
                            : Icon(Icons.account_balance_wallet_rounded,
                            size: 18, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd
                              .copyWith(color: c.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '$currencySymbol${_fmt(balance)}',
                    style: AppTypography.headlineSm.copyWith(
                      color: c.onSurface,
                      fontFeatures: AppTypography.numericKeypad.fontFeatures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return v < 0 ? '-${buf.toString()}' : buf.toString();
  }
}