// ─────────────────────────────────────────────────────────────────────────────
// transaction.dart
//
// PURPOSE: An immutable record of a single buy or sell action taken by the user.
//          Transactions are append-only — they're never modified after creation.
//
// WHY STORE totalAmount SEPARATELY:
//   We store `totalAmount = shares × pricePerShare` even though it's computable,
//   because the stock's current price will change over time. Locking in the
//   exact dollar amount at trade time gives an accurate transaction history.
// ─────────────────────────────────────────────────────────────────────────────

/// Distinguishes between buy and sell actions.
enum TransactionType { buy, sell }

class Transaction {
  /// A simple unique ID — we use ticker + timestamp milliseconds.
  /// Sufficient for this app; replace with uuid package for production use.
  final String id;

  /// The ticker of the stock that was traded.
  final String ticker;

  /// Whether this was a purchase or a sale.
  final TransactionType type;

  /// Number of shares traded.
  final int shares;

  /// Price per share at the moment of the transaction.
  final double pricePerShare;

  /// Total cash moved: shares × pricePerShare.
  /// Positive for sells (cash in), negative for buys (cash out) when computing
  /// portfolio cash flow — the UI just shows the absolute value.
  final double totalAmount;

  /// Wall-clock time when the trade was executed.
  /// Shown in the transaction history list.
  final DateTime timestamp;

  const Transaction({
    required this.id,
    required this.ticker,
    required this.type,
    required this.shares,
    required this.pricePerShare,
    required this.totalAmount,
    required this.timestamp,
  });

  // ── Serialisation ───────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticker': ticker,
      // Store the enum as a string so it survives JSON round-trips.
      'type': type.name, // 'buy' or 'sell'
      'shares': shares,
      'pricePerShare': pricePerShare,
      'totalAmount': totalAmount,
      // DateTime → ISO-8601 string, e.g. "2024-01-15T10:30:00.000"
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      ticker: json['ticker'] as String,
      // Parse the enum back from its string name.
      type: TransactionType.values.byName(json['type'] as String),
      shares: json['shares'] as int,
      pricePerShare: (json['pricePerShare'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  String toString() =>
      'Transaction(${type.name.toUpperCase()} $shares $ticker @ \$$pricePerShare)';
}
