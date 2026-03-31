// ─────────────────────────────────────────────────────────────────────────────
// watchlist_screen.dart
//
// PURPOSE: Displays all stocks the player has starred (watchlisted), sorted
//          by today's % change (biggest movers first). Tapping a stock opens
//          StockDetailScreen. Starring/un-starring updates live via the
//          MarketProvider watchlist.
//
// Shows an empty state when nothing is watched.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/stock_definitions.dart';
import '../models/stock.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stock_tile.dart';
import 'stock_detail_screen.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final portfolio = context.watch<PortfolioProvider>();

    // Map watched tickers to their live Stock objects, dropping any that
    // haven't been initialised yet (shouldn't happen but guards against nulls).
    final watchedStocks = market.watchlist
        .map((ticker) {
          try {
            return market.stocks.firstWhere((s) => s.ticker == ticker);
          } catch (_) {
            return null;
          }
        })
        .whereType<Stock>()
        .toList()
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));

    if (watchedStocks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_outline,
              size: 56,
              color: AppTheme.textMuted,
            ),
            SizedBox(height: 16),
            Text(
              'No stocks in your watchlist yet.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tap ★ on any stock to add it.',
              style: AppTheme.caption,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      itemCount: watchedStocks.length,
      itemBuilder: (context, index) {
        final stock = watchedStocks[index];
        final isLocked = !portfolio.isStockUnlocked(stock.ticker);
        final unlockThreshold = kStockDefinitions
            .firstWhere((s) => s.ticker == stock.ticker)
            .unlockThreshold;

        return StockTile(
          stock: stock,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StockDetailScreen(ticker: stock.ticker),
            ),
          ),
          isLocked: isLocked,
          unlockThreshold: unlockThreshold,
          isWatched: true,
          onToggleWatch: () => market.toggleWatchlist(stock.ticker),
        );
      },
    );
  }
}
