import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:fuata/widgets/provider_error_card.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/transaction.dart';
import '../../domain/models/unparsed_capture.dart';
import '../../routing/routes.dart';
import '../../widgets/capture_review/all_caught_up.dart';
import '../../widgets/capture_review/pending_card.dart';
import '../../widgets/capture_review/unparsed_card.dart';
import '../../widgets/personalization/label.dart';
import '../providers/app_providers.dart';
import '../providers/capture_providers.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Review inbox (ui-design-brief.md section 7.6, US-09/US-11): everything
/// the app caught from shared or pasted messages (#21 — notifications
/// join the same inbox in #22) waits here as a pending transaction until
/// the person says Looks right, Fix, or Not mine. Messages nothing could
/// read wait under "Couldn't read these", each with a Teach me button
/// into the rule builder (#20). The header toggle auto-accepts new
/// captures straight into the ledger.
class ReviewInboxScreen extends ConsumerWidget {
  const ReviewInboxScreen({super.key});

  /// The paste half of US-09's "no permissions" paths — same CaptureService
  /// as the share target.
  Future<void> _paste(BuildContext context, WidgetRef ref) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Nothing to paste.')));
      }
      return;
    }

    CaptureOutcome outcome;
    try {
      outcome = await ref
          .read(captureServiceProvider)
          .capture(text, source: TxSource.shared);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read that message')));
      }
      return;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case Captured(:final autoAccepted):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              autoAccepted
                  ? 'Caught it — already added to your money.'
                  : 'Caught it — waiting for your check below.',
            ),
          ),
        );
      case CaptureDuplicate():
        messenger.showSnackBar(
          const SnackBar(content: Text('Already caught that one.')),
        );
      case CaptureUnparsed():
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't read that one yet.")),
        );
      case CaptureIgnored():
        messenger.showSnackBar(
          const SnackBar(content: Text('Nothing to paste.')),
        );
    }
  }

  /// Teach me: open the rule builder with this message already pasted,
  /// then try it again — a freshly saved rule usually reads the message
  /// that produced it, in which case the unparsed row retires itself.
  Future<void> _teachMe(
    BuildContext context,
    WidgetRef ref,
    UnparsedCapture entry,
  ) async {
    await context.push<String>(Routes.ruleBuilderNewPath, extra: entry.rawText);
    if (!context.mounted) return;
    final outcome = await ref
        .read(captureServiceProvider)
        .capture(entry.rawText, source: TxSource.shared);
    if (outcome is Captured && context.mounted) {
      await ref.read(captureRepositoryProvider).deleteUnparsed(entry.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Got it now — see it above.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTransactionsProvider);
    final unparsedAsync = ref.watch(unparsedCapturesProvider);
    final settings = ref.watch(currentSettingsProvider);
    final unitsAsync = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caught from my messages'),
        actions: [
          IconButton(
            tooltip: 'Paste a message',
            icon: const Icon(Icons.content_paste_rounded),
            onPressed: () => _paste(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: unitsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your money right now",
            error: e,
            onRetry: () => ref.invalidate(unitsProvider),
          ),
          data: (units) {
            final unitById = {for (final u in units) u.id: u};
            return unparsedAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, st) => ProviderErrorCard(
                headline: "Couldn't load it's activity right now",
                error: e,
                onRetry: () => ref.invalidate(unparsedCapturesProvider),
              ),
              data: (unparsed) {
                final c = context.colors;
                final isEmpty = pending.isEmpty && unparsed.isEmpty;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.margin,
                    AppSpacing.sm,
                    AppSpacing.margin,
                    AppSpacing.xl,
                  ),
                  children: [
                    // Always visible — it's a setting, not a per-capture action.
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-accept new captures',
                                style: AppTypography.bodyMd.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                              Text(
                                'Skips this screen and adds them straight away.',
                                style: AppTypography.bodySm.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: settings.autoAcceptCaptures,
                          onChanged: (v) => ref
                              .read(settingsRepositoryProvider)
                              .updateSettings(
                                settings.copyWith(autoAcceptCaptures: v),
                              ),
                        ),
                      ],
                    ),

                    if (isEmpty)
                      const AllCaughtUp()
                    else ...[
                      if (pending.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Label('Waiting for you · ${pending.length}'),
                        const SizedBox(height: AppSpacing.sm),
                        for (final t in pending) ...[
                          PendingCard(t: t, unit: unitById[t.unitId]),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                      if (unparsed.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Label("Couldn't read these"),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Teach Fuata what one of these means and it will '
                          'read the rest.',
                          style: AppTypography.bodySm.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final entry in unparsed) ...[
                          UnparsedCard(
                            entry: entry,
                            onTeachMe: () => _teachMe(context, ref, entry),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
