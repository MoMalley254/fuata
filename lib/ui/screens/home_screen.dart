import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/logic/summary.dart';
import '../../domain/models/money.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/unit.dart';
import '../../routing/routes.dart';
import '../../widgets/activity/grouped_list.dart';
import '../../widgets/amount_text.dart';
import '../../widgets/home/week_peek.dart';
import '../../widgets/personalization/amount_visibility_toggle.dart';
import '../../widgets/provider_error_card.dart';
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
          error: (e, st) => ProviderErrorCard(
            headline: "Couldn't load your money right now",
            error: e,
            onRetry: () => ref.invalidate(homeStateProvider),
          ),
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
                  onReorderUnits: (ids) =>
                      ref.read(unitRepositoryProvider).reorderUnits(ids),
                ),
        ),
      ),
      // #116: the + adds a transaction, which needs a unit to attach to.
      // On a fresh install there is nothing to attach to, so the Empty Home
      // state carries the only action that works — adding the first unit.
      floatingActionButton: (homeAsync.value?.units.isNotEmpty ?? false)
          ? FloatingActionButton(
              onPressed: () => showAddTransactionSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
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

  /// Issue #117: called with every unit id in its new order after a
  /// long-press drag on the My money row. Null turns reordering off.
  final ValueChanged<List<String>>? onReorderUnits;
  const HomeContent({
    super.key,
    required this.state,
    required this.settings,
    this.inboxCount = 0,
    this.pendingCount = 0,
    this.onSeeAllActivity,
    this.onOpenInbox,
    this.onReorderUnits,
  });

  @override
  Widget build(BuildContext context) {
    final showUnits = settings.homeSections.contains(HomeSection.units);
    final showLately = settings.homeSections.contains(HomeSection.lately);
    final showWeekPeek = settings.homeSections.contains(HomeSection.weekPeek);

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
          UnitRow(state: state, onReorder: onReorderUnits),
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
        if (showWeekPeek) ...[
          const SizedBox(height: AppSpacing.lg),
          WeekPeekCard(
            spentByDay: state.spentByDay,
            dailyLimit: state.dailyLimit,
            currencyCode: state.units.isNotEmpty
                ? state.units.first.currencyCode
                : 'KES',
            // Opens the same Summary the button below does, at the week view.
            // The query-parameter form is how the router already reads it (see
            // app_router.dart's summary route), so this adds no new shape.
            onTap: () => context.push(
              '${Routes.summaryPath}?period=${SummaryPeriod.week.name}',
            ),
          ),
        ],
        // Issue #112: one "See my summaries" on Home, never two. With Lately
        // on it lives in that section's header; this one is only the way in
        // when Lately is off.
        if (!showLately) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SummaryScreen())),
              icon: const Icon(Icons.insights_rounded),
              label: const Text('See my summaries'),
            ),
          ),
        ],
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
        // The avatar is how you reach your profile now that name and
        // accent live on their own screen (#79, F3). It's an IconButton
        // rather than a bare CircleAvatar so the tap target is the full
        // 48dp minimum and the tooltip gives it a name for screen
        // readers — "Profile" rather than the icon's own "person", which
        // reads the right word but the wrong meaning.
        IconButton(
          tooltip: 'Profile',
          onPressed: () => context.push(Routes.profilePath),
          icon: CircleAvatar(
            backgroundColor: c.surfaceContainerHigh,
            child: Icon(Icons.person, color: c.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The most important widget in the app: one glance answers
/// "Am I okay today?" (ui-design-brief.md section 7.2).
/// Uses the real StatusRingCard when a daily limit is set; falls back to
/// a plain total when it isn't (StatusRingCard assumes a limit exists).
class HeroSection extends ConsumerWidget {
  final HomeState state;
  final HomeHeadline headline;
  const HeroSection({
    super.key,
    required this.state,
    this.headline = HomeHeadline.leftToday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      final hidden = ref.watch(currentSettingsProvider).amountsHidden;
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

      // Issue #110: pick the starting size from the text that will
      // actually be shown (the same one AmountText formats), so a
      // 9-figure balance starts smaller instead of relying on
      // FittedBox to shrink it out of legibility.
      final displayText = hidden
          ? kHiddenAmountMask
          : Money(amountMinor, currency).format();
      final numberStyle = _heroStyleFor(displayText, c.onSurface);

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
            // Issue #110: the card's content width is about 272 dp on
            // a 360 dp phone, where displayHeroMobile fits roughly
            // thirteen characters. FittedBox covers the rest.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                minor: amountMinor,
                currencyCode: currency,
                style: numberStyle,
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

  /// Issue #110: same thresholding as
  /// [StatusRingCard._heroNumberStyle], tuned to the wider plain card
  /// (no ring, so more room before the number has to shrink).
  static TextStyle _heroStyleFor(String displayText, Color color) {
    final base = displayText.length <= 13
        ? AppTypography.displayHeroMobile
        : AppTypography.headlineLg;
    return base.copyWith(color: color);
  }
}

/// The horizontal "My money" row on Home. Long-press a card and drag it to
/// reorder (#117); a plain tap still opens the unit. Pass a null
/// [onReorder] for the plain, non-draggable row.
class UnitRow extends StatefulWidget {
  final HomeState state;
  final ValueChanged<List<String>>? onReorder;
  const UnitRow({super.key, required this.state, this.onReorder});

  @override
  State<UnitRow> createState() => _UnitRowState();
}

class _UnitRowState extends State<UnitRow> {
  // The order on screen. Saving goes through the database and comes back
  // on a stream, a beat after the drop; without a local copy the card
  // would snap back to its old slot and then jump. Reset only when a
  // genuinely new list arrives, so an unrelated rebuild can't undo a drop.
  late List<MoneyUnit> _units = List.of(widget.state.units);

  @override
  void didUpdateWidget(UnitRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.state.units, widget.state.units)) {
      _units = List.of(widget.state.units);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    // ReorderableListView reports newIndex as if the dragged item were
    // still in the list; moving later shifts everything down one.
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;
    setState(() => _units.insert(newIndex, _units.removeAt(oldIndex)));
    widget.onReorder?.call([for (final u in _units) u.id]);
  }

  Widget _card(BuildContext context, MoneyUnit unit) {
    final balance = widget.state.balanceByUnit[unit.id] ?? 0;
    return UnitCard(
      kind: unit.kind,
      title: unit.name,
      balance: Money(balance, unit.currencyCode).majorValue,
      emoji: unit.iconEmoji,
      currencySymbol: currencySymbol(unit.currencyCode),
      onTap: () => context.push(Routes.unitFor(unit.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addCard = AddUnitCard(onTap: () => showEditUnitSheet(context));

    if (widget.onReorder == null) {
      return SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _units.length + 1,
          separatorBuilder: (_, _) =>
              const SizedBox(width: AppSpacing.gutterSm),
          itemBuilder: (context, i) =>
              i == _units.length ? addCard : _card(context, _units[i]),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        // Long-press on every platform (the default shows a drag handle on
        // desktop, which a card this small has no room for).
        buildDefaultDragHandles: false,
        itemCount: _units.length,
        onReorderStart: (_) => HapticFeedback.mediumImpact(),
        onReorder: _onReorder,
        // A transparent Material can't cast a shadow, so the lifted card is
        // just nudged larger.
        proxyDecorator: (child, _, _) => Transform.scale(
          scale: 1.05,
          child: Material(color: Colors.transparent, child: child),
        ),
        itemBuilder: (context, i) {
          final unit = _units[i];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(unit.id),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.gutterSm),
              child: _card(context, unit),
            ),
          );
        },
        // Not draggable, and always last.
        footer: addCard,
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
      child: SingleChildScrollView(
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
            const SizedBox(height: AppSpacing.lg),
            // #116: a real action, not a dead end. The floating + adds a
            // transaction, which needs a unit to attach to — so the first
            // thing to do is add the unit itself.
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => showEditUnitSheet(context),
                child: const Text('Add some money'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Want Fuata to catch payments for you? Turn on Auto-catch '
              'in Settings.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
