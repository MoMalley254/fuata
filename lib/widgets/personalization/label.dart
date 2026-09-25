
import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_typography.dart';

class Label extends StatelessWidget {
  final String text;
  const Label(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.labelMd.copyWith(color: context.colors.onSurfaceVariant));
  }
}