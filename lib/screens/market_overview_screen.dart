// ─────────────────────────────────────────────────────────────────────────────
// market_overview_screen.dart
//
// PURPOSE: Displays all 20 stocks in a scrollable list, sorted by the user's
//          chosen sort order (biggest gainers by default). Tapping a stock
//          navigates to StockDetailScreen.
//
// SORTING OPTIONS (DropdownButton in AppBar actions):
//   • Biggest Gainers  — descending by changePercent (default)
//   • Biggest Losers   — ascending by changePercent
//   • Alphabetical     — ascending by ticker
//   • By Sector        — grouped by sector name
//
// STATE: _sortMode is local widget state (not in the provider) because it's
//        purely a UI preference that doesn't need to survive rebuilds caused
//        by market updates — the list simply re-sorts on each rebuild.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/stock_tile.dart';
import 'stock_detail_screen.dart';

// Enum representing the four sort modes available to the user.
enum _SortMode { gainers, losers, alphabetical, sector }

class MarketOverviewScreen extends StatefulWidget {
  const MarketOverviewScreen({super.key});

  @override
  State<MarketOverviewScreen> createState() => _MarketOverviewScreenState();
}

class _MarketOverviewScreenState extends State<MarketOverviewScreen> {
  // Default: show biggest gainers at the top.
  _SortMode _sortMode = _SortMode.gainers;

  /// Returns a sorted copy of [stocks] according to the current _sortMode.
  /// We always work on a copy — never mutate the provider's list.
  List<Stock> _sorted(List<Stock> stocks) {
    final copy = List<Stock>.from(stocks);
    switch (_sortMode) {
      case _SortMode.gainers:
        // Descending: highest positive change% first.
        copy.sort((a, b) => b.changePercent.compareTo(a.changePercent));
      case _SortMode.losers:
        // Ascending: most negative change% first.
        copy.sort((a, b) => a.changePercent.compareTo(b.changePercent));
      case _SortMode.alphabetical:
        copy.sort((a, b) => a.ticker.compareTo(b.ticker));
      case _SortMode.sector:
        // Primary sort by sector name, secondary by ticker within sector.
        copy.sort((a, b) {
          final sectorCmp = a.sector.compareTo(b.sector);
          return sectorCmp != 0 ? sectorCmp : a.ticker.compareTo(b.ticker);
        });
    }
    return copy;
  }

  @override
  Widget build(BuildContext context) {
    // Watch the market provider — rebuilds whenever stock prices update.
    final market = context.watch<MarketProvider>();
    final sorted = _sorted(market.stocks);

    // Compute a quick market summary: net % change across all stocks.
    // This gives the user a one-glance "is the market up or down today?" view.
    final double avgChange = market.stocks.isEmpty
        ? 0
        : market.stocks
                .map((s) => s.changePercent)
                .reduce((a, b) => a + b) /
            market.stocks.length;
    final bool marketPositive = avgChange >= 0;

    return Column(
      children: [
        // ── Market summary banner ─────────────────────────────────────────────
        // A tinted strip showing the average market movement for the day.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: marketPositive
              ? AppTheme.positiveFaint
              : AppTheme.negativeFaint,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Market Average',
                style: AppTheme.label,
              ),
              Row(
                children: [
                  Icon(
                    marketPositive
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: marketPositive
                        ? AppTheme.positive
                        : AppTheme.negative,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${marketPositive ? '+' : ''}${avgChange.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: marketPositive
                          ? AppTheme.positive
                          : AppTheme.negative,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Sort controls ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Sort by:', style: AppTheme.label),
              const SizedBox(width: 8),
              // Simple dropdown to pick sort mode.
              DropdownButton<_SortMode>(
                value: _sortMode,
                dropdownColor: AppTheme.surface,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _SortMode.gainers,
                    child: Text('Biggest Gainers'),
                  ),
                  DropdownMenuItem(
                    value: _SortMode.losers,
                    child: Text('Biggest Losers'),
                  ),
                  DropdownMenuItem(
                    value: _SortMode.alphabetical,
                    child: Text('Alphabetical'),
                  ),
                  DropdownMenuItem(
                    value: _SortMode.sector,
                    child: Text('By Sector'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) setState(() => _sortMode = mode);
                },
              ),
            ],
          ),
        ),

        // ── Stock list ────────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            // Use a small top padding so the first card doesn't butt up against
            // the sort controls.
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemBuilder: (context, index) {
              final stock = sorted[index];

              // If sorting by sector, show a sector header when the sector
              // changes between adjacent items.
              if (_sortMode == _SortMode.sector) {
                final showHeader = index == 0 ||
                    sorted[index - 1].sector != stock.sector;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          stock.sector.toUpperCase(),
                          style: AppTheme.caption.copyWith(
                            letterSpacing: 1.2,
                            color: AppTheme.accent,
                          ),
                        ),
                      ),
                    StockTile(
                      stock: stock,
                      onTap: () => _openDetail(context, stock.ticker),
                    ),
                  ],
                );
              }

              return StockTile(
                stock: stock,
                onTap: () => _openDetail(context, stock.ticker),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Pushes the StockDetailScreen for the given ticker.
  void _openDetail(BuildContext context, String ticker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockDetailScreen(ticker: ticker),
      ),
    );
  }
}
