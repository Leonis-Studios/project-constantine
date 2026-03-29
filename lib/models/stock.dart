// ─────────────────────────────────────────────────────────────────────────────
// stock.dart
//
// PURPOSE: Defines the Stock data model — the core entity the whole app revolves
//          around. Each Stock represents one fake publicly-traded company.
//
// KEY DESIGN CHOICES:
//   • Immutable-by-convention: never modify a Stock's fields directly. Always
//     use copyWith() to produce an updated copy. This prevents subtle bugs
//     where widgets hold stale references to old values.
//   • priceHistory stores the last 30 end-of-day closing prices so the chart
//     widget has data to draw a sparkline without needing a separate list.
//   • toJson / fromJson enable persistence via shared_preferences (the
//     PersistenceService serialises stocks to a JSON string).
// ─────────────────────────────────────────────────────────────────────────────

class Stock {
  // ── Identifying fields ──────────────────────────────────────────────────────

  /// Short trading symbol, e.g. "NXCO". Always uppercase, 2–5 characters.
  final String ticker;

  /// Full company name shown in detail views, e.g. "Nexacor Industries".
  final String companyName;

  /// Industry sector — used to group companies and target sector-wide events.
  /// Valid values: "Technology", "Energy", "Healthcare", "Finance",
  ///               "Consumer", "Industrial", "Entertainment"
  final String sector;

  /// One-sentence description of what the company does. Shown on the detail
  /// screen to give context to price movements caused by events.
  final String description;

  // ── Price fields ────────────────────────────────────────────────────────────

  /// The stock's price at the end of the most recent simulated day.
  /// This is the number displayed prominently in the UI.
  final double currentPrice;

  /// The price at the end of the previous day. Used to calculate the daily
  /// change amount and percentage. Set equal to currentPrice on the first day.
  final double previousPrice;

  /// Ordered list of end-of-day closing prices, oldest first.
  /// Capped at 30 entries by the SimulationEngine — new entries are appended
  /// and the oldest is dropped once the cap is reached.
  /// Used to draw the sparkline/line chart on the detail screen.
  final List<double> priceHistory;

  // ── Constructor ─────────────────────────────────────────────────────────────

  const Stock({
    required this.ticker,
    required this.companyName,
    required this.sector,
    required this.description,
    required this.currentPrice,
    required this.previousPrice,
    required this.priceHistory,
  });

  // ── Computed getters ────────────────────────────────────────────────────────

  /// Dollar change from previous close to current price.
  /// Positive = up, negative = down.
  double get changeAmount => currentPrice - previousPrice;

  /// Percentage change relative to the previous day's price.
  /// Formula: ((current - previous) / previous) * 100
  /// Returns 0.0 if previousPrice is 0 to avoid division by zero.
  double get changePercent {
    if (previousPrice == 0) return 0.0;
    return ((currentPrice - previousPrice) / previousPrice) * 100;
  }

  /// True if the stock is up or flat compared to yesterday.
  bool get isPositive => currentPrice >= previousPrice;

  // ── Immutable update ────────────────────────────────────────────────────────

  /// Returns a new Stock with selected fields replaced.
  /// All other fields are copied from `this` unchanged.
  ///
  /// Usage in SimulationEngine:
  ///   final updated = stock.copyWith(
  ///     currentPrice: newPrice,
  ///     previousPrice: stock.currentPrice,  // today becomes yesterday
  ///     priceHistory: [...stock.priceHistory, newPrice],
  ///   );
  Stock copyWith({
    String? ticker,
    String? companyName,
    String? sector,
    String? description,
    double? currentPrice,
    double? previousPrice,
    List<double>? priceHistory,
  }) {
    return Stock(
      ticker: ticker ?? this.ticker,
      companyName: companyName ?? this.companyName,
      sector: sector ?? this.sector,
      description: description ?? this.description,
      currentPrice: currentPrice ?? this.currentPrice,
      previousPrice: previousPrice ?? this.previousPrice,
      priceHistory: priceHistory ?? this.priceHistory,
    );
  }

  // ── Serialisation ───────────────────────────────────────────────────────────

  /// Converts this Stock to a JSON-compatible map for storage.
  /// Called by PersistenceService when saving state to disk.
  Map<String, dynamic> toJson() {
    return {
      'ticker': ticker,
      'companyName': companyName,
      'sector': sector,
      'description': description,
      'currentPrice': currentPrice,
      'previousPrice': previousPrice,
      // priceHistory is a List<double>, which JSON encodes natively.
      'priceHistory': priceHistory,
    };
  }

  /// Reconstructs a Stock from a JSON map loaded from disk.
  /// The 'as' casts are safe because we control the serialisation format.
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      ticker: json['ticker'] as String,
      companyName: json['companyName'] as String,
      sector: json['sector'] as String,
      description: json['description'] as String,
      currentPrice: (json['currentPrice'] as num).toDouble(),
      previousPrice: (json['previousPrice'] as num).toDouble(),
      // JSON decodes arrays as List<dynamic>, so we cast each element to double.
      priceHistory: (json['priceHistory'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  @override
  String toString() =>
      'Stock($ticker @ \$$currentPrice, ${changePercent.toStringAsFixed(2)}%)';
}
