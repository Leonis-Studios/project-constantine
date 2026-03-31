// ─────────────────────────────────────────────────────────────────────────────
// persistence_service.dart
//
// PURPOSE: Thin wrapper around shared_preferences that serialises and
//          deserialises the app's mutable state to/from disk.
//
// WHAT IS PERSISTED:
//   • All 20 stock objects (with current prices and price history)
//   • The current simulated day number
//   • The full events log
//   • The portfolio: cash balance, holdings, and transaction history
//
// HOW IT WORKS:
//   Each save method converts its data to a JSON string using dart:convert
//   and stores it under a typed key (e.g. "stocks_v1"). Load methods reverse
//   this, returning null if the key hasn't been written yet (first launch).
//
// KEY VERSIONING:
//   Keys are suffixed with _v1. If you change a model's schema in a way that
//   breaks backwards compatibility, bump the version number (e.g. _v2) and
//   add migration logic in init() if needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/stock.dart';
import '../models/market_event.dart';
import '../models/portfolio_holding.dart';
import '../models/transaction.dart';
import '../models/short_position.dart';
import '../models/insider_tip.dart';

class PersistenceService {
  // The shared_preferences instance. Initialised once in init().
  late SharedPreferences _prefs;

  // ── Storage keys ────────────────────────────────────────────────────────────
  // Using constants avoids typos and makes key names easy to update.

  static const String _kStocksKey = 'stocks_v2';
  static const String _kCurrentDayKey = 'current_day_v1';
  static const String _kEventsKey = 'events_v1';
  static const String _kCashBalanceKey = 'cash_balance_v1';
  static const String _kHoldingsKey = 'holdings_v1';
  static const String _kTransactionsKey = 'transactions_v1';
  static const String _kUnlockedTickersKey = 'unlocked_tickers_v1';
  static const String _kShortPositionsKey = 'short_positions_v1';
  static const String _kXpTotalKey = 'xp_total_v1';
  static const String _kXpAchievementsKey = 'xp_achievements_v1';
  static const String _kXpTipsKey = 'xp_tips_v1';
  static const String _kXpTradesKey = 'xp_trades_v1';

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Must be called once before any save/load method is used.
  /// Typically called in main() before runApp().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Stock persistence ────────────────────────────────────────────────────────

  /// Saves the full list of stocks to disk as a JSON array string.
  Future<void> saveStocks(List<Stock> stocks) async {
    // Convert each Stock to a Map, then encode the whole list to JSON.
    final jsonString =
        jsonEncode(stocks.map((s) => s.toJson()).toList());
    await _prefs.setString(_kStocksKey, jsonString);
  }

