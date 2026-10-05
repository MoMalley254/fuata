import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../../domain/models/settings.dart';
import '../../routing/routes.dart';
import '../../widgets/activity/grouped_list.dart';
import '../../widgets/sheets/add_transaction_sheet.dart';
import '../../widgets/sheets/edit_unit_sheet.dart';
import 'summary_screen.dart';
import '../providers/app_providers.dart';
import '../providers/capture_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../widgets/status_ring_card.dart';
import '../../widgets/unit_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeStateProvider);
    final settings = ref.watch(currentSettingsProvider);
    final inboxCount = ref.watch(reviewInboxCountProvider);
    final pendingCount = ref.watch(pendingTransactionsProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        // Theme toggling moved to Me → Appearance (#12); it belongs with
        // the rest of personalisation rather than living on its own here.
      ),
      body: SafeArea(
        child: homeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Something went wrong: $e')),
          data: (state) => state.units.isEmpty
              ? const EmptyHome()
              : HomeContent(
                  state: state,
                  settings: settings,
                  inboxCount: inboxCount,
                  pendingCount: pendingCount,
                  onSeeAllActivity: () =>
                      StatefulNavigationShell.of(context).goBranch(1),
                  onOpenInbox: () => context.push(Routes.inboxPath),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTransactionSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final HomeState state;
  final AppSettings settings;
  final int inboxCount;
  final int pendingCount;
  final VoidCallback? onSeeAllActivity;
  final VoidCallback? onOpenInbox;
  const HomeContent({
    super.key,
    required this.state,
    required this.settings,
    this.inboxCount = 0,
    this.pendingCount = 0,
    this.onSeeAllActivity,
    this.onOpenInbox,
  });

  @override
  Widget build(BuildContext context) {
    final showUnits = settings.homeSections.contains(HomeSection.units);
    final showLately = settings.homeSections.contains(HomeSection.lately);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.sm,
        AppSpacing.margin,
        100,
      ),
      children: [
        Greeting(name: settings.name),
        if (inboxCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          _InboxNudge(
            inboxCount: inboxCount,
            pendingCount: pendingCount,
            onTap: onOpenInbox,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        HeroSection(state: state, headline: settings.homeHeadline),
        if (showUnits) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'My money',
            style: AppTypography.headlineSm.copyWith(
              color: context.colors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.gutterSm),
          UnitRow(state: state),
        ],
        if (showLately) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lately',
                style: AppTypography.headlineSm.copyWith(
                  color: context.colors.onSurface,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push(Routes.summaryPath),
                icon: const Icon(Icons.insights_rounded),
                label: const Text('See my summaries'),
              ),
            ],
          ),
          if (state.lately.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Nothing yet today. Nice and calm.',
                style: AppTypography.bodyMd.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            )
          else
            GroupedList(
              transactions: state.lately,
              unitById: {for (final u in state.units) u.id: u},
            ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SummaryScreen())),
            icon: const Icon(Icons.insights_rounded),
            label: const Text('See my summaries'),
          ),
        ),
      ],
    );
  }

  String _friendlyTime(DateTime t) {
    final now = DateTime.now();
    final isToday =
        t.year == now.year && t.month == now.month && t.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(t);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        t.year == yesterday.year &&
        t.month == yesterday.month &&
        t.day == yesterday.day;
    if (isYesterday) return 'yesterday';
    return DateFormat('EEE, d MMM').format(t);
  }
}

