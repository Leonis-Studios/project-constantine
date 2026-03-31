// ─────────────────────────────────────────────────────────────────────────────
// stock_tile.dart
//
// PURPOSE: A single row in the MarketOverviewScreen stock list. Displays the
//          ticker, company name, sector chip, current price, change badge,
//          and a compact 7-day sparkline.
//
// Tapping the tile calls the [onTap] callback provided by the parent screen,
// which typically navigates to StockDetailScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stock.dart';
import '../theme/app_theme.dart';
import 'price_change_badge.dart';
import 'sparkline_chart.dart';

class StockTile extends StatelessWidget {
  final Stock stock;

  /// Called when the user taps an unlocked tile.
  final VoidCallback onTap;

  /// When true, the tile is greyed out and trading is blocked.
  final bool isLocked;

  /// The portfolio value needed to unlock this stock (shown on locked tiles).
  final double? unlockThreshold;

  /// Whether this stock is in the player's watchlist.
  final bool isWatched;

  /// Callback to toggle watchlist status. If null, no star icon is shown.
  final VoidCallback? onToggleWatch;

  const StockTile({
    super.key,
    required this.stock,
    required this.onTap,
    this.isLocked = false,
    this.unlockThreshold,
    this.isWatched = false,
    this.onToggleWatch,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final sparklinePrices = stock.priceHistory.length > 7
        ? stock.priceHistory.sublist(stock.priceHistory.length - 7)
        : stock.priceHistory;

    return InkWell(
      onTap: isLocked
          ? () {
              final threshold = unlockThreshold != null
                  ? NumberFormat.currency(symbol: '\$', decimalDigits: 0)
                      .format(unlockThreshold)
                  : 'a higher portfolio value';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Reach $threshold total portfolio value to unlock ${stock.ticker}.',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          : onTap,
      child: Opacity(
        opacity: isLocked ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // ── Left: Ticker + company name ───────────────────────────────
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(stock.ticker, style: AppTheme.ticker),
                        if (isLocked) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                        ],
                        if (onToggleWatch != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onToggleWatch,
                            child: Icon(
                              isWatched ? Icons.star : Icons.star_outline,
                              size: 14,
                              color: isWatched
                                  ? AppTheme.accent
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stock.companyName,
                      style: AppTheme.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isLocked && unlockThreshold != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppTheme.badgeRadius),
                        ),
                        child: Text(
                          'Unlocks at ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(unlockThreshold)}',
                          style: AppTheme.caption,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius:
                              BorderRadius.circular(AppTheme.badgeRadius),
                        ),
                        child: Text(
                          stock.sector,
                          style: AppTheme.caption,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Centre: 7-day sparkline ───────────────────────────────────
              if (sparklinePrices.length >= 2)
                SizedBox(
                  width: 64,
                  height: 36,
                  child: SparklineChart(
                    prices: sparklinePrices,
                    isPositive: stock.isPositive,
                    height: 36,
                    showAxes: false,
                  ),
                ),

              const SizedBox(width: 12),

              // ── Right: Price + change badge ───────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(stock.currentPrice),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PriceChangeBadge(changePercent: stock.changePercent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
