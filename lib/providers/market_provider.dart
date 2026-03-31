// ─────────────────────────────────────────────────────────────────────────────
// market_provider.dart
//
// PURPOSE: The single source of truth for all market state — the list of stocks,
//          the events log, and the current simulated day number.
//
// RESPONSIBILITIES:
//   • Load saved state from disk on startup (or seed from kStockDefinitions)
//   • Expose stocks and events as read-only views to the UI
//   • Drive the simulation forward when advanceDay() is called
//   • Optionally auto-advance on a 3-second timer
//   • Persist state after every change so progress survives app restarts
//   • Provide a resetSimulation() for "New Game" functionality
//
// HOW UI LISTENS:
//   Widgets call context.watch<MarketProvider>() to rebuild whenever
//   notifyListeners() is called. Use context.read<MarketProvider>() for
//   one-off method calls (e.g., from button taps) where you don't need rebuilds.
//
// THREADING NOTE:
//   All state mutations happen on the main isolate. The persistence saves are
//   async but we fire-and-forget them (no await) so the UI doesn't stall.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/stock.dart';
import '../models/market_event.dart';
import '../data/stock_definitions.dart';
import '../data/event_definitions.dart';
import '../services/simulation_engine.dart';
import '../services/persistence_service.dart';
import 'portfolio_provider.dart';

class MarketProvider extends ChangeNotifier {
  // ── Dependencies ─────────────────────────────────────────────────────────────

  final PersistenceService _persistence;
  final SimulationEngine _engine;

  // Seeded with a random value so each app session has different outcomes.
  // Pass Random(42) in tests for deterministic results.
  final Random _rng;

  // ── Constructor ──────────────────────────────────────────────────────────────

  MarketProvider(this._persistence)
      : _engine = SimulationEngine(),
        _rng = Random();

  // ── Private state ────────────────────────────────────────────────────────────

  List<Stock> _stocks = [];

  // Events are stored newest-first so the EventsLogScreen can display them
  // in reverse chronological order without re-sorting every rebuild.
  List<MarketEvent> _events = [];

  int _currentDay = 0;

  // True while the initial load from disk is in progress. The HomeScreen
  // shows a loading indicator while this is true.
  bool _isLoading = true;

  // When auto-advance is active, this timer fires every 3 seconds.
  Timer? _autoAdvanceTimer;
  bool _isAutoAdvancing = false;

  // Optional reference to PortfolioProvider so advanceDay() can trigger
  // unlock checks when prices change without a trade.
  PortfolioProvider? _portfolio;

  /// Tickers newly unlocked on the last advanceDay() call.
  /// The UI reads this to show unlock snackbars.
  List<String> recentlyUnlocked = [];

  // Tickers the player has added to their watchlist.
  Set<String> _watchlist = {};

  // ── Public getters (read-only) ───────────────────────────────────────────────

  /// All 20 stocks. The UI should never modify elements in this list directly.
  List<Stock> get stocks => List.unmodifiable(_stocks);

  /// All events that have fired, newest first.
  List<MarketEvent> get events => List.unmodifiable(_events);

  /// The current simulated day (0 = game start, increments each Next Day press).
  int get currentDay => _currentDay;

  /// True while loading from disk. Show a spinner when this is true.
  bool get isLoading => _isLoading;

  /// True when the auto-advance timer is running.
  bool get isAutoAdvancing => _isAutoAdvancing;

  /// Wires the PortfolioProvider so advanceDay() can trigger unlock checks
  /// when stock prices move without any player trade. Call once from HomeScreen
  /// after both providers have finished initialising.
  void attachPortfolio(PortfolioProvider portfolio) {
    _portfolio = portfolio;
  }

  /// All tickers the player has added to their watchlist.
  Set<String> get watchlist => Set.unmodifiable(_watchlist);

  /// Returns true if [ticker] is in the player's watchlist.
  bool isWatching(String ticker) => _watchlist.contains(ticker);

  /// Adds or removes [ticker] from the watchlist and persists the change.
  void toggleWatchlist(String ticker) {
    if (_watchlist.contains(ticker)) {
      _watchlist.remove(ticker);
    } else {
      _watchlist.add(ticker);
    }
    _persistence.saveWatchlist(_watchlist);
    notifyListeners();
  }

