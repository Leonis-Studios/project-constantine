// ─────────────────────────────────────────────────────────────────────────────
// portfolio_provider.dart
//
// PURPOSE: Manages all player-owned financial state — cash balance, stock
//          holdings, short positions, unlocked tickers, and transaction history.
//
// RESPONSIBILITIES:
//   • Load portfolio state from disk on startup
//   • Validate buy/sell/short/cover operations and return human-readable errors
//   • Update holdings using weighted average cost calculation
//   • Track which locked stocks have been permanently unlocked
//   • Persist all changes after every trade
//   • Provide computed totals (portfolio value, total P&L) for the UI
//
// RETURN VALUE PATTERN FOR TRADES:
//   All trade methods return a String? where:
//     null   = success (the trade was executed)
//     String = an error message to show the user (e.g., "Not enough cash")
//   This avoids try/catch boilerplate in widgets.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../models/stock.dart';
import '../models/portfolio_holding.dart';
import '../models/short_position.dart';
import '../models/transaction.dart';
import '../data/stock_definitions.dart';
import '../services/persistence_service.dart';
import '../systems/abilities/ability_service.dart';

class PortfolioProvider extends ChangeNotifier {
  // ── Constants ────────────────────────────────────────────────────────────────

  /// The cash balance a new player starts with.
  static const double kStartingCash = 500.00;

  // ── Dependencies ─────────────────────────────────────────────────────────────

  final PersistenceService _persistence;

  // Optional — wired after construction via attachAbilityService().
  AbilityService? _abilityService;

  // ── Private state ────────────────────────────────────────────────────────────

  double _cashBalance = kStartingCash;
  List<PortfolioHolding> _holdings = [];
  List<ShortPosition> _shortPositions = [];
  List<Transaction> _transactions = [];

  /// Tickers that have been permanently unlocked via portfolio threshold.
  Set<String> _unlockedTickers = {};

  bool _isLoading = true;

  // ── Constructor ──────────────────────────────────────────────────────────────

  PortfolioProvider(this._persistence);

  // ── Service wiring ───────────────────────────────────────────────────────────

  /// Wires the AbilityService so buyStock / sellStock can apply modifiers.
  /// Call once from main() after both services are constructed.
  void attachAbilityService(AbilityService service) {
    _abilityService = service;
  }

  // ── Public getters (read-only) ───────────────────────────────────────────────

  double get cashBalance => _cashBalance;
  List<PortfolioHolding> get holdings => List.unmodifiable(_holdings);
  List<ShortPosition> get shortPositions => List.unmodifiable(_shortPositions);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;

