import 'package:flutter/material.dart';
import 'package:fuata/widgets/personalization/section_card.dart';

import '../../data/constants/keep_alive_guides.dart';
import '../../platform/notification_capture.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Keep Fuata running (issue #36): the manufacturer-specific steps that
/// stop a phone's battery manager from killing the notification listener.
///
/// Shows the entry for this phone's manufacturer (Build.MANUFACTURER), or
/// the generic fallback. Static content, no permissions. Reachable from
/// the Auto-catch screen at any time and from its "looks inactive" state.
class KeepAliveGuideScreen extends StatefulWidget {
  const KeepAliveGuideScreen({super.key});

  @override
  State<KeepAliveGuideScreen> createState() => _KeepAliveGuideScreenState();
}

class _KeepAliveGuideScreenState extends State<KeepAliveGuideScreen> {
  late final Future<String?> _manufacturer = getDeviceManufacturer();

  Future<void> _open(SettingsTarget target) async {
    final opened = await openSystemSettings(target);
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This phone doesn’t have that screen. Look for it in Settings.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Keep Fuata running')),
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: _manufacturer,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }
            final guide = keepAliveGuideFor(snapshot.data);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                AppSpacing.xl,
              ),
              children: [
                SectionCard(
                  title: guide.name,
                  children: [
                    Text(
                      guide.intro,
                      style: AppTypography.bodySm.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < guide.steps.length; i++) ...[
                      _StepRow(
                        number: i + 1,
                        step: guide.steps[i],
                        onOpen: _open,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      _footnote(guide),
                      style: AppTypography.bodySm.copyWith(
                        color: c.onSurfaceTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Vendor menus move between OS versions, and nothing here can promise
  /// capture on every phone (testing.md): say both.
  String _footnote(KeepAliveGuide guide) {
    final checked = guide.checkedOn == null
        ? guide.isFallback
              ? 'Menu names differ between phones.'
              : 'These steps haven’t been checked against a specific '
                    'version of the phone’s software yet, so menu names '
                    'may differ.'
        : 'Last checked on ${guide.checkedOn}. Menu names may differ on '
              'other versions.';
    return '$checked These settings help, but they can’t guarantee that '
        'every payment is caught on every phone.';
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.onOpen,
  });

  final int number;
  final KeepAliveStep step;
  final Future<void> Function(SettingsTarget) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final target = step.target;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            '$number.',
            style: AppTypography.bodyMd.copyWith(color: c.primary),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.text,
                style: AppTypography.bodyMd.copyWith(color: c.onSurface),
              ),
              if (target != null) ...[
                const SizedBox(height: AppSpacing.sm),
                FilledButton.tonal(
                  onPressed: () => onOpen(target),
                  child: Text(step.targetLabel ?? 'Open settings'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
