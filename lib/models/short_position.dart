// ─────────────────────────────────────────────────────────────────────────────
// short_position.dart
//
// PURPOSE: Represents an open short position — shares borrowed and sold with
//          the expectation that the price will fall so they can be bought back
//          (covered) more cheaply for a profit.
//
// MECHANICS:
//   • Opening a short: player immediately receives shares × entryPrice in cash.
//   • Covering a short: player pays shares × currentPrice to close the position.
//   • Profit  = (entryPrice - currentPrice) × shares  (price fell → gain)
//   • Loss    = (currentPrice - entryPrice) × shares  (price rose → pain)
//
// MULTIPLE OPENS: Adding to an existing short uses a weighted average entry
//   price, the same way long holdings track average cost.
// ─────────────────────────────────────────────────────────────────────────────

class ShortPosition {
  /// Ticker of the shorted stock.
  final String ticker;

  /// Number of shares currently shorted (always positive).
  final int shares;

  /// Weighted average price at which the short was opened.
  /// Used as the P&L baseline — not updated when covering (only when adding).
  final double entryPrice;

  const ShortPosition({
    required this.ticker,
    required this.shares,
    required this.entryPrice,
  });

  // ── Computed values ──────────────────────────────────────────────────────────

  /// Total cash received when the short was opened.
  double get totalProceeds => shares * entryPrice;

  /// Unrealised profit/loss at the given current price.
  /// Positive = profitable (price fell). Negative = losing (price rose).
  double unrealizedPnl(double currentPrice) =>
      (entryPrice - currentPrice) * shares;

  /// Unrealised P&L as a percentage of the original proceeds.
  double unrealizedPnlPercent(double currentPrice) {
    if (totalProceeds == 0) return 0.0;
    return (unrealizedPnl(currentPrice) / totalProceeds) * 100;
  }

  /// How much cash is needed to cover (close) the position right now.
  double coverCost(double currentPrice) => shares * currentPrice;

  // ── Copy with ────────────────────────────────────────────────────────────────

  ShortPosition copyWith({
    String? ticker,
    int? shares,
    double? entryPrice,
  }) {
    return ShortPosition(
      ticker: ticker ?? this.ticker,
      shares: shares ?? this.shares,
      entryPrice: entryPrice ?? this.entryPrice,
    );
  }

  // ── Serialisation ────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'ticker': ticker,
      'shares': shares,
      'entryPrice': entryPrice,
    };
  }

  factory ShortPosition.fromJson(Map<String, dynamic> json) {
    return ShortPosition(
      ticker: json['ticker'] as String,
      shares: json['shares'] as int,
      entryPrice: (json['entryPrice'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'ShortPosition(SHORT $shares $ticker @ \$$entryPrice)';
}
