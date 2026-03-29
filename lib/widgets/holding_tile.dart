// ─────────────────────────────────────────────────────────────────────────────
// holding_tile.dart
//
// PURPOSE: A single row in the PortfolioScreen holdings list. Shows the stock
//          ticker, shares owned, current market value, and unrealised P&L
//          colour-coded green (profit) or red (loss).
//
// USED IN: PortfolioScreen (_HoldingsTab)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/portfolio_holding.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';

class HoldingTile extends StatelessWidget {
  final PortfolioHolding holding;

  /// The matching live stock from MarketProvider (used for current price).
  final Stock stock;

  /// Called when the user taps the tile (navigates to StockDetailScreen).
  final VoidCallback onTap;

  const HoldingTile({
    super.key,
    required this.holding,
    required this.stock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final double currentValue = holding.currentValue(stock.currentPrice);
    final double pnl = holding.unrealizedPnl(stock.currentPrice);
    final double pnlPct = holding.unrealizedPnlPercent(stock.currentPrice);
    final bool isProfitable = pnl >= 0;

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
            // ── Left: Ticker + share count ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holding.ticker, style: AppTheme.ticker),
                  const SizedBox(height: 2),
                  Text(
                    stock.companyName,
                    style: AppTheme.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${holding.shares} share${holding.shares == 1 ? '' : 's'}  •  avg ${currencyFormat.format(holding.averageCost)}',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),

            // ── Right: Current value + P&L ──────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Current total value of the position.
                Text(
                  currencyFormat.format(currentValue),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                // Unrealised P&L in dollars and percentage.
                Text(
                  '${isProfitable ? '+' : ''}${currencyFormat.format(pnl)} '
                  '(${isProfitable ? '+' : ''}${pnlPct.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isProfitable ? AppTheme.positive : AppTheme.negative,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
