import 'package:flutter/material.dart';

import '../../domain/logic/summary.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'summary_card.dart';

/// "Where it went" / "Where it came from": the top few, with "See all"
/// for the rest (ui-design-brief.md 7.11).
class RankedListCard extends StatefulWidget {
  const RankedListCard({
    super.key,
    required this.title,
    required this.items,
    required this.currencyCode,
    required this.emptyText,
    this.previewCount = 3,
  });

  final String title;
  final List<RankedTotal> items;
  final String currencyCode;
  final String emptyText;
  final int previewCount;

  @override
  State<RankedListCard> createState() => _RankedListCardState();
}

class _RankedListCardState extends State<RankedListCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = widget.items;
    final shown = _showAll ? items : items.take(widget.previewCount).toList();

    return SummaryCard(
      title: widget.title,
      child: items.isEmpty
          ? Text(
              widget.emptyText,
              style: AppTypography.bodyMd.copyWith(color: c.onSurfaceVariant),
            )
          : Column(
              children: [
                for (final item in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyLg.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                              Text(
                                item.count == 1 ? '1 time' : '${item.count} times',
                                style: AppTypography.bodySm.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          friendlyMoney(item.minor, widget.currencyCode),
                          style: AppTypography.labelLg.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (items.length > widget.previewCount)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(
                        _showAll ? 'Show less' : 'See all ${items.length}',
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
