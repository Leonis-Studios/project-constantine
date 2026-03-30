// ─────────────────────────────────────────────────────────────────────────────
// stock_detail_screen.dart
//
// PURPOSE: Full-page detail view for a single stock. Shows the current price,
//          a price history chart, company info, the user's position(s), and
//          action buttons that open the BuySellBottomSheet.
//
// BUTTON LOGIC:
//   • Locked stock             → all buttons disabled, lock banner shown
//   • No position              → [Buy] [Short]
//   • Has long holding         → [Buy] [Sell]   (Short disabled)
//   • Has short position       → [Cover]         (Buy/Sell disabled)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/stock_definitions.dart';
import '../models/stock.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/price_change_badge.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/event_card.dart';
import '../widgets/buy_sell_bottom_sheet.dart';
import '../models/transaction.dart';

// Amber for short-related buttons.
const _kShortAmber = Color(0xFFE3B341);

class StockDetailScreen extends StatelessWidget {
  final String ticker;

  const StockDetailScreen({super.key, required this.ticker});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final portfolio = context.watch<PortfolioProvider>();

    final Stock? stock = market.stockByTicker(ticker);
    if (stock == null) {
      return Scaffold(
        appBar: AppBar(title: Text(ticker)),
        body: const Center(child: Text('Stock not found.')),
      );
    }

    final holding = portfolio.holdingForTicker(ticker);
    final shortPosition = portfolio.shortForTicker(ticker);
    final isLocked = !portfolio.isStockUnlocked(ticker);
    final unlockThreshold = kStockDefinitions
        .firstWhere((s) => s.ticker == ticker)
        .unlockThreshold;
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    final relatedEvents = market.events
        .where((e) => e.affectedTicker == ticker)
        .take(5)
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
            // ── Lock banner ─────────────────────────────────────────────────
            if (isLocked && unlockThreshold != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppTheme.border,
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Unlocks at ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(unlockThreshold)} portfolio value',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),

            // ── 1. Price Header ─────────────────────────────────────────────
            _PriceHeader(stock: stock),

            const SizedBox(height: 4),

            // ── 2. Price Chart ──────────────────────────────────────────────
            if (stock.priceHistory.length > 1)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SparklineChart(
                  prices: stock.priceHistory,
                  isPositive: stock.isPositive,
                  height: 180,
                  showAxes: true,
                ),
              ),

            const SizedBox(height: 8),

            // ── 3. Company Info ─────────────────────────────────────────────
            _InfoCard(
              title: 'About',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppTheme.badgeRadius),
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

            // ── 4. Long Position Card ───────────────────────────────────────
            if (holding != null)
              _InfoCard(
                title: 'Your Long Position',
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Shares Owned',
                      value: '${holding.shares}',
                    ),
                    _StatRow(
                      label: 'Avg Cost',
                      value: currencyFormat.format(holding.averageCost),
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
                      valueColor:
                          holding.unrealizedPnl(stock.currentPrice) >= 0
                              ? AppTheme.positive
                              : AppTheme.negative,
                    ),
                  ],
                ),
              ),

            // ── 5. Short Position Card ──────────────────────────────────────
            if (shortPosition != null)
              _InfoCard(
                title: 'Your Short Position',
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Shares Shorted',
                      value: '${shortPosition.shares}',
                    ),
                    _StatRow(
                      label: 'Entry Price',
                      value: currencyFormat.format(shortPosition.entryPrice),
                    ),
                    _StatRow(
                      label: 'Cover Cost',
                      value: currencyFormat
                          .format(shortPosition.coverCost(stock.currentPrice)),
                    ),
                    _StatRow(
                      label: 'Unrealised P&L',
                      value:
                          '${currencyFormat.format(shortPosition.unrealizedPnl(stock.currentPrice))}'
                          ' (${shortPosition.unrealizedPnlPercent(stock.currentPrice).toStringAsFixed(2)}%)',
                      valueColor:
                          shortPosition.unrealizedPnl(stock.currentPrice) >= 0
                              ? AppTheme.positive
                              : AppTheme.negative,
                    ),
                  ],
                ),
              ),

            // ── 6. No position hint ─────────────────────────────────────────
            if (holding == null && shortPosition == null && !isLocked)
              _InfoCard(
                title: 'Your Position',
                child: Text(
                  "You don't own any ${stock.ticker} shares yet.",
                  style: AppTheme.companyName,
                ),
              ),

            // ── 7. Action Buttons ───────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: isLocked
                  ? _LockedButtons(ticker: ticker, threshold: unlockThreshold)
                  : shortPosition != null
                      ? _ShortButtons(
                          stock: stock,
                          portfolio: portfolio,
                          shortPosition: shortPosition,
                          shortingUnlocked: portfolio.totalPortfolioValue(market.stocks) >= 1000,
                        )
                      : _LongButtons(
                          stock: stock,
                          portfolio: portfolio,
                          holding: holding,
                          shortingUnlocked: portfolio.totalPortfolioValue(market.stocks) >= 1000,
                        ),
            ),

            // ── 8. Recent Events ────────────────────────────────────────────
            if (relatedEvents.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Recent News', style: AppTheme.headline),
              ),
              ...relatedEvents.map((event) => EventCard(event: event)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Locked buttons ────────────────────────────────────────────────────────────

class _LockedButtons extends StatelessWidget {
  final String ticker;
  final double? threshold;
  const _LockedButtons({required this.ticker, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final label = threshold != null
        ? 'Unlocks at ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(threshold)}'
        : 'Locked';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.lock_outline, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: AppTheme.border,
          disabledForegroundColor: AppTheme.textMuted,
        ),
      ),
    );
  }
}

