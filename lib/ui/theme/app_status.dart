import 'package:flutter/material.dart';

import 'app_colors.dart';

enum BudgetStatus { safe, warning, danger, overdraft }

extension BudgetStatusX on BudgetStatus {
  /// Icon glyph — never rely on color alone (a11y).
  IconData get icon => switch (this) {
    BudgetStatus.safe => Icons.check_circle_rounded,
    BudgetStatus.warning => Icons.report_problem_rounded,
    BudgetStatus.danger => Icons.gpp_bad_rounded,
    BudgetStatus.overdraft => Icons.trending_down_rounded,
  };

  /// Human-scale microcopy used on status pills.
  String get label => switch (this) {
    BudgetStatus.safe => "You're good",
    BudgetStatus.warning => 'Easy now',
    BudgetStatus.danger => 'Almost at your limit',
    BudgetStatus.overdraft => 'Over budget',
  };

  Color fg(AppColors c) => switch (this) {
    BudgetStatus.safe => c.statusSafe,
    BudgetStatus.warning => c.statusWarning,
    BudgetStatus.danger => c.statusDanger,
    BudgetStatus.overdraft => c.statusOverdraft,
  };

  Color bg(AppColors c) => switch (this) {
    BudgetStatus.safe => c.statusSafeContainer,
    BudgetStatus.warning => c.statusWarningContainer,
    BudgetStatus.danger => c.statusDangerContainer,
    BudgetStatus.overdraft => c.statusOverdraftContainer,
  };

  Color border(AppColors c) => switch (this) {
    BudgetStatus.safe => c.statusSafeBorder,
    BudgetStatus.warning => c.statusWarningBorder,
    BudgetStatus.danger => c.statusDangerBorder,
    BudgetStatus.overdraft => c.statusOverdraftBorderFallback,
  };
}

extension on AppColors {
  Color get statusOverdraftBorderFallback =>
      Color.lerp(statusOverdraft, Colors.white, 0.55)!.withValues(alpha: 0.5);
}