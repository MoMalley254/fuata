import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/money.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../widgets/status_ring_card.dart';
import '../../widgets/unit_card.dart';
import '../../widgets/transaction_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onToggleMode});
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            onPressed: onToggleMode,
            icon: const Icon(Icons.brightness_6_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: homeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Something went wrong: $e')),
          data: (state) => state.units.isEmpty
              ? const _EmptyHome()
              : _HomeContent(state: state),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddTransaction(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openAddTransaction(BuildContext context) {
    // Wired up properly in issue #9 (add-transaction sheet).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add transaction — coming in #9')),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeState state;
  const _HomeContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        AppSpacing.sm,
        AppSpacing.margin,
        100,
      ),
      children: [
        const _Greeting(name: 'Amina'), // TODO: from settings (#12)
        const SizedBox(height: AppSpacing.lg),
        _HeroSection(state: state),
        const SizedBox(height: AppSpacing.lg),
        Text('My money', style: AppTypography.headlineSm.copyWith(color: context.colors.onSurface)),
        const SizedBox(height: AppSpacing.gutterSm),
        _UnitRow(state: state),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Lately', style: AppTypography.headlineSm.copyWith(color: context.colors.onSurface)),
            TextButton(onPressed: () {}, child: const Text('See all')),
          ],
        ),
        if (state.lately.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Nothing yet today. Nice and calm.',
              style: AppTypography.bodyMd.copyWith(color: context.colors.onSurfaceVariant),
            ),
          )
        else
          ...state.lately.map((t) => TransactionRow(
            title: t.counterparty ?? state.units.firstWhere((u) => u.id == t.unitId).name,
            subtitle: _friendlyTime(t.occurredAt),
            amount: Money(t.amountMinor, state.units.firstWhere((u) => u.id == t.unitId).currencyCode)
                .majorValue,
            emoji: state.units.firstWhere((u) => u.id == t.unitId).iconEmoji,
            accent: state.units.firstWhere((u) => u.id == t.unitId).color,
          )),
      ],
    );
  }

  String _friendlyTime(DateTime t) {
    final now = DateTime.now();
    final isToday = t.year == now.year && t.month == now.month && t.day == now.day;
    if (isToday) return DateFormat('h:mm a').format(t);
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        t.year == yesterday.year && t.month == yesterday.month && t.day == yesterday.day;
    if (isYesterday) return 'yesterday';
    return DateFormat('EEE, d MMM').format(t);
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  const _Greeting({required this.name});

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
            Text('Hi $name 👋', style: AppTypography.headlineLg.copyWith(color: c.onSurface)),
            Text(today, style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
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
class _HeroSection extends StatelessWidget {
  final HomeState state;
  const _HeroSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final limit = state.dailyLimit;
    final currency = state.units.isNotEmpty ? state.units.first.currencyCode : 'KES';
    final symbol = currencySymbol(currency);

    if (limit == null) {
      final c = context.colors;
      final total = state.balanceByUnit.values.fold(0, (a, b) => a + b);
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
            Text('Altogether you have', style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Money(total, currency).format(),
              style: AppTypography.displayHeroMobile.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Set a daily limit to see how today is going.',
                style: AppTypography.bodySm.copyWith(color: c.onSurfaceVariant)),
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

class _UnitRow extends StatelessWidget {
  final HomeState state;
  const _UnitRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.units.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gutterSm),
        itemBuilder: (context, i) {
          if (i == state.units.length) {
            return _AddUnitCard(onTap: () {});
          }
          final unit = state.units[i];
          final balance = state.balanceByUnit[unit.id] ?? 0;
          return UnitCard(
            kind: unit.kind,
            title: unit.name,
            balance: Money(balance, unit.currencyCode).majorValue,
            emoji: unit.iconEmoji,
            currencySymbol: currencySymbol(unit.currencyCode),
          );
        },
      ),
    );
  }
}

class _AddUnitCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddUnitCard({required this.onTap});

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

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

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