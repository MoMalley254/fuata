import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/money.dart';
import '../ui/providers/app_providers.dart';

/// One place that renders an amount on screen, so "Hide amounts in the
/// app" (issue #81, finding F7) can't be honoured on one screen and
/// forgotten on the next.
///
/// When the setting is on, the amount is replaced by [kHiddenAmountMask]
/// and any currency symbol is dropped with it — the acceptance test for
/// #81 is that no "KSh" survives while hidden.
class AmountText extends ConsumerWidget {
  const AmountText({
    super.key,
    required this.minor,
    required this.currencyCode,
    this.showSign = false,
    this.style,
    this.textAlign,
  });

  /// Minor units (ADR-003), signed as stored.
  final int minor;
  final String currencyCode;

  /// "+" for money in, "-" for money out — same convention as
  /// [Money.format]'s `showSign`.
  final bool showSign;

  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;
    return Text(
      hidden
          ? kHiddenAmountMask
          : Money(minor, currencyCode).format(showSign: showSign),
      style: style,
      textAlign: textAlign,
    );
  }
}