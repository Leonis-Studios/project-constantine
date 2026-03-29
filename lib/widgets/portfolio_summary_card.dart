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

    // Compute the four summary values.
    final double totalValue = portfolio.totalPortfolioValue(stocks);
    final double unrealisedPnl = portfolio.totalUnrealizedPnl(stocks);
    final double cash = portfolio.cashBalance;
    final double invested = portfolio.totalInvested();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Portfolio Summary', style: AppTheme.label),
            const SizedBox(height: 12),
            // 2×2 grid of stat cells.
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
                    label: 'Unrealised P&L',
                    value:
                        '${unrealisedPnl >= 0 ? '+' : ''}${currencyFormat.format(unrealisedPnl)}',
                    valueColor: unrealisedPnl >= 0
                        ? AppTheme.positive
                        : AppTheme.negative,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: 'Cash Available',
                    value: currencyFormat.format(cash),
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    label: 'Amount Invested',
                    value: currencyFormat.format(invested.clamp(0, double.infinity)),
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