  /// Loads stocks from disk. Returns null if no stocks have been saved yet
  /// (i.e., first launch). The caller (MarketProvider) handles the null case
  /// by seeding from kStockDefinitions.
  Future<List<Stock>?> loadStocks() async {
    final jsonString = _prefs.getString(_kStocksKey);
    if (jsonString == null) return null;

    // Decode JSON → List<dynamic> → List<Stock>
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => Stock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Day counter ──────────────────────────────────────────────────────────────

  /// Saves the current simulated day number.
  Future<void> saveCurrentDay(int day) async {
    await _prefs.setInt(_kCurrentDayKey, day);
  }

  /// Loads the current day. Returns 0 (day zero) if not yet saved.
  Future<int> loadCurrentDay() async {
    return _prefs.getInt(_kCurrentDayKey) ?? 0;
  }

  // ── Events persistence ───────────────────────────────────────────────────────

  /// Saves the full events log. On large lists this could be slow — consider
  /// trimming to the last 200 events if performance becomes an issue.
  Future<void> saveEvents(List<MarketEvent> events) async {
    final jsonString =
        jsonEncode(events.map((e) => e.toJson()).toList());
    await _prefs.setString(_kEventsKey, jsonString);
  }

  /// Loads the events log. Returns null on first launch.
  Future<List<MarketEvent>?> loadEvents() async {
    final jsonString = _prefs.getString(_kEventsKey);
    if (jsonString == null) return null;

    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => MarketEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Portfolio persistence ────────────────────────────────────────────────────

  /// Saves the user's available cash balance.
  Future<void> saveCashBalance(double cash) async {
    // shared_preferences doesn't have setDouble, so we store as a string.
    // Alternatively, use setBool/setInt — but string keeps full precision.
    await _prefs.setString(_kCashBalanceKey, cash.toString());
  }

  /// Loads cash balance. Returns the starting value ($10,000) if not yet saved.
  Future<double> loadCashBalance() async {
    final raw = _prefs.getString(_kCashBalanceKey);
    if (raw == null) return 500.00;
    return double.parse(raw);
  }

  /// Saves the list of portfolio holdings (stocks currently owned).
  Future<void> saveHoldings(List<PortfolioHolding> holdings) async {
    final jsonString =
        jsonEncode(holdings.map((h) => h.toJson()).toList());
    await _prefs.setString(_kHoldingsKey, jsonString);
  }

  /// Loads holdings. Returns null on first launch.
  Future<List<PortfolioHolding>?> loadHoldings() async {
    final jsonString = _prefs.getString(_kHoldingsKey);
    if (jsonString == null) return null;

    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => PortfolioHolding.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves the transaction history (all buys and sells ever made).
  Future<void> saveTransactions(List<Transaction> transactions) async {
    final jsonString =
        jsonEncode(transactions.map((t) => t.toJson()).toList());
    await _prefs.setString(_kTransactionsKey, jsonString);
  }

  /// Loads transaction history. Returns null on first launch.
  Future<List<Transaction>?> loadTransactions() async {
    final jsonString = _prefs.getString(_kTransactionsKey);
    if (jsonString == null) return null;

    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Unlock state persistence ─────────────────────────────────────────────────

  /// Saves the set of tickers the player has permanently unlocked.
  Future<void> saveUnlockedTickers(Set<String> tickers) async {
    final jsonString = jsonEncode(tickers.toList());
    await _prefs.setString(_kUnlockedTickersKey, jsonString);
  }

  /// Loads the unlocked ticker set. Returns an empty set on first launch.
  Future<Set<String>> loadUnlockedTickers() async {
    final jsonString = _prefs.getString(_kUnlockedTickersKey);
    if (jsonString == null) return {};
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.cast<String>().toSet();
  }

  // ── Watchlist persistence ────────────────────────────────────────────────────

  static const String _kWatchlistKey = 'watchlist_v1';

  /// Saves the set of tickers the player has added to their watchlist.
  Future<void> saveWatchlist(Set<String> tickers) async {
    final jsonString = jsonEncode(tickers.toList());
    await _prefs.setString(_kWatchlistKey, jsonString);
  }

  /// Loads the watchlist. Returns an empty set on first launch.
  Future<Set<String>> loadWatchlist() async {
    final jsonString = _prefs.getString(_kWatchlistKey);
    if (jsonString == null) return {};
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList.cast<String>().toSet();
  }

  // ── Short positions persistence ──────────────────────────────────────────────

  /// Saves all open short positions.
  Future<void> saveShortPositions(List<ShortPosition> positions) async {
    final jsonString =
        jsonEncode(positions.map((p) => p.toJson()).toList());
    await _prefs.setString(_kShortPositionsKey, jsonString);
  }

  /// Loads short positions. Returns an empty list on first launch.
  Future<List<ShortPosition>> loadShortPositions() async {
    final jsonString = _prefs.getString(_kShortPositionsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => ShortPosition.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── XP / Achievement / Tip persistence ──────────────────────────────────────

  /// Saves XP total, unlocked achievement IDs, tip history, and total trade count.
  Future<void> saveXpState({
    required int xp,
    required Set<String> achievements,
    required List<InsiderTip> tips,
    required int totalTrades,
  }) async {
    await Future.wait([
      _prefs.setInt(_kXpTotalKey, xp),
      _prefs.setString(_kXpAchievementsKey, jsonEncode(achievements.toList())),
      _prefs.setString(
          _kXpTipsKey, jsonEncode(tips.map((t) => t.toJson()).toList())),
      _prefs.setInt(_kXpTradesKey, totalTrades),
    ]);
  }

  /// Loads XP state. Returns defaults on first launch.
  Future<({int xp, Set<String> achievements, List<InsiderTip> tips, int totalTrades})>
      loadXpState() async {
    final xp = _prefs.getInt(_kXpTotalKey) ?? 0;
    final totalTrades = _prefs.getInt(_kXpTradesKey) ?? 0;

    final achievementsJson = _prefs.getString(_kXpAchievementsKey);
    final achievements = achievementsJson == null
        ? <String>{}
        : (jsonDecode(achievementsJson) as List<dynamic>)
            .cast<String>()
            .toSet();

    final tipsJson = _prefs.getString(_kXpTipsKey);
    final tips = tipsJson == null
        ? <InsiderTip>[]
        : (jsonDecode(tipsJson) as List<dynamic>)
            .map((e) => InsiderTip.fromJson(e as Map<String, dynamic>))
            .toList();

    return (xp: xp, achievements: achievements, tips: tips, totalTrades: totalTrades);
  }

  // ── Full reset ───────────────────────────────────────────────────────────────

  /// Wipes all saved state. Called by MarketProvider.resetSimulation() and
  /// PortfolioProvider.resetPortfolio() when the user starts a new game.
  Future<void> clearAll() async {
    await Future.wait([
      _prefs.remove('stocks_v1'), // clean up old key if present
      _prefs.remove(_kStocksKey),
      _prefs.remove(_kCurrentDayKey),
      _prefs.remove(_kEventsKey),
      _prefs.remove(_kCashBalanceKey),
      _prefs.remove(_kHoldingsKey),
      _prefs.remove(_kTransactionsKey),
      _prefs.remove(_kUnlockedTickersKey),
      _prefs.remove(_kShortPositionsKey),
      _prefs.remove(_kXpTotalKey),
      _prefs.remove(_kXpAchievementsKey),
      _prefs.remove(_kXpTipsKey),
      _prefs.remove(_kXpTradesKey),
      _prefs.remove(_kWatchlistKey),
    ]);
  }
}