/// design.md's status field rule: Home shows "N waiting to confirm" when
/// captures are sitting in the review inbox (#21). Tapping opens it.
class _InboxNudge extends StatelessWidget {
  final int inboxCount;
  final int pendingCount;
  final VoidCallback? onTap;
  const _InboxNudge({
    required this.inboxCount,
    required this.pendingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Two voices, because "waiting for your check" is a lie when the only
    // thing in there is a message Fuata couldn't read.
    final message = pendingCount > 0
        ? '$inboxCount caught from your messages — tap to check'
        : "$inboxCount I couldn't read — tap to teach me";

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
            border: Border.all(color: c.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.mark_email_unread_rounded, color: c.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMd.copyWith(color: c.onSurface),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class Greeting extends StatelessWidget {
  final String name;
  const Greeting({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateFormat('EEEE, d MMM').format(DateTime.now());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // Onboarding lets the name be skipped; don't greet "Hi  👋".
              name.trim().isEmpty ? 'Hi there 👋' : 'Hi $name 👋',
              style: AppTypography.headlineLg.copyWith(color: c.onSurface),
            ),
            Text(
              today,
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
        CircleAvatar(
          backgroundColor: c.surfaceContainerHigh,
          child: Icon(Icons.person, color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The most important widget in the app: one glance answers
/// "Am I okay today?" (ui-design-brief.md section 7.2).
/// Uses the real StatusRingCard when a daily limit is set; falls back to
/// a plain total when it isn't (StatusRingCard assumes a limit exists).
class HeroSection extends StatelessWidget {
  final HomeState state;
  final HomeHeadline headline;
  const HeroSection({
    super.key,
    required this.state,
    this.headline = HomeHeadline.leftToday,
  });

  @override
  Widget build(BuildContext context) {
    final limit = state.dailyLimit;
    final currency = state.units.isNotEmpty
        ? state.units.first.currencyCode
        : 'KES';
    final symbol = currencySymbol(currency);
    final total = state.balanceByUnit.values.fold(0, (a, b) => a + b);

    // "Left today" is the ring's native story and needs a limit to mean
    // anything; the other two headlines (total / spent today) always
    // have a number to show, so they get the plain card even when a
    // limit exists. Making every headline drive the ring itself (so the
    // *number* on it changes while the *progress* stays spend-based) is
    // future polish, flagged rather than done partially here.
    if (limit == null || headline != HomeHeadline.leftToday) {
      final c = context.colors;
      final (label, amountMinor, caption) = switch (headline) {
        HomeHeadline.leftToday => (
          'Altogether you have',
          total,
          'Set a daily limit to see how today is going.',
        ),
        HomeHeadline.totalIHave => (
          'Altogether you have',
          total,
          'Across everything you\'ve told Fuata about.',
        ),
        HomeHeadline.spentToday => (
          'Spent today',
          state.spentToday,
          limit == null
              ? 'Set a daily limit to see how today is going.'
              : 'of ${Money(limit.amountMinor, currency).format()} · resets at midnight',
        ),
      };
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadiusHero),
          border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Money(amountMinor, currency).format(),
              style: AppTypography.displayHeroMobile.copyWith(
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption,
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return StatusRingCard(
      remaining: Money(state.leftToday, currency).majorValue,
      spent: Money(state.spentToday, currency).majorValue,
      limit: Money(limit.amountMinor, currency).majorValue,
      status: state.status,
      currencySymbol: symbol,
    );
  }
}

class UnitRow extends StatelessWidget {
  final HomeState state;
  const UnitRow({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.units.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.gutterSm),
        itemBuilder: (context, i) {
          if (i == state.units.length) {
            return AddUnitCard(onTap: () => showEditUnitSheet(context));
          }
          final unit = state.units[i];
          final balance = state.balanceByUnit[unit.id] ?? 0;
          return UnitCard(
            kind: unit.kind,
            title: unit.name,
            balance: Money(balance, unit.currencyCode).majorValue,
            emoji: unit.iconEmoji,
            currencySymbol: currencySymbol(unit.currencyCode),
            onTap: () => context.push(Routes.unitFor(unit.id)),
          );
        },
      ),
    );
  }
}

class AddUnitCard extends StatelessWidget {
  final VoidCallback onTap;
  const AddUnitCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          border: Border.all(color: c.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.add, color: c.onSurfaceVariant),
      ),
    );
  }
}

class EmptyHome extends StatelessWidget {
  const EmptyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👋', style: TextStyle(fontSize: 40)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Add your first bit of money to get started.',
              style: AppTypography.headlineSm.copyWith(color: c.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
