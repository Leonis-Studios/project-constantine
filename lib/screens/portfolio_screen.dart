// ─────────────────────────────────────────────────────────────────────────────
// portfolio_screen.dart
//
// PURPOSE: Two-tab view of the user's financial position.
//
// TAB 1 — Holdings:
//   • PortfolioSummaryCard at the top (total value, P&L, cash, invested)
//   • ListView of HoldingTile — each row shows one owned stock
//   • Tapping a tile navigates to StockDetailScreen
//   • Empty state message if the portfolio has no holdings
//
// TAB 2 — History:
//   • Chronological list of every buy and sell transaction
//   • Each row shows: BUY/SELL chip, ticker, shares, price, total, timestamp
//   • Empty state if no transactions have been made yet
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/holding_tile.dart';
import '../widgets/portfolio_summary_card.dart';
import 'stock_detail_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // DefaultTabController manages the selected tab index locally.
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // ── Tab bar ───────────────────────────────────────────────────────
          TabBar(
            tabs: [
              Tab(text: 'Holdings'),
              Tab(text: 'History'),
            ],
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textSecondary,
          ),
          Divider(height: 1),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              children: [
                _HoldingsTab(),
                _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Holdings Tab ──────────────────────────────────────────────────────────────

class _HoldingsTab extends StatelessWidget {
  const _HoldingsTab();

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final portfolio = context.watch<PortfolioProvider>();

    if (portfolio.holdings.isEmpty) {
      // Empty state — user hasn't bought anything yet.
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'Your portfolio is empty.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Go to Market and buy some stocks!',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Summary card at the very top.
        PortfolioSummaryCard(
          portfolio: portfolio,
          stocks: market.stocks,
        ),
        const SizedBox(height: 8),

        // One HoldingTile per owned stock.
        ...portfolio.holdings.map((holding) {
          // Look up current price from the market provider.
          final stock = market.stockByTicker(holding.ticker);
          if (stock == null) return const SizedBox.shrink();

          return HoldingTile(
            holding: holding,
            stock: stock,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StockDetailScreen(ticker: holding.ticker),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final portfolio = context.watch<PortfolioProvider>();
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat('MMM d, h:mm a');

    if (portfolio.transactions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'No transactions yet.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: portfolio.transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
      itemBuilder: (context, index) {
        final tx = portfolio.transactions[index];
        final isBuy = tx.type == TransactionType.buy;

        return ListTile(
          // BUY / SELL chip on the left.
          leading: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isBuy
                  ? AppTheme.positiveFaint
                  : AppTheme.negativeFaint,
              borderRadius:
                  BorderRadius.circular(AppTheme.badgeRadius),
            ),
            child: Text(
              isBuy ? 'BUY' : 'SELL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isBuy ? AppTheme.positive : AppTheme.negative,
              ),
            ),
          ),
          // Ticker and share count.
          title: Text(
            '${tx.ticker}  ×${tx.shares}',
            style: AppTheme.ticker.copyWith(fontSize: 14),
          ),
          // Price per share.
          subtitle: Text(
            '${currencyFormat.format(tx.pricePerShare)} / share  •  ${dateFormat.format(tx.timestamp)}',
            style: AppTheme.caption,
          ),
          // Total amount on the right.
          trailing: Text(
            currencyFormat.format(tx.totalAmount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isBuy ? AppTheme.negative : AppTheme.positive,
            ),
          ),
        );
      },
    );
  }
}