// ── Long position buttons (Buy + Sell) ────────────────────────────────────────

class _LongButtons extends StatelessWidget {
  final Stock stock;
  final PortfolioProvider portfolio;
  final dynamic holding; // PortfolioHolding?
  final bool shortingUnlocked;

  const _LongButtons({
    required this.stock,
    required this.portfolio,
    required this.holding,
    required this.shortingUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _openSheet(context, TransactionType.buy),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.positive,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Buy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: holding == null
                    ? null
                    : () => _openSheet(context, TransactionType.sell),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.negative,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.negative.withValues(alpha: 0.3),
                ),
                child: const Text('Sell'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: shortingUnlocked
                    ? () => _openSheet(context, TransactionType.short)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kShortAmber,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _kShortAmber.withValues(alpha: 0.3),
                ),
                child: const Text('Short'),
              ),
            ),
          ],
        ),
        if (!shortingUnlocked)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Reach \$1,000 portfolio value to unlock shorting',
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  void _openSheet(BuildContext context, TransactionType type) {
    showModalBottomSheet(
      context: context,
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

// ── Short position buttons (Cover + Short More) ───────────────────────────────

class _ShortButtons extends StatelessWidget {
  final Stock stock;
  final PortfolioProvider portfolio;
  final dynamic shortPosition; // ShortPosition
  final bool shortingUnlocked;

  const _ShortButtons({
    required this.stock,
    required this.portfolio,
    required this.shortPosition,
    required this.shortingUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => _openSheet(context, TransactionType.cover),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cover'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: shortingUnlocked
                ? () => _openSheet(context, TransactionType.short)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kShortAmber,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _kShortAmber.withValues(alpha: 0.3),
            ),
            child: const Text('Short More'),
          ),
        ),
      ],
    );
  }

  void _openSheet(BuildContext context, TransactionType type) {
    showModalBottomSheet(
      context: context,
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

// ── Price Header ──────────────────────────────────────────────────────────────

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
          Text(
            currencyFormat.format(stock.currentPrice),
            style: AppTheme.priceDisplay,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
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
        ],
      ),
    );
  }
}

// ── Generic Info Card ─────────────────────────────────────────────────────────

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
