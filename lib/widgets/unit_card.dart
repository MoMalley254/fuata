import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/domain/models/unit.dart' show UnitKind;
import 'package:fuata/ui/providers/app_providers.dart';

import '../domain/models/money.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_spacing.dart';
import '../ui/theme/app_typography.dart';

/// Note: this used to declare its own `enum MoneyUnit {cash, mobileMoney,
/// bank, card}`, which collided by name with domain/models/unit.dart's
/// `class MoneyUnit` (the actual unit model). Uses UnitKind — the domain
/// enum already built for exactly this — instead of a second local one.
class UnitCard extends ConsumerWidget {
  const UnitCard({
    super.key,
    required this.kind,
    required this.title,
    required this.balance,
    this.emoji,
    this.currencySymbol = '\$',
    this.onTap,
  });

  final UnitKind kind;
  final String title;
  final double balance;
  final String? emoji;
  final String currencySymbol;
  final VoidCallback? onTap;

  Color _accent(AppColors c) => switch (kind) {
    UnitKind.cash => c.unitCash,
    UnitKind.mobileMoney => c.unitMobileMoney,
    UnitKind.bank => c.unitBank,
    UnitKind.card => c.unitCard,
    UnitKind.other => c.primary,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final accent = _accent(c);
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;

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
              border: Border.all(
                color: c.outlineVariant.withValues(alpha: 0.35),
              ),
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
                            : Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 18,
                                color: accent,
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // A FittedBox so the amount stays on one line and shrinks
                  // to fit rather than wrapping. Two reasons it can be too
                  // wide for the 100 dp slot: a long amount ("KSh 1,234,567"),
                  // and the wider fallback font flutter_test uses when the
                  // bundled PlusJakartaSans isn't loaded. Without this the
                  // Text wraps to two lines and the card's fixed height
                  // overflows (issue #81's widget test hit exactly that).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hidden
                          ? kHiddenAmountMask
                          : '$currencySymbol${_fmt(balance)}',
                      maxLines: 1,
                      softWrap: false,
                      style: AppTypography.headlineSm.copyWith(
                        color: c.onSurface,
                        fontFeatures: AppTypography.numericKeypad.fontFeatures,
                      ),
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
