// ─────────────────────────────────────────────────────────────────────────────
// portfolio_screen.dart
//
// PURPOSE: Two-tab view of the user's financial position.
//
// TAB 1 — Holdings:
//   • PortfolioSummaryCard at the top
//   • Long holdings (HoldingTile)
//   • Short positions (ShortPositionTile) with a section header
//   • Empty state if no long or short positions
//
// TAB 2 — History:
//   • All transactions: BUY (green), SELL (red), SHORT (amber), COVER (blue)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/holding_tile.dart';
import '../widgets/short_position_tile.dart';
import '../widgets/portfolio_summary_card.dart';
import 'stock_detail_screen.dart';

// Amber for SHORT chip.
const _kShortAmber = Color(0xFFE3B341);

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        children: [
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

    final hasLongs = portfolio.holdings.isNotEmpty;
    final hasShorts = portfolio.shortPositions.isNotEmpty;

    if (!hasLongs && !hasShorts) {
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
              'Go to Market and buy or short some stocks!',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        PortfolioSummaryCard(
          portfolio: portfolio,
          stocks: market.stocks,
        ),
        const SizedBox(height: 8),

        // ── Long holdings ───────────────────────────────────────────────────
        if (hasLongs) ...[
          if (hasShorts)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'LONG POSITIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ...portfolio.holdings.map((holding) {
            final stock = market.stockByTicker(holding.ticker);
            if (stock == null) return const SizedBox.shrink();
            return HoldingTile(
              holding: holding,
              stock: stock,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StockDetailScreen(ticker: holding.ticker),
                ),
              ),
            );
          }),
        ],

        // ── Short positions ─────────────────────────────────────────────────
        if (hasShorts) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'SHORT POSITIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _kShortAmber,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...portfolio.shortPositions.map((position) {
            final stock = market.stockByTicker(position.ticker);
            if (stock == null) return const SizedBox.shrink();
            return ShortPositionTile(
              position: position,
              stock: stock,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StockDetailScreen(ticker: position.ticker),
                ),
              ),
            );
          }),
        ],
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

        // Chip colour + label per transaction type.
        final Color chipBg;
        final Color chipFg;
        final String chipLabel;
        final Color amountColor;

        switch (tx.type) {
          case TransactionType.buy:
            chipBg = AppTheme.positiveFaint;
            chipFg = AppTheme.positive;
            chipLabel = 'BUY';
            amountColor = AppTheme.negative; // cash out
          case TransactionType.sell:
            chipBg = AppTheme.negativeFaint;
            chipFg = AppTheme.negative;
            chipLabel = 'SELL';
            amountColor = AppTheme.positive; // cash in
          case TransactionType.short:
            chipBg = _kShortAmber.withValues(alpha: 0.15);
            chipFg = _kShortAmber;
            chipLabel = 'SHORT';
            amountColor = AppTheme.positive; // received cash
          case TransactionType.cover:
            chipBg = AppTheme.accent.withValues(alpha: 0.15);
            chipFg = AppTheme.accent;
            chipLabel = 'COVER';
            amountColor = AppTheme.negative; // paid cash
        }

        return ListTile(
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
            ),
            child: Text(
              chipLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: chipFg,
              ),
            ),
          ),
          title: Text(
            '${tx.ticker}  ×${tx.shares}',
            style: AppTheme.ticker.copyWith(fontSize: 14),
          ),
          subtitle: Text(
            '${currencyFormat.format(tx.pricePerShare)} / share  •  ${dateFormat.format(tx.timestamp)}',
            style: AppTheme.caption,
          ),
          trailing: Text(
            currencyFormat.format(tx.totalAmount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
          ),
        );
      },
    );
  }
}
