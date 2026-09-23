import 'package:flutter/material.dart';

import '../../domain/models/limit_rule.dart';
import 'app_colors.dart';

/// Presentation for SpendStatus (domain/models/limit_rule.dart).
///
/// SpendStatus itself stays pure Dart (no Flutter imports) so the ledger
/// and limit engine are unit-testable without a device — see design.md,
/// "domain layer is pure Dart". Icon and colour, which need Flutter and
/// the theme, live here instead. There is deliberately only ONE status
/// enum in the app; this used to be a second enum (BudgetStatus) that
/// duplicated SpendStatus — removed to avoid the two drifting apart.
extension SpendStatusStyle on SpendStatus {
  /// Icon glyph — never rely on colour alone (a11y).
  IconData get icon => switch (this) {
    SpendStatus.safe => Icons.check_circle_rounded,
    SpendStatus.warning => Icons.report_problem_rounded,
    SpendStatus.danger => Icons.gpp_bad_rounded,
    SpendStatus.overdraft => Icons.trending_down_rounded,
  };

  Color fg(AppColors c) => switch (this) {
    SpendStatus.safe => c.statusSafe,
    SpendStatus.warning => c.statusWarning,
    SpendStatus.danger => c.statusDanger,
    SpendStatus.overdraft => c.statusOverdraft,
  };

  Color bg(AppColors c) => switch (this) {
    SpendStatus.safe => c.statusSafeContainer,
    SpendStatus.warning => c.statusWarningContainer,
    SpendStatus.danger => c.statusDangerContainer,
    SpendStatus.overdraft => c.statusOverdraftContainer,
  };

  Color border(AppColors c) => switch (this) {
    SpendStatus.safe => c.statusSafeBorder,
    SpendStatus.warning => c.statusWarningBorder,
    SpendStatus.danger => c.statusDangerBorder,
    SpendStatus.overdraft => c.statusOverdraftBorderFallback,
  };
}

extension on AppColors {
  // statusOverdraftBorder has no dedicated token yet (see app_colors.dart);
  // derive one the same way the old BudgetStatus extension did.
  Color get statusOverdraftBorderFallback =>
      Color.lerp(statusOverdraft, Colors.white, 0.55)!.withValues(alpha: 0.5);
}