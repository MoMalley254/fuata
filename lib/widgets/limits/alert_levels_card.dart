import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/logic/alert_engine.dart';
import '../../domain/logic/banner_content.dart';
import '../../domain/models/limit_alert.dart';
import '../../domain/models/limit_rule.dart';
import '../../domain/models/money.dart';
import '../../domain/models/settings.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../banner/banner_preview.dart';
import '../personalization/toggle_row.dart';

/// Alert levels and the live banner preview (ui-design-brief.md 7.8,
/// issue #63).
///
/// One pair of sliders sets the levels for *every* limit — the daily, the
/// weekly, and any per-unit ones — because "nudge me at 70%" is a habit,
/// not a per-limit setting. They are stored on each LimitRule (warnAt /
/// dangerAt), so nothing new is persisted for them.
///
/// Dragging only changes local state; the write happens when the finger
/// lifts. Writing on every tick would re-post the banner and re-run alert
/// evaluation dozens of times per drag — and could announce a level the
/// person was merely sliding past.
class AlertLevelsCard extends ConsumerStatefulWidget {
  final List<LimitRule> limits;
  const AlertLevelsCard({super.key, required this.limits});

  @override
  ConsumerState<AlertLevelsCard> createState() => _AlertLevelsCardState();
}

class _AlertLevelsCardState extends ConsumerState<AlertLevelsCard> {
  static const _min = 0.5;
  static const _max = 0.95;
  static const _minGapPercent = 5;

  RangeValues? _draft; // while dragging / until the write lands
  bool _dragging = false;
  double? _tryRatio; // the "if I've spent…" scrubber; null = today's real use

  @override
  void didUpdateWidget(covariant AlertLevelsCard old) {
    super.didUpdateWidget(old);
    // Drop the draft once the stored levels have caught up with it, so the
    // thumbs don't flicker back to the old values between write and stream.
    final d = _draft;
    if (d == null || _dragging) return;
    final (w, dg) = LimitRule.levelsFrom(widget.limits);
    if ((w - d.start).abs() < 0.001 && (dg - d.end).abs() < 0.001) {
      _draft = null;
    }
  }

  Future<void> _save(RangeValues v) async {
    final repo = ref.read(limitRepositoryProvider);
    final warn = (v.start * 100).round() / 100;
    final danger = (v.end * 100).round() / 100;
    try {
      for (final l in widget.limits) {
        if (l.warnAt == warn && l.dangerAt == danger) continue;
        await repo.setLimit(l.copyWith(warnAt: warn, dangerAt: danger));
      }
    } catch (_) {
      if (mounted) setState(() => _draft = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settings = ref.watch(currentSettingsProvider);
    final home = ref.watch(homeStateProvider).value;
    final hasLimits = widget.limits.isNotEmpty;

    final (storedWarn, storedDanger) = LimitRule.levelsFrom(widget.limits);
    // Clamped: a limit saved by older code could hold a level outside the
    // slider's range, and RangeSlider asserts on that.
    final values = _draft ??
        RangeValues(
          storedWarn.clamp(_min, _max).toDouble(),
          storedDanger.clamp(_min, _max).toDouble(),
        );
    String pct(double v) => '${(v * 100).round()}%';

    final daily = widget.limits
        .where((l) =>
    l.scope == LimitScope.overall &&
        l.period == LimitPeriod.day &&
        l.enabled)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ToggleRow(
          title: 'Alerts',
          subtitle: 'Nudge me as I get close to a limit.',
          value: settings.alertsEnabled,
          onChanged: (on) => ref
              .read(settingsRepositoryProvider)
              .updateSettings(settings.copyWith(alertsEnabled: on)),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '${SpendStatus.warning.emoji} Nudge me at ${pct(values.start)}',
          style: AppTypography.bodyMd.copyWith(color: c.onSurface),
        ),
        Text(
          '${SpendStatus.danger.emoji} Warn me at ${pct(values.end)}',
          style: AppTypography.bodyMd.copyWith(color: c.onSurface),
        ),
        Text(
          "${SpendStatus.overdraft.emoji} And when I'm over",
          style: AppTypography.bodyMd.copyWith(color: c.onSurface),
        ),
        RangeSlider(
          values: values,
          min: _min,
          max: _max,
          divisions: ((_max - _min) * 100).round(),
          labels: RangeLabels(pct(values.start), pct(values.end)),
          // Nothing to set the levels *on* until a limit exists.
          onChangeStart: hasLimits ? (_) => _dragging = true : null,
          onChanged: hasLimits
              ? (v) {
            final s = (v.start * 100).round();
            final e = (v.end * 100).round();
            // Keep the two lines apart: "nudge" and "warn" at the same
            // number would make the middle level meaningless.
            if (e - s < _minGapPercent) return;
            setState(() => _draft = v);
          }
              : null,
          onChangeEnd: hasLimits
              ? (v) {
            _dragging = false;
            _save(v);
          }
              : null,
        ),
        if (!hasLimits)
          Text(
            'Set a limit above, then choose when to be nudged.',
            style: AppTypography.labelSm.copyWith(color: c.onSurfaceTertiary),
          ),
        if (daily != null) ...[
          const SizedBox(height: AppSpacing.md),
          _preview(context, daily, values, settings, home),
        ],
      ],
    );
  }

  Widget _preview(
      BuildContext context,
      LimitRule daily,
      RangeValues values,
      AppSettings settings,
      HomeState? home,
      ) {
    final c = context.colors;
    final limit = daily.copyWith(warnAt: values.start, dangerAt: values.end);

    final realRatio = limit.amountMinor <= 0
        ? 0.0
        : (home?.spentToday ?? 0) / limit.amountMinor;
    final ratio = (_tryRatio ?? realRatio).clamp(0.0, 1.2);
    final spent = (limit.amountMinor * ratio).round();

    final content = BannerContent.build(
      status: limit.statusFor(spent),
      spentToday: spent,
      dailyLimit: limit,
      units: home?.units ?? const [],
      balanceByUnit: home?.balanceByUnit ?? const {},
      headline: settings.bannerHeadline,
      unitsMode: settings.bannerUnitsMode,
      selectedUnitIds: settings.bannerUnitIds,
      showProgress: settings.bannerShowProgress,
      showQuickAdd: settings.bannerShowQuickAdd,
      redacted: settings.amountsHidden,
    );

    final level = AlertEngine.levelFor(limit, spent);
    final alertLine = !settings.alertsEnabled
        ? 'Alerts are off.'
        : level == null
        ? 'No alert at this point.'
        : () {
      final t = AlertText.build(LimitAlert(
        limit: limit,
        level: level,
        periodKey: '',
        spentMinor: spent,
      ));
      return "You'd get: ${t.title} — ${t.body}";
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Try it: if I've spent "
              '${settings.amountsHidden ? kHiddenAmountMask : Money(spent, limit.currencyCode).format()} '
              'today',
          style: AppTypography.labelMd.copyWith(color: c.onSurfaceVariant),
        ),
        Slider(
          value: ratio.toDouble(),
          min: 0,
          max: 1.2,
          onChanged: (r) => setState(() => _tryRatio = r),
        ),
        BannerPreview(content: content),
        const SizedBox(height: AppSpacing.sm),
        Text(
          alertLine,
          style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}