  /// Returns the Stock with the given ticker, or null if not found.
  /// Used by StockDetailScreen and BuySellBottomSheet to look up a single stock.
  Stock? stockByTicker(String ticker) {
    try {
      return _stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null; // ticker not found
    }
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  /// Loads market state from disk. Call this from HomeScreen.initState().
  /// If no saved state exists (first launch), seeds from kStockDefinitions.
  Future<void> initialize() async {
    // Guard: don't re-initialize if already done.
    if (!_isLoading) return;

    // Attempt to load previously saved stocks.
    final savedStocks = await _persistence.loadStocks();

    if (savedStocks != null && savedStocks.isNotEmpty) {
      // Restore from disk — player is resuming a previous session.
      _stocks = savedStocks;
    } else {
      // First launch: inflate each StockSeed into a full Stock object.
      _stocks = kStockDefinitions.map((seed) => seed.toStock()).toList();
    }

    // Restore the day counter (defaults to 0 if not saved).
    _currentDay = await _persistence.loadCurrentDay();

    // Restore the events log (defaults to empty list if not saved).
    _events = (await _persistence.loadEvents()) ?? [];

    // Restore the watchlist (defaults to empty set if not saved).
    _watchlist = await _persistence.loadWatchlist();

    // Done loading — release the spinner.
    _isLoading = false;
    notifyListeners();
  }

  // ── Core simulation ──────────────────────────────────────────────────────────

  /// Advances the simulation by one day. This is called when the user taps
  /// "Next Day" or when the auto-advance timer fires.
  ///
  /// Flow:
  ///   1. Delegate to SimulationEngine for price updates and event generation
  ///   2. Update local state (stocks, events, day)
  ///   3. Fire-and-forget persistence saves (async, doesn't block UI)
  ///   4. Notify listeners → all watching widgets rebuild
  Future<void> advanceDay() async {
    // Don't advance if we're still loading initial state.
    if (_isLoading) return;

    // Run the simulation engine — purely computational, no side effects.
    final result = _engine.advanceOneDay(
      currentStocks: _stocks,
      eventPool: kAllEventDefinitions,
      dayNumber: _currentDay + 1, // events are labelled with the day they occur
      rng: _rng,
    );

    // Replace the stocks list with updated copies.
    _stocks = result.updatedStocks;

    // Prepend new events to the front of the list (newest-first order).
    _events = [...result.events, ..._events];

    // Increment the day counter.
    _currentDay += 1;

    // Persist changes in the background — we don't await so the UI updates
    // immediately without waiting for disk I/O.
    _persistence.saveStocks(_stocks);
    _persistence.saveCurrentDay(_currentDay);
    _persistence.saveEvents(_events);

    // Check whether price movements have triggered any stock unlocks.
    recentlyUnlocked = _portfolio?.checkAndUnlockStocks(_stocks) ?? [];

    // Rebuild all listening widgets.
    notifyListeners();
  }

  // ── Auto-advance ─────────────────────────────────────────────────────────────

  /// Toggles the auto-advance timer on or off.
  /// When on, advanceDay() is called every 3 seconds automatically.
  ///
  /// The user can toggle this with the play/pause icon in the AppBar.
  void toggleAutoAdvance() {
    if (_isAutoAdvancing) {
      // Turn off: cancel the timer.
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
      _isAutoAdvancing = false;
    } else {
      // Turn on: fire immediately, then every 3 seconds.
      _isAutoAdvancing = true;
      advanceDay(); // immediate first tick
      _autoAdvanceTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => advanceDay(),
      );
    }
    notifyListeners();
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  /// Resets the entire simulation back to day 0 with fresh stock prices.
  /// Called from a "New Game" confirmation dialog.
  Future<void> resetSimulation() async {
    // Stop auto-advance if running.
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _isAutoAdvancing = false;

    // Re-seed stocks from the static definitions.
    _stocks = kStockDefinitions.map((seed) => seed.toStock()).toList();
    _events = [];
    _currentDay = 0;
    recentlyUnlocked = [];
    _watchlist = {};

    // Wipe persisted state so it doesn't load old data on next launch.
    await _persistence.clearAll();

    notifyListeners();
  }

  // ── Disposal ─────────────────────────────────────────────────────────────────

  /// Cancel any active timer when this provider is removed from the tree.
  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
}
