// ─────────────────────────────────────────────────────────────────────────────
// short_position_tile.dart
//
// PURPOSE: A single row in the PortfolioScreen showing an open short position.
//          Mirrors HoldingTile layout but with inverted P&L semantics and an
//          amber "SHORT" badge to visually distinguish it from long positions.
//
// P&L is INVERTED vs. longs:
//   • Green (profit)  = price fell below entry price
//   • Red   (loss)    = price rose above entry price
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/short_position.dart';
import '../models/stock.dart';
import '../theme/app_theme.dart';

// Amber colour for the SHORT badge — distinct from green (profit) and red (loss).
const _kShortAmber = Color(0xFFE3B341);

class ShortPositionTile extends StatelessWidget {
  final ShortPosition position;

  /// The matching live stock from MarketProvider (used for current price).
  final Stock stock;

  /// Called when the user taps the tile (navigates to StockDetailScreen).
  final VoidCallback onTap;

  const ShortPositionTile({
    super.key,
    required this.position,
    required this.stock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final double pnl = position.unrealizedPnl(stock.currentPrice);
    final double pnlPct = position.unrealizedPnlPercent(stock.currentPrice);
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
            // ── Left: Ticker + position info ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(position.ticker, style: AppTheme.ticker),
                      const SizedBox(width: 6),
                      // "SHORT" badge in amber.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kShortAmber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
                          border: Border.all(
                            color: _kShortAmber.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'SHORT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _kShortAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.companyName,
                    style: AppTheme.companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${position.shares} share${position.shares == 1 ? '' : 's'} short  •  entry ${currencyFormat.format(position.entryPrice)}',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),

            // ── Right: Cover cost + P&L ───────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Current cost to cover (market liability).
                Text(
                  currencyFormat.format(position.coverCost(stock.currentPrice)),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                // Unrealised P&L — inverted sign vs. longs.
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
