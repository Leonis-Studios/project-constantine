// ─────────────────────────────────────────────────────────────────────────────
// portfolio_summary_card.dart
//
// PURPOSE: A 2×2 grid card shown at the top of the Portfolio Holdings tab.
//          Gives the user a quick snapshot of their financial position:
//
//   ┌──────────────────┬──────────────────┐
//   │  Total Value     │  Unrealised P&L  │
//   ├──────────────────┼──────────────────┤
//   │  Cash Available  │  Amount Invested │
//   └──────────────────┴──────────────────┘
//
// All values update every time the market advances a day (because MarketProvider
// notifyListeners triggers a rebuild of PortfolioScreen which passes fresh data
// into this widget).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stock.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final PortfolioProvider portfolio;

  /// Current stock list from MarketProvider — needed to look up live prices.
  final List<Stock> stocks;

  const PortfolioSummaryCard({
    super.key,
    required this.portfolio,
    required this.stocks,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Compute the summary values.
    final double totalValue = portfolio.totalPortfolioValue(stocks);
    final double unrealisedPnl = portfolio.totalUnrealizedPnl(stocks);
    final double cash = portfolio.cashBalance;
    // Realised P&L = total return minus what is still unrealised.
    // totalPortfolioValue = startingCash + realisedGains + unrealisedGains
    // => realisedGains = totalPortfolioValue - startingCash - unrealisedGains
    final double realisedPnl =
        totalValue - PortfolioProvider.kStartingCash - unrealisedPnl;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portfolio Summary', style: AppTheme.label),
            const SizedBox(height: 12),
            // Row 1: Total Value | Buying Power
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Total Value',
                    value: currencyFormat.format(totalValue),
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Buying Power',
                    value: currencyFormat.format(cash),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Unrealised P&L | Realised P&L
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Unrealised P&L',
                    value:
                        '${unrealisedPnl >= 0 ? '+' : ''}${currencyFormat.format(unrealisedPnl)}',
                    valueColor: unrealisedPnl >= 0
                        ? AppTheme.positive
                        : AppTheme.negative,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Realised P&L',
                    value:
                        '${realisedPnl >= 0 ? '+' : ''}${currencyFormat.format(realisedPnl)}',
                    valueColor: realisedPnl >= 0
                        ? AppTheme.positive
                        : AppTheme.negative,
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

// ── Stat Cell ─────────────────────────────────────────────────────────────────
//
// One cell in the 2×2 summary grid — a label above a large value.

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
