import 'package:flutter/material.dart';

import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_typography.dart';

class StepLabel extends StatelessWidget {
  const StepLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.headlineSm.copyWith(color: context.colors.onSurface),
    );
  }
}
