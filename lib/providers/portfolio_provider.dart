// ─────────────────────────────────────────────────────────────────────────────
// portfolio_provider.dart
//
// PURPOSE: Manages all player-owned financial state — cash balance, stock
//          holdings, and the full transaction history.
//
// RESPONSIBILITIES:
//   • Load portfolio state from disk on startup
//   • Validate buy/sell operations and return human-readable error strings
//   • Update holdings using weighted average cost calculation
//   • Persist all changes after every trade
//   • Provide computed totals (portfolio value, total P&L) for the UI
//
// RETURN VALUE PATTERN FOR TRADES:
//   buyStock() and sellStock() return a String? where:
//     null   = success (the trade was executed)
//     String = an error message to show the user (e.g., "Not enough cash")
//   This avoids try/catch boilerplate in widgets — the caller just checks
//   if the result is null before showing a success snackbar.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../models/stock.dart';
import '../models/portfolio_holding.dart';
import '../models/transaction.dart';
import '../services/persistence_service.dart';

class PortfolioProvider extends ChangeNotifier {
  // ── Constants ────────────────────────────────────────────────────────────────

  /// The cash balance a new player starts with.
  /// Change this to give players more or less starting money.
  static const double kStartingCash = 10000.00;

  // ── Dependencies ─────────────────────────────────────────────────────────────

  final PersistenceService _persistence;

  // ── Private state ────────────────────────────────────────────────────────────

  double _cashBalance = kStartingCash;
  List<PortfolioHolding> _holdings = [];
  List<Transaction> _transactions = [];

  bool _isLoading = true;

  // ── Constructor ──────────────────────────────────────────────────────────────

  PortfolioProvider(this._persistence);

  // ── Public getters (read-only) ───────────────────────────────────────────────

  /// Available cash the player can spend on new purchases.
  double get cashBalance => _cashBalance;

  /// All stocks currently owned. Never modify elements directly.
  List<PortfolioHolding> get holdings => List.unmodifiable(_holdings);

  /// Full history of every buy and sell, newest first.
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  /// True while loading from disk.
  bool get isLoading => _isLoading;

