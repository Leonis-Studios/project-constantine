// ─────────────────────────────────────────────────────────────────────────────
// stock_detail_screen.dart
//
// PURPOSE: Full-page detail view for a single stock. Shows the current price,
//          a price history chart, company info, the user's holding, and buy/sell
//          buttons that open the BuySellBottomSheet.
//
// RECEIVES: a `ticker` string from the navigation push in MarketOverviewScreen.
//
// LAYOUT (single scrollable Column):
//   1. Price header — large price, change badge, previous close
//   2. Sparkline chart — fl_chart line chart over priceHistory
//   3. Company info card — name, sector, description
//   4. Holdings card — shares owned, avg cost, unrealised P&L
//   5. Buy / Sell buttons
//   6. Recent events — last 5 events that mention this ticker
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/price_change_badge.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/event_card.dart';
import '../widgets/buy_sell_bottom_sheet.dart';
import '../models/transaction.dart';

class StockDetailScreen extends StatelessWidget {
  /// The ticker symbol of the stock to display.
  final String ticker;

  const StockDetailScreen({super.key, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final portfolio = context.watch<PortfolioProvider>();

    // Look up the stock — if somehow not found, show an error.
    final Stock? stock = market.stockByTicker(ticker);
    if (stock == null) {
      return Scaffold(
        appBar: AppBar(title: Text(ticker)),
        body: const Center(child: Text('Stock not found.')),
      );
    }

    final holding = portfolio.holdingForTicker(ticker);
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Filter events log to only those affecting this specific ticker.
    final relatedEvents = market.events
        .where((e) => e.affectedTicker == ticker)
        .take(5) // show the 5 most recent events for this stock
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stock.ticker, style: AppTheme.ticker),
            Text(stock.companyName, style: AppTheme.companyName),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Price Header ─────────────────────────────────────────────
            _PriceHeader(stock: stock),

            const SizedBox(height: 4),

            // ── 2. Price Chart ──────────────────────────────────────────────
            // Only render the chart if we have more than one data point.
            if (stock.priceHistory.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SparklineChart(
                  prices: stock.priceHistory,
                  isPositive: stock.isPositive,
                  height: 180,
                  showAxes: true, // show Y-axis labels in detail mode
                ),
              ),

            const SizedBox(height: 8),

            // ── 3. Company Info ─────────────────────────────────────────────
            _InfoCard(
              title: 'About',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sector chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
                    ),
                    child: Text(
                      stock.sector,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(stock.description, style: AppTheme.companyName),
                ],
              ),
            ),

            // ── 4. Holdings Card ────────────────────────────────────────────
            _InfoCard(
              title: 'Your Position',
              child: holding == null
                  // User doesn't own this stock yet.
                  ? Text(
                      "You don't own any ${stock.ticker} shares yet.",
                      style: AppTheme.companyName,
                    )
                  // Show position details.
                  : Column(
                      children: [
                        _StatRow(
                          label: 'Shares Owned',
                          value: '${holding.shares}',
                        ),
                        _StatRow(
                          label: 'Avg Cost',
                          value: currencyFormat
                              .format(holding.averageCost),
                        ),
                        _StatRow(
                          label: 'Current Value',
                          value: currencyFormat
                              .format(holding.currentValue(stock.currentPrice)),
                        ),
                        _StatRow(
                          label: 'Unrealised P&L',
                          value:
                              '${currencyFormat.format(holding.unrealizedPnl(stock.currentPrice))}'
                              ' (${holding.unrealizedPnlPercent(stock.currentPrice).toStringAsFixed(2)}%)',
                          valueColor: holding.unrealizedPnl(stock.currentPrice) >= 0
                              ? AppTheme.positive
                              : AppTheme.negative,
                        ),
                      ],
                    ),
            ),

            // ── 5. Buy / Sell Buttons ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Buy button — always enabled.
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openBuySell(
                          context, stock, TransactionType.buy, portfolio),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.positive,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Buy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sell button — disabled if user owns no shares.
                  Expanded(
                    child: ElevatedButton(
                      onPressed: holding == null
                          ? null // disabled — nothing to sell
                          : () => _openBuySell(
                              context, stock, TransactionType.sell, portfolio),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.negative,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.negative.withValues(alpha: 0.3),
                      ),
                      child: const Text('Sell'),
                    ),
                  ),
                ],
              ),
            ),

            // ── 6. Recent Events ────────────────────────────────────────────
            if (relatedEvents.isNotEmpty) ...[
              const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Recent News', style: AppTheme.headline),
              ),
              ...relatedEvents.map((event) => EventCard(event: event)),
            ],
          ],
        ),
      ),
    );
  }

  /// Opens the BuySellBottomSheet modal for the given transaction type.
  void _openBuySell(
    BuildContext context,
    Stock stock,
    TransactionType type,
    PortfolioProvider portfolio,
  ) {
    showModalBottomSheet(
      context: context,
      // isScrollControlled allows the sheet to grow taller than 50% of screen.
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.cardRadius),
        ),
      ),
      builder: (_) => BuySellBottomSheet(
        stock: stock,
        type: type,
        portfolio: portfolio,
      ),
    );
  }
}

// ── Price Header Widget ───────────────────────────────────────────────────────
//
// Displays the large current price, change badge, and previous close.
// Extracted into a private widget to keep the main build() method readable.

class _PriceHeader extends StatelessWidget {
  final Stock stock;
  const _PriceHeader({required this.stock});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large current price.
          Text(
            currencyFormat.format(stock.currentPrice),
            style: AppTheme.priceDisplay,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Coloured change badge (e.g., "+2.4% / +$3.40")
              PriceChangeBadge(
                changePercent: stock.changePercent,
                changeAmount: stock.changeAmount,
                showAmount: true,
              ),
              const SizedBox(width: 12),
              Text(
                'Prev. close: ${currencyFormat.format(stock.previousPrice)}',
                style: AppTheme.caption,
              ),
            ],
          ),
          if (stock.isInUptrend || stock.isInDowntrend) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  stock.isInUptrend ? Icons.trending_up : Icons.trending_down,
                  size: 13,
                  color: stock.isInUptrend ? AppTheme.positive : AppTheme.negative,
                ),
                const SizedBox(width: 4),
                Text(
                  '${stock.isInUptrend ? "UPTREND" : "DOWNTREND"} · ${stock.trendDaysRemaining}d remaining',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: stock.isInUptrend ? AppTheme.positive : AppTheme.negative,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Generic Info Card ─────────────────────────────────────────────────────────
//
// A titled card container used for the "About" and "Your Position" sections.

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.label),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Stat Row ──────────────────────────────────────────────────────────────────
//
// A label / value pair used inside the holdings card.

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.companyName),
          Text(
            value,
            style: AppTheme.label.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
