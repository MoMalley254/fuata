import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuata/ui/theme/app_colors.dart';
import 'package:intl/intl.dart';

import '../../domain/logic/capture_review.dart';
import '../../domain/models/category.dart';
import '../../domain/models/money.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/unit.dart';
import '../../platform/banner.dart';
import '../../routing/app_keys.dart';
import '../../ui/providers/app_providers.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../category_chip_row.dart';
import '../sheets/fix_captured_sheet.dart';
import '../sheets/update_balance_sheet.dart';

class PendingCard extends ConsumerStatefulWidget {
  final MoneyTransaction t;
  final MoneyUnit? unit;
  const PendingCard({super.key, required this.t, this.unit});
  @override
  ConsumerState<PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends ConsumerState<PendingCard> {
  late final TextEditingController _noteController;
  Timer? _noteDebounce;
  String? _savedNote;

  List<MoneyTransaction> _childRows(List<MoneyTransaction> all) =>
      all.where((x) => x.parentId == widget.t.id).toList();

  CaptureReview _review() => CaptureReview(
    transactions: ref.read(transactionRepositoryProvider),
    units: ref.read(unitRepositoryProvider),
  );

  /// Returns the freshest version of this transaction, or the one we were
  /// handed if it has disappeared. Note/category writes should always be
  /// applied against the latest snapshot so we never clobber a concurrent
  /// edit (e.g. from the Fix sheet).
  MoneyTransaction latest() {
    final all =
        ref.read(transactionsProvider).value ?? const <MoneyTransaction>[];
    return all.firstWhere((x) => x.id == widget.t.id, orElse: () => widget.t);
  }

  void _sayCouldNotSave(String what) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't save the $what")),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    // Flush any pending note write before confirming, so the note
// travels with the transaction.
    _noteDebounce?.cancel();
    await _saveNote(_noteController.text);
    
    // The same code the capture notification's Accept button runs.
    final result = await _review().accept(widget.t.id);
    // The row is handled either way; its notification has nothing left to ask.
    await BannerPlatform.instance.cancelCapture(widget.t.id);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    // Reconcile (requirements.md section 5): if the balance the message
    // quoted disagrees with the ledger now that this row is in, flag it
    // and offer the adjustment entry immediately.
    final unit = result.unit;
    if (!result.balanceMismatch || unit == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Added to your money.')),
      );
      return;
    }

    // Capture values before the snackbar — `unit` and `computed` are
    // immutables, so the closure below survives the PendingCard being
    // unmounted when confirmTransaction removes t from the pending list.
    final capturedUnit = unit;
    final capturedComputed = result.ledgerBalanceMinor!;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "The message says ${Money(result.quotedBalanceMinor!, unit.currencyCode).format()}, "
          'but the ledger says ${Money(capturedComputed, unit.currencyCode).format()}.',
        ),
        action: SnackBarAction(
          label: 'Update balance',
          onPressed: () {
            ScaffoldMessenger.of(rootNavigatorKey.currentContext!)
                .hideCurrentSnackBar();
            showUpdateBalanceSheet(
              unit: capturedUnit,
              currentBalanceMinor: capturedComputed,
            );
          },
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    await _review().discard(widget.t.id);
    await BannerPlatform.instance.cancelCapture(widget.t.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed.')));
    }
  }

  Future<void> _updateCategory(String? categoryId) async {
    try {
      await ref.read(transactionRepositoryProvider).updateTransaction(
        latest().copyWith(categoryId: categoryId),
      );
    } catch (_) {
      _sayCouldNotSave('category');
    }
  }

  Future<void> _saveNote(String text) async {
    final trimmed = text.trim();
    final next = trimmed.isEmpty ? null : trimmed;
    if (next == _savedNote) return;

    final previous = _savedNote;
    _savedNote = next;               // optimistic

    try {
      await ref.read(transactionRepositoryProvider).updateTransaction(
        latest().copyWith(note: next),
      );
    } catch (_) {
      _savedNote = previous;         // let the next call retry
      _sayCouldNotSave('note');
    }
  }

  void _onNoteChanged() {
    _noteDebounce?.cancel();
    _noteDebounce = Timer(
      const Duration(milliseconds: 500),
          () => _saveNote(_noteController.text),
    );
  }

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.t.note ?? '');
    _savedNote = widget.t.note;
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteDebounce?.cancel();
    _flushNoteOnDispose();
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _flushNoteOnDispose() {
    final text = _noteController.text.trim();
    final next = text.isEmpty ? null : text;
    if (next == _savedNote) return;
    // ref is still valid during dispose (before super.dispose()).
    final repo = ref.read(transactionRepositoryProvider);
    final base = latest();
    // Fire-and-forget: we cannot await inside dispose.
    unawaited(
      repo
          .updateTransaction(base.copyWith(note: next))
          .catchError((_) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hidden = ref.watch(currentSettingsProvider).amountsHidden;
    final c = context.colors;
    final unit = widget.unit;
    final currency = unit?.currencyCode ?? 'KES';

    final amountText = hidden
        ? kHiddenAmountMask
        : Money(widget.t.amountMinor.abs(), currency).format();

    final isInflow = widget.t.amountMinor >= 0;
    final childRows = _childRows(ref.watch(transactionsProvider).value ?? []);
    final feeMinor = childRows.fold<int>(
      0,
      (sum, x) => sum + x.amountMinor.abs(),
    );
    final feeText = feeMinor > 0
        ? ' + ${hidden ? kHiddenAmountMask : Money(feeMinor, currency).format()} fee'
        : '';

    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppSpacing.unitTileRadius),
        border: Border.all(color: c.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (unit?.color ?? c.primary).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unit?.iconEmoji ?? '💰',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${isInflow ? 'Got' : 'Spent'} $amountText$feeText',
                      style: AppTypography.bodyLg.copyWith(color: c.onSurface),
                    ),
                    Text(
                      '${widget.t.counterparty ?? unit?.name ?? 'Unknown'} · '
                      '${unit?.name ?? 'Unknown'} · '
                      '${DateFormat('d MMM, h:mm a').format(widget.t.occurredAt)}',
                      style: AppTypography.bodySm.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            CategoryChipRow(
              categories: categories,
              selectedId: widget.t.categoryId,
              onSelected: _updateCategory,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _noteController,
            minLines: 5,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodySm.copyWith(color: c.onSurface),
            decoration: InputDecoration(
              hintText: 'Add a note',
              hintStyle: AppTypography.bodySm.copyWith(
                color: c.onSurfaceVariant,
              ),
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _action(
                c: c,
                icon: Icons.check_rounded,
                label: 'Looks right',
                color: c.statusSafe,
                onTap: () => _confirm(context),
              ),
              _action(
                c: c,
                icon: Icons.edit_outlined,
                label: 'Fix',
                color: c.onSurfaceVariant,
                onTap: () => showFixCapturedSheet(context, widget.t),
              ),
              _action(
                c: c,
                icon: Icons.close_rounded,
                label: 'Not mine',
                color: c.onSurfaceVariant,
                onTap: () => _delete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action({
    required AppColors c,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: AppTypography.labelMd.copyWith(color: color)),
      ),
    );
  }
}
