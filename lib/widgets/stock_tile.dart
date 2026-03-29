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

  /// Called when the user taps the tile.
  final VoidCallback onTap;

  const StockTile({super.key, required this.stock, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Use only the last 7 price history points for the compact sparkline.
    // If we have fewer than 7 points, use all of them.
    final sparklinePrices = stock.priceHistory.length > 7
        ? stock.priceHistory.sublist(stock.priceHistory.length - 7)
        : stock.priceHistory;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // ── Left: Ticker + company name ─────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.ticker, style: AppTheme.ticker),
                  const SizedBox(height: 2),
                  Text(
                    stock.companyName,
                    style: AppTheme.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Sector chip — small coloured label.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.border,
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

            // ── Centre: 7-day sparkline ─────────────────────────────────────
            if (sparklinePrices.length >= 2)
              SizedBox(
                width: 64,
                height: 36,
                child: SparklineChart(
                  prices: sparklinePrices,
                  isPositive: stock.isPositive,
                  height: 36,
                  showAxes: false, // compact mode — no labels
                ),
              ),

            const SizedBox(width: 12),

            // ── Right: Price + change badge ─────────────────────────────────
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
    );
  }
}