  /// Returns the long holding for a ticker, or null if not owned.
  PortfolioHolding? holdingForTicker(String ticker) {
    try {
      return _holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  /// Returns the open short position for a ticker, or null if none.
  ShortPosition? shortForTicker(String ticker) {
    try {
      return _shortPositions.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  /// Returns true if [ticker] is available for trading.
  /// Stocks with no threshold are always unlocked.
  /// Stocks with a threshold are unlocked once the player reaches it
  /// (permanently — no need to maintain).
  bool isStockUnlocked(String ticker) {
    final seed = kStockDefinitions.firstWhere(
      (s) => s.ticker == ticker,
      orElse: () => const StockSeed(
        ticker: '', companyName: '', sector: '',
        initialPrice: 0, description: '',
      ),
    );
    if (seed.unlockThreshold == null) return true;
    return _unlockedTickers.contains(ticker);
  }

  // ── Computed totals ──────────────────────────────────────────────────────────

  /// Total portfolio value = cash + long positions market value + short P&L.
  ///
  /// Why shorts are included this way:
  ///   Cash already contains the proceeds received when the short was opened
  ///   (entryPrice × shares). The player still owes currentPrice × shares to
  ///   cover. Net contribution of a short to portfolio value is:
  ///   proceeds_in_cash - cover_liability = (entryPrice - currentPrice) × shares
  ///   = unrealizedPnl, which we add here.
  double totalPortfolioValue(List<Stock> stocks) {
    final holdingsValue = _holdings.fold<double>(0.0, (sum, holding) {
      final stock = stocks.firstWhere(
        (s) => s.ticker == holding.ticker,
        orElse: () => throw StateError(
            'Stock ${holding.ticker} not found in market'),
      );
      return sum + holding.currentValue(stock.currentPrice);
    });

    final shortsPnl = _shortPositions.fold<double>(0.0, (sum, sp) {
      try {
        final stock = stocks.firstWhere((s) => s.ticker == sp.ticker);
        return sum + sp.unrealizedPnl(stock.currentPrice);
      } catch (_) {
        return sum;
      }
    });

    return _cashBalance + holdingsValue + shortsPnl;
  }

  /// Total amount originally invested in long positions (buys minus sell proceeds).
  double totalInvested() {
    return _transactions.fold<double>(0.0, (sum, tx) {
      if (tx.type == TransactionType.buy) {
        return sum + tx.totalAmount;
      } else if (tx.type == TransactionType.sell) {
        return sum - tx.totalAmount;
      }
      return sum; // short/cover don't count as "invested"
    });
  }

  /// Total unrealised P&L across all long holdings and short positions.
  double totalUnrealizedPnl(List<Stock> stocks) {
    final longPnl = _holdings.fold<double>(0.0, (sum, holding) {
      final stock = stocks.firstWhere(
        (s) => s.ticker == holding.ticker,
        orElse: () => throw StateError(
            'Stock ${holding.ticker} not found in market'),
      );
      return sum + holding.unrealizedPnl(stock.currentPrice);
    });

    final shortPnl = _shortPositions.fold<double>(0.0, (sum, sp) {
      try {
        final stock = stocks.firstWhere((s) => s.ticker == sp.ticker);
        return sum + sp.unrealizedPnl(stock.currentPrice);
      } catch (_) {
        return sum;
      }
    });

    return longPnl + shortPnl;
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!_isLoading) return;

    _cashBalance = await _persistence.loadCashBalance();
    _holdings = (await _persistence.loadHoldings()) ?? [];
    _shortPositions = await _persistence.loadShortPositions();
    _transactions = (await _persistence.loadTransactions()) ?? [];
    _unlockedTickers = await _persistence.loadUnlockedTickers();

    _isLoading = false;
    notifyListeners();
  }

  // ── Unlock system ────────────────────────────────────────────────────────────

  /// Checks whether any locked stocks have been reached by the current
  /// portfolio value and permanently unlocks them. Returns a list of newly
  /// unlocked ticker symbols (empty if none). Call this after any event that
  /// changes portfolio value: trades, price advances.
  List<String> checkAndUnlockStocks(List<Stock> stocks) {
    final value = totalPortfolioValue(stocks);
    final newlyUnlocked = <String>[];

    for (final seed in kStockDefinitions) {
      if (seed.unlockThreshold != null &&
          !_unlockedTickers.contains(seed.ticker) &&
          value >= seed.unlockThreshold!) {
        _unlockedTickers.add(seed.ticker);
        newlyUnlocked.add(seed.ticker);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _persistence.saveUnlockedTickers(_unlockedTickers);
      notifyListeners();
    }

    return newlyUnlocked;
  }

  // ── Trading operations ───────────────────────────────────────────────────────

  /// Attempts to buy [shares] of [stock] at its current price.
  /// Returns null on success, or an error string if the trade cannot proceed.
  String? buyStock(Stock stock, int shares) {
    if (shares <= 0) return 'Must buy at least 1 share.';

    // Cannot buy a stock you currently have a short position in.
    if (shortForTicker(stock.ticker) != null) {
      return 'Cover your short position in ${stock.ticker} before buying long.';
    }

    // Stop Loss: cannot re-buy a ticker that was auto-sold within the ban window.
    if (_abilityService?.isTickerStopLossBanned(stock.ticker) == true) {
      return 'Stop Loss: cannot re-buy ${stock.ticker} for 1 hour after auto-sell.';
    }

    final double cost = shares * stock.currentPrice;

    if (cost > _cashBalance) {
      final shortfall = cost - _cashBalance;
      return 'Not enough cash. You need \$${shortfall.toStringAsFixed(2)} more.';
    }

    _cashBalance -= cost;

    final existingIndex = _holdings.indexWhere((h) => h.ticker == stock.ticker);

    if (existingIndex >= 0) {
      final existing = _holdings[existingIndex];
      final totalShares = existing.shares + shares;
      final newAvgCost =
          ((existing.shares * existing.averageCost) +
                  (shares * stock.currentPrice)) /
              totalShares;
      _holdings = List.of(_holdings)
        ..[existingIndex] = existing.copyWith(
          shares: totalShares,
          averageCost: newAvgCost,
        );
    } else {
      _holdings = [
        ..._holdings,
        PortfolioHolding(
          ticker: stock.ticker,
          shares: shares,
          averageCost: stock.currentPrice,
        ),
      ];
    }

    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.buy,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: cost,
      timestamp: DateTime.now(),
    );
    _transactions = [tx, ..._transactions];

    // Ability modifier for buys (e.g. Contrarian Signal stores a credit).
    _abilityService?.applyTradeModifiers(
      trade: tx,
      history: _transactions,
      holdings: _holdings,
      stocks: [], // stocks list not needed for buy-side modifiers
    );

    _persistPortfolio();
    notifyListeners();
    return null;
  }

  /// Attempts to sell [shares] of [stock] at its current price.
  /// Returns null on success, or an error string if the trade cannot proceed.
  String? sellStock(Stock stock, int shares) {
    if (shares <= 0) return 'Must sell at least 1 share.';

    final existingIndex = _holdings.indexWhere((h) => h.ticker == stock.ticker);

    if (existingIndex < 0) {
      return 'You don\'t own any ${stock.ticker} shares.';
    }

    final existing = _holdings[existingIndex];

    if (shares > existing.shares) {
      return 'You only own ${existing.shares} share${existing.shares == 1 ? '' : 's'} of ${stock.ticker}.';
    }

    // Build the transaction record first so ability modifiers can inspect it.
    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.sell,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: shares * stock.currentPrice,
      timestamp: DateTime.now(),
    );

    // Check ability modifiers — may block or add a cash bonus.
    double abilityBonus = 0.0;
    if (_abilityService != null) {
      final result = _abilityService!.applyTradeModifiers(
        trade: tx,
        history: _transactions,
        holdings: _holdings,
        stocks: [],
      );
      if (result.isBlocked) return result.blockReason;
      abilityBonus = result.bonusAmount;
    }

    final double proceeds = tx.totalAmount + abilityBonus;
    _cashBalance += proceeds;

    final remainingShares = existing.shares - shares;

    if (remainingShares == 0) {
      _holdings = _holdings.where((h) => h.ticker != stock.ticker).toList();
    } else {
      _holdings = List.of(_holdings)
        ..[existingIndex] = existing.copyWith(shares: remainingShares);
    }

    _transactions = [tx, ..._transactions];

    _persistPortfolio();
    notifyListeners();
    return null;
  }

  /// Opens or adds to a short position in [stock].
  ///
  /// The player immediately receives shares × currentPrice in cash.
  /// Returns null on success, or an error string.
  String? shortStock(Stock stock, int shares) {
    if (shares <= 0) return 'Must short at least 1 share.';

    // Cannot short a stock you already own long.
    if (holdingForTicker(stock.ticker) != null) {
      return 'Sell your long position in ${stock.ticker} before shorting.';
    }

    final double proceeds = shares * stock.currentPrice;

    // Add proceeds to cash (player borrows and immediately sells the shares).
    _cashBalance += proceeds;

    // Update or create the short position.
    final existingIndex =
        _shortPositions.indexWhere((s) => s.ticker == stock.ticker);

    if (existingIndex >= 0) {
      // Adding to an existing short — weighted average entry price.
      final existing = _shortPositions[existingIndex];
      final totalShares = existing.shares + shares;
      final newEntryPrice =
          ((existing.shares * existing.entryPrice) +
                  (shares * stock.currentPrice)) /
              totalShares;
      _shortPositions = List.of(_shortPositions)
        ..[existingIndex] = existing.copyWith(
          shares: totalShares,
          entryPrice: newEntryPrice,
        );
    } else {
      _shortPositions = [
        ..._shortPositions,
        ShortPosition(
          ticker: stock.ticker,
          shares: shares,
          entryPrice: stock.currentPrice,
        ),
      ];
    }

    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.short,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: proceeds,
      timestamp: DateTime.now(),
    );
    _transactions = [tx, ..._transactions];

    _persistPortfolio();
    notifyListeners();
    return null;
  }

  /// Covers (closes) [shares] of an open short position in [stock].
  ///
  /// The player pays shares × currentPrice to buy back the borrowed shares.
  /// Returns null on success, or an error string.
  String? coverStock(Stock stock, int shares) {
    if (shares <= 0) return 'Must cover at least 1 share.';

    final existingIndex =
        _shortPositions.indexWhere((s) => s.ticker == stock.ticker);

    if (existingIndex < 0) {
      return 'You don\'t have a short position in ${stock.ticker}.';
    }

    final existing = _shortPositions[existingIndex];

    if (shares > existing.shares) {
      return 'You only have ${existing.shares} share${existing.shares == 1 ? '' : 's'} shorted in ${stock.ticker}.';
    }

    final double cost = shares * stock.currentPrice;

    if (cost > _cashBalance) {
      return 'Not enough cash to cover. Need \$${cost.toStringAsFixed(2)}, have \$${_cashBalance.toStringAsFixed(2)}.';
    }

    _cashBalance -= cost;

    final remainingShares = existing.shares - shares;

    if (remainingShares == 0) {
      _shortPositions =
          _shortPositions.where((s) => s.ticker != stock.ticker).toList();
    } else {
      _shortPositions = List.of(_shortPositions)
        ..[existingIndex] = existing.copyWith(shares: remainingShares);
    }

    final tx = Transaction(
      id: '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.cover,
      shares: shares,
      pricePerShare: stock.currentPrice,
      totalAmount: cost,
      timestamp: DateTime.now(),
    );
    _transactions = [tx, ..._transactions];

    _persistPortfolio();
    notifyListeners();
    return null;
  }

  /// Sells all [shares] of [stock] unconditionally — used by AbilityService's
  /// stop-loss auto-sell. Bypasses ability modifier checks to prevent loops.
  /// Returns null on success or an error string (e.g. if not held).
  String? sellStockForAbility(Stock stock, int shares) {
    if (shares <= 0) return null;
    final existingIndex = _holdings.indexWhere((h) => h.ticker == stock.ticker);
    if (existingIndex < 0) return 'Not held: ${stock.ticker}';

    final existing = _holdings[existingIndex];
    final sharesToSell = shares.clamp(0, existing.shares);
    if (sharesToSell == 0) return null;

    final double proceeds = sharesToSell * stock.currentPrice;
    _cashBalance += proceeds;

    final remaining = existing.shares - sharesToSell;
    if (remaining == 0) {
      _holdings = _holdings.where((h) => h.ticker != stock.ticker).toList();
    } else {
      _holdings = List.of(_holdings)
        ..[existingIndex] = existing.copyWith(shares: remaining);
    }

    final tx = Transaction(
      id: '${stock.ticker}_sl_${DateTime.now().millisecondsSinceEpoch}',
      ticker: stock.ticker,
      type: TransactionType.sell,
      shares: sharesToSell,
      pricePerShare: stock.currentPrice,
      totalAmount: proceeds,
      timestamp: DateTime.now(),
    );
    _transactions = [tx, ..._transactions];

    _persistPortfolio();
    notifyListeners();
    return null;
  }

  // ── Ability cost deduction ────────────────────────────────────────────────────

  /// Deducts [amount] from the cash balance after a successful ability swap.
  ///
  /// Call this immediately after [AbilityService.swapAbility] returns null.
  /// Does nothing if [amount] exceeds the current balance (guard against
  /// double-calls; the ability service already validated funds via canSwap).
  void spendCash(double amount) {
    if (amount <= 0 || amount > _cashBalance) return;
    _cashBalance -= amount;
    _persistPortfolio();
    notifyListeners();
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  Future<void> resetPortfolio() async {
    _cashBalance = kStartingCash;
    _holdings = [];
    _shortPositions = [];
    _transactions = [];
    _unlockedTickers = {};
    notifyListeners();
    // PersistenceService.clearAll() is called by MarketProvider.resetSimulation()
    // which handles wiping everything including portfolio keys.
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  void _persistPortfolio() {
    _persistence.saveCashBalance(_cashBalance);
    _persistence.saveHoldings(_holdings);
    _persistence.saveShortPositions(_shortPositions);
    _persistence.saveTransactions(_transactions);
    _persistence.saveUnlockedTickers(_unlockedTickers);
  }
}
