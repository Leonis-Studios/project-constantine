// ─────────────────────────────────────────────────────────────────────────────
// daily_summary_sheet.dart
//
// PURPOSE: End-of-day report shown as a modal bottom sheet every time the
//          player presses "Next Day". Displays:
//            • Portfolio value change (before → after)
//            • Holdings performance (each position, sorted best → worst)
//            • Market movers (top 3 gainers + top 3 losers across all stocks)
//            • Today's events (headlines + impact badges)
//            • Cash balance footer
//
// HOW TO SHOW:
//   showModalBottomSheet(
//     context: context,
//     isScrollControlled: true,
//     builder: (_) => DailySummarySheet(...),
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/market_event.dart';
import '../models/stock.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';

class DailySummarySheet extends StatelessWidget {
  final int dayNumber;
  final double portfolioValueBefore;
  final double portfolioValueAfter;
  final List<Stock> stocks;
  final PortfolioProvider portfolio;
  final List<MarketEvent> todayEvents;

  const DailySummarySheet({
    super.key,
    required this.dayNumber,
    required this.portfolioValueBefore,
    required this.portfolioValueAfter,
    required this.stocks,
    required this.portfolio,
    required this.todayEvents,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final valueDelta = portfolioValueAfter - portfolioValueBefore;
    final valueDeltaPct = portfolioValueBefore > 0
        ? (valueDelta / portfolioValueBefore) * 100
        : 0.0;
    final deltaColor = valueDelta >= 0 ? AppTheme.positive : AppTheme.negative;
    final deltaSign = valueDelta >= 0 ? '+' : '';

    // Sort stocks by today's % change for movers section.
    final sortedStocks = List<Stock>.from(stocks)
      ..sort((a, b) => b.changePercent.compareTo(a.changePercent));
    final topGainers = sortedStocks.take(3).toList();
    final topLosers = sortedStocks.reversed.take(3).toList();

    // Holdings with live price data, sorted best → worst by today's % change.
    final holdingRows = portfolio.holdings.map((h) {
      final stock = stocks.firstWhere(
        (s) => s.ticker == h.ticker,
        orElse: () => stocks.first,
      );
      return _HoldingRow(
        ticker: h.ticker,
        companyName: stock.companyName,
        shares: h.shares,
        todayChangePct: stock.changePercent,
        unrealizedPnl: h.unrealizedPnl(stock.currentPrice),
      );
    }).toList()
      ..sort((a, b) => b.todayChangePct.compareTo(a.todayChangePct));

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── Drag handle + header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day $dayNumber Complete',
                                  style: AppTheme.headline,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Market has closed',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ── Portfolio value card ──────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Portfolio Value', style: AppTheme.label),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currency.format(portfolioValueAfter),
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'was ${currency.format(portfolioValueBefore)}',
                                  style: AppTheme.caption,
                                ),
                              ],
                            ),
                          ),
                          // Delta badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (valueDelta >= 0
                                      ? AppTheme.positiveFaint
                                      : AppTheme.negativeFaint),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.cardRadius),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$deltaSign${currency.format(valueDelta)}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: deltaColor,
                                  ),
                                ),
                                Text(
                                  '$deltaSign${valueDeltaPct.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: deltaColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Cash row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cash available', style: AppTheme.caption),
                          Text(
                            currency.format(portfolio.cashBalance),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Holdings performance ──────────────────────────────────────
              if (holdingRows.isNotEmpty) ...[
                _SectionHeader(title: 'Your Holdings Today'),
                SliverToBoxAdapter(
                  child: _SectionCard(
                    child: Column(
                      children: holdingRows
                          .map((row) => _HoldingRowWidget(row: row))
                          .toList(),
                    ),
                  ),
                ),
              ],

              // ── Market movers ─────────────────────────────────────────────
              _SectionHeader(title: 'Market Movers'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gainers
                      Expanded(
                        child: _MoverColumn(
                          label: 'Top Gainers',
                          labelColor: AppTheme.positive,
                          stocks: topGainers,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Losers
                      Expanded(
                        child: _MoverColumn(
                          label: 'Top Losers',
                          labelColor: AppTheme.negative,
                          stocks: topLosers,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Today's events ────────────────────────────────────────────
              if (todayEvents.isNotEmpty) ...[
                _SectionHeader(title: "Today's Events"),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _EventRow(event: todayEvents[i]),
                    childCount: todayEvents.length,
                  ),
                ),
              ],

              // ── Bottom padding ────────────────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data class for a holding row.

class _HoldingRow {
  final String ticker;
  final String companyName;
  final int shares;
  final double todayChangePct;
  final double unrealizedPnl;

  const _HoldingRow({
    required this.ticker,
    required this.companyName,
    required this.shares,
    required this.todayChangePct,
    required this.unrealizedPnl,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header sliver.

class _SectionHeader extends SliverToBoxAdapter {
  _SectionHeader({required String title})
      : super(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                )),
          ),
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Card wrapper with consistent padding and styling.

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One row inside the holdings section.

class _HoldingRowWidget extends StatelessWidget {
  final _HoldingRow row;
  const _HoldingRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final pct = row.todayChangePct;
    final pnl = row.unrealizedPnl;
    final color = pct >= 0 ? AppTheme.positive : AppTheme.negative;
    final sign = pct >= 0 ? '+' : '';
    final pnlSign = pnl >= 0 ? '+' : '';
    final currency = NumberFormat.currency(symbol: '\$');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Ticker + company
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.ticker,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                    )),
                Text(
                  '${row.shares} shares',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          // Today % change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                '$pnlSign${currency.format(pnl)} P&L',
                style: TextStyle(fontSize: 10, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gainers/losers column.

class _MoverColumn extends StatelessWidget {
  final String label;
  final Color labelColor;
  final List<Stock> stocks;

  const _MoverColumn({
    required this.label,
    required this.labelColor,
    required this.stocks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...stocks.map((s) {
            final pct = s.changePercent;
            final color = pct >= 0 ? AppTheme.positive : AppTheme.negative;
            final sign = pct >= 0 ? '+' : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.ticker,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '$sign${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// A compact event row for today's events.

class _EventRow extends StatelessWidget {
  final MarketEvent event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.isGlobal
        ? AppTheme.accent
        : event.isPositive
            ? AppTheme.positive
            : AppTheme.negative;
    final sign = event.impactPercent >= 0 ? '+' : '';
    final impactStr = '$sign${event.impactPercent.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: const BorderSide(color: AppTheme.border, width: 1),
          right: const BorderSide(color: AppTheme.border, width: 1),
          bottom: const BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              event.headline,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
            ),
            child: Text(
              impactStr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
