// ─────────────────────────────────────────────────────────────────────────────
// portfolio_holding.dart
//
// PURPOSE: Represents how many shares of a single stock the user currently owns,
//          plus the weighted average price they paid per share.
//
// NOTE ON AVERAGE COST:
//   When a user buys the same stock multiple times at different prices, we track
//   the weighted average cost rather than the first purchase price. Example:
//     • Buy 10 shares at $100 → avg cost = $100
//     • Buy 10 more at $120  → avg cost = ($1000 + $1200) / 20 = $110
//   This is the standard cost-basis method used in brokerage apps.
//
//   The recalculation lives in PortfolioProvider.buyStock(), not here — this
//   model just stores the result.
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioHolding {
  /// Ticker of the stock being held — links this holding to a Stock object.
  final String ticker;

  /// Number of whole shares owned. We use int (whole shares) to keep the math
  /// simple and avoid fractional share edge cases.
  final int shares;

  /// Weighted average price paid per share across all buy transactions.
  /// Used to calculate unrealised profit/loss.
  final double averageCost;

  const PortfolioHolding({
    required this.ticker,
    required this.shares,
    required this.averageCost,
  });

  // ── Computed values ─────────────────────────────────────────────────────────

  /// Total amount originally invested in this position.
  /// = shares × averageCost
  double get totalCost => shares * averageCost;

  /// Current market value of this position.
  /// Requires the live price, so it's a method not a getter.
  /// = shares × currentPrice
  double currentValue(double currentPrice) => shares * currentPrice;

  /// Unrealised profit or loss in dollars (positive = profit, negative = loss).
  /// = currentValue - totalCost
  double unrealizedPnl(double currentPrice) =>
      currentValue(currentPrice) - totalCost;

  /// Unrealised P&L as a percentage of the original investment.
  /// Returns 0.0 if totalCost is 0 to avoid division by zero.
  double unrealizedPnlPercent(double currentPrice) {
    if (totalCost == 0) return 0.0;
    return (unrealizedPnl(currentPrice) / totalCost) * 100;
  }

  // ── Immutable update ────────────────────────────────────────────────────────

  /// Returns a new PortfolioHolding with selectively replaced fields.
  PortfolioHolding copyWith({
    String? ticker,
    int? shares,
    double? averageCost,
  }) {
    return PortfolioHolding(
      ticker: ticker ?? this.ticker,
      shares: shares ?? this.shares,
      averageCost: averageCost ?? this.averageCost,
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'ticker': ticker,
      'shares': shares,
      'averageCost': averageCost,
    };
  }

  factory PortfolioHolding.fromJson(Map<String, dynamic> json) {
    return PortfolioHolding(
      ticker: json['ticker'] as String,
      shares: json['shares'] as int,
      averageCost: (json['averageCost'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'PortfolioHolding($ticker × $shares shares @ avg \$$averageCost)';
}