  /// Returns the holding for a specific ticker, or null if not owned.
  PortfolioHolding? holdingForTicker(String ticker) {
    try {
      return _holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  // ── Computed totals ──────────────────────────────────────────────────────────

  /// Total portfolio value = cash + sum of (shares × currentPrice) for each holding.
  /// Requires the current stock list from MarketProvider to look up live prices.
  double totalPortfolioValue(List<Stock> stocks) {
    final holdingsValue = _holdings.fold<double>(0.0, (sum, holding) {
      final stock = stocks.firstWhere(
        (s) => s.ticker == holding.ticker,
        orElse: () => throw StateError(
            'Stock ${holding.ticker} not found in market'),
      );
      return sum + holding.currentValue(stock.currentPrice);
    });
    return _cashBalance + holdingsValue;
  }

  /// Total amount originally invested (sum of all buy transaction totals minus
  /// proceeds from sells). Positive = net money put into the market.
  double totalInvested() {
    return _transactions.fold<double>(0.0, (sum, tx) {
      if (tx.type == TransactionType.buy) {
        return sum + tx.totalAmount;
      } else {
        return sum - tx.totalAmount;
      }
    });
  }

  /// Total unrealised P&L across all open holdings.
  /// = sum of (currentValue - costBasis) for each holding.
  double totalUnrealizedPnl(List<Stock> stocks) {
    return _holdings.fold<double>(0.0, (sum, holding) {
      final stock = stocks.firstWhere(
        (s) => s.ticker == holding.ticker,
        orElse: () => throw StateError(
            'Stock ${holding.ticker} not found in market'),
      );
      return sum + holding.unrealizedPnl(stock.currentPrice);
    });
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Loads portfolio state from disk. Call from HomeScreen.initState()
  /// alongside MarketProvider.initialize().
  Future<void> initialize() async {
    if (!_isLoading) return;

    _cashBalance = await _persistence.loadCashBalance();
    _holdings = (await _persistence.loadHoldings()) ?? [];
    _transactions = (await _persistence.loadTransactions()) ?? [];

    _isLoading = false;
    notifyListeners();
  }

  // ── Trading operations ───────────────────────────────────────────────────────

  /// Attempts to buy [shares] of [stock] at its current price.
  ///
  /// Returns null on success, or an error string if the trade cannot proceed.
  /// Possible errors:
  ///   "Must buy at least 1 share"
  ///   "Not enough cash. Need $X, have $Y."
  String? buyStock(Stock stock, int shares) {
    // ── Validation ────────────────────────────────────────────────────────────
    if (shares <= 0) return 'Must buy at least 1 share.';

    final double cost = shares * stock.currentPrice;

    if (cost > _cashBalance) {
      // Show the user exactly how much they're short.
      final shortfall = cost - _cashBalance;
      return 'Not enough cash. You need \$${shortfall.toStringAsFixed(2)} more.';
    }

    // ── Execute trade ─────────────────────────────────────────────────────────

    // Deduct the purchase cost from available cash.
    _cashBalance -= cost;

    // Update or create the holding for this ticker.
    final existingIndex = _holdings.indexWhere((h) => h.ticker == stock.ticker);

    if (existingIndex >= 0) {
      // Already own some shares — recalculate weighted average cost.
      final existing = _holdings[existingIndex];
      final totalShares = existing.shares + shares;

      // Weighted average cost formula:
      //   newAvg = (existingShares × existingAvgCost + newShares × newPrice)
      //            ÷ totalShares
      final newAvgCost =
          ((existing.shares * existing.averageCost) + (shares * stock.currentPrice)) /
              totalShares;

      // Replace the old holding with the updated one (never mutate in place).
      _holdings = List.of(_holdings)
        ..[existingIndex] = existing.copyWith(
          shares: totalShares,
          averageCost: newAvgCost,
        );
    } else {
      // First purchase of this stock — create a new holding.
      _holdings = [
        ..._holdings,
        PortfolioHolding(
          ticker: stock.ticker,
          shares: shares,
          averageCost: stock.currentPrice,
        ),
      ];
    }

    // Record the transaction in the history log.
    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.buy,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: cost,
      timestamp: DateTime.now(),
    );
    // Prepend so the list stays newest-first.
    _transactions = [tx, ..._transactions];

    // Persist changes in the background.
    _persistPortfolio();

    notifyListeners();
    return null; // null = success
  }

  /// Attempts to sell [shares] of [stock] at its current price.
  ///
  /// Returns null on success, or an error string if the trade cannot proceed.
  /// Possible errors:
  ///   "Must sell at least 1 share"
  ///   "You don't own any X shares."
  ///   "You only own N shares of X."
  String? sellStock(Stock stock, int shares) {
    // ── Validation ────────────────────────────────────────────────────────────
    if (shares <= 0) return 'Must sell at least 1 share.';

    final existingIndex = _holdings.indexWhere((h) => h.ticker == stock.ticker);

    if (existingIndex < 0) {
      return 'You don\'t own any ${stock.ticker} shares.';
    }

    final existing = _holdings[existingIndex];

    if (shares > existing.shares) {
      return 'You only own ${existing.shares} share${existing.shares == 1 ? '' : 's'} of ${stock.ticker}.';
    }

    // ── Execute trade ─────────────────────────────────────────────────────────

    final double proceeds = shares * stock.currentPrice;

    // Add the sale proceeds to cash.
    _cashBalance += proceeds;

    // Update the holding: reduce shares, or remove it entirely if all sold.
    final remainingShares = existing.shares - shares;

    if (remainingShares == 0) {
      // Position fully closed — remove the holding from the list.
      _holdings = _holdings.where((h) => h.ticker != stock.ticker).toList();
    } else {
      // Partial sell — average cost does not change when selling (only buying).
      _holdings = List.of(_holdings)
        ..[existingIndex] = existing.copyWith(shares: remainingShares);
    }

    // Record the sell transaction.
    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.sell,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: proceeds,
      timestamp: DateTime.now(),
    );
    _transactions = [tx, ..._transactions];

    _persistPortfolio();
    notifyListeners();
    return null; // null = success
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  /// Resets the portfolio back to the starting state (called with New Game).
  Future<void> resetPortfolio() async {
    _cashBalance = kStartingCash;
    _holdings = [];
    _transactions = [];
    notifyListeners();
    // PersistenceService.clearAll() is called by MarketProvider.resetSimulation()
    // which handles wiping everything including portfolio keys.
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Fire-and-forget persistence of the portfolio state to disk.
  void _persistPortfolio() {
    _persistence.saveCashBalance(_cashBalance);
    _persistence.saveHoldings(_holdings);
    _persistence.saveTransactions(_transactions);
  }
}
