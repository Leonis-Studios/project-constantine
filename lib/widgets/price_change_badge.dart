// ─────────────────────────────────────────────────────────────────────────────
// price_change_badge.dart
//
// PURPOSE: A compact coloured badge showing the daily price change as a
//          percentage, with an optional dollar amount alongside it.
//          Green for positive, red for negative.
//
// USED IN:
//   • StockDetailScreen — price header (large, with dollar amount)
//   • StockTile         — compact list row (percentage only)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PriceChangeBadge extends StatelessWidget {
  /// Daily change as a percentage (e.g. 2.4 for +2.4%, -5.1 for -5.1%).
  final double changePercent;

  /// Optional dollar change amount shown alongside the percentage.
  final double? changeAmount;

  /// Whether to display the dollar amount in addition to the percentage.
  final bool showAmount;

  const PriceChangeBadge({
    super.key,
    required this.changePercent,
    this.changeAmount,
    this.showAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = changePercent >= 0;

    // Choose colours based on direction.
    final Color textColor =
        isPositive ? AppTheme.positive : AppTheme.negative;
    final Color bgColor =
        isPositive ? AppTheme.positiveFaint : AppTheme.negativeFaint;

    // Build the label string.
    final String sign = isPositive ? '+' : ''; // negative already has '-'
    final String percentStr =
        '$sign${changePercent.toStringAsFixed(2)}%';

    String label = percentStr;
    if (showAmount && changeAmount != null) {
      final String amtStr =
          '$sign${changeAmount!.toStringAsFixed(2)}';
      label = '$amtStr  ($percentStr)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small arrow icon indicating direction.
          Icon(
            isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: textColor,
            size: 16,
          ),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
