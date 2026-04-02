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
//   • Delegate event SELECTION to EventEngine (weighted balancing algorithm)
//   • Delegate event APPLICATION to SimulationEngine (price maths)
//   • Trigger AbilityService stop-loss checks and unlock checks each tick
//   • Optionally auto-advance on a 3-second timer
//   • Persist state after every change so progress survives app restarts
//   • Provide a resetSimulation() for "New Game" functionality
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/stock.dart';
import '../models/market_event.dart';
import '../data/stock_definitions.dart';
import '../services/simulation_engine.dart';
import '../services/persistence_service.dart';
import '../systems/events/event_engine.dart';
import '../systems/events/market_event.dart' as sys;
import '../systems/abilities/ability_service.dart';
import 'portfolio_provider.dart';

class MarketProvider extends ChangeNotifier {
  // ── Dependencies ─────────────────────────────────────────────────────────────

  final PersistenceService _persistence;
  final SimulationEngine _engine;
  final EventEngine _eventEngine;
  final Random _rng;

  // ── Constructor ──────────────────────────────────────────────────────────────

  MarketProvider(this._persistence)
      : _engine = SimulationEngine(),
        _eventEngine = EventEngine(),
        _rng = Random();

  // ── Private state ────────────────────────────────────────────────────────────

  List<Stock> _stocks = [];
  List<MarketEvent> _events = [];
  int _currentDay = 0;
  bool _isLoading = true;
  Timer? _autoAdvanceTimer;
  bool _isAutoAdvancing = false;

  PortfolioProvider? _portfolio;
  AbilityService? _abilityService;

  /// Tickers newly unlocked on the last advanceDay() call (for UI snackbars).
  List<String> recentlyUnlocked = [];

  Set<String> _watchlist = {};

  // ── Public getters (read-only) ───────────────────────────────────────────────

  List<Stock> get stocks => List.unmodifiable(_stocks);
  List<MarketEvent> get events => List.unmodifiable(_events);
  int get currentDay => _currentDay;
  bool get isLoading => _isLoading;
  bool get isAutoAdvancing => _isAutoAdvancing;

  void attachPortfolio(PortfolioProvider portfolio) {
    _portfolio = portfolio;
  }

  /// Wires the AbilityService so advanceDay() can run stop-loss checks and
  /// unlock condition evaluations each tick.
  void attachAbilityService(AbilityService service) {
    _abilityService = service;
  }

  Set<String> get watchlist => Set.unmodifiable(_watchlist);
  bool isWatching(String ticker) => _watchlist.contains(ticker);

  void toggleWatchlist(String ticker) {
    if (_watchlist.contains(ticker)) {
      _watchlist.remove(ticker);
    } else {
      _watchlist.add(ticker);
    }
    _persistence.saveWatchlist(_watchlist);
    notifyListeners();
  }

  Stock? stockByTicker(String ticker) {
    try {
      return _stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  // ── Initialisation ───────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!_isLoading) return;

    final savedStocks = await _persistence.loadStocks();
    if (savedStocks != null && savedStocks.isNotEmpty) {
      _stocks = savedStocks;
    } else {
      _stocks = kStockDefinitions.map((seed) => seed.toStock()).toList();
    }

    _currentDay = await _persistence.loadCurrentDay();
    _events = (await _persistence.loadEvents()) ?? [];
    _watchlist = await _persistence.loadWatchlist();

    // Load EventEngine rolling state.
    await _eventEngine.loadState(_persistence);

    _isLoading = false;
    notifyListeners();
  }

  // ── Core simulation ──────────────────────────────────────────────────────────

  Future<void> advanceDay() async {
    if (_isLoading) return;

    // ── 1. Select events using the weighted EventEngine ──────────────────────
    final List<sys.MarketEventDefinition> selectedEvents =
        _eventEngine.selectEvents(
      stocks: _stocks,
      holdings: _portfolio?.holdings ?? [],
      cashBalance: _portfolio?.cashBalance ?? 0,
      rng: _rng,
    );

    // Notify ability service whether a crash is among the selected events.
    final bool crashThisTick = selectedEvents
        .any((e) => e.id == 'global_crash');
    _abilityService?.setCrashEventActive(crashThisTick);

    // Track whether this tick has a volatile event (for Swing Trader).
    final bool volatileThisTick = selectedEvents
        .any((e) => e.direction == sys.EventDirection.volatile);

    // ── 2. Run simulation engine (price updates + event application) ─────────
    final result = _engine.advanceOneDay(
      currentStocks: _stocks,
      selectedEvents: selectedEvents,
      dayNumber: _currentDay + 1,
      rng: _rng,
    );

    _stocks = result.updatedStocks;
    _events = [...result.events, ..._events];
    _currentDay += 1;

    // ── 3. Stop-loss auto-sell ───────────────────────────────────────────────
    // Must run after prices update so we compare against new prices.
    if (_abilityService != null && _portfolio != null) {
      final stopLossTickers = _abilityService!.applyStopLossCheck(
        _portfolio!.holdings,
        _stocks,
      );
      for (final ticker in stopLossTickers) {
        final stock = stockByTicker(ticker);
        final holding = _portfolio!.holdingForTicker(ticker);
        if (stock != null && holding != null) {
          _portfolio!.sellStockForAbility(stock, holding.shares);
          _abilityService!.recordStopLossSell(ticker);
        }
      }
    }

    // ── 4. Clear crash flag for this tick ────────────────────────────────────
    _abilityService?.setCrashEventActive(false);

    // ── 5. Stock unlock checks ───────────────────────────────────────────────
    recentlyUnlocked = _portfolio?.checkAndUnlockStocks(_stocks) ?? [];

    // ── 6. Ability unlock checks ─────────────────────────────────────────────
    if (_abilityService != null && _portfolio != null) {
      _abilityService!.checkUnlockConditions(
        transactions: _portfolio!.transactions,
        holdings: _portfolio!.holdings,
        stocks: _stocks,
        lastTickHadCorrectionEvent: selectedEvents.any((e) =>
            e.balancingTags.contains('correction') ||
            e.balancingTags.contains('anti-whale')),
        lastTickHadVolatileEvent: volatileThisTick,
      );
    }

    // ── 7. Persist ───────────────────────────────────────────────────────────
    _persistence.saveStocks(_stocks);
    _persistence.saveCurrentDay(_currentDay);
    _persistence.saveEvents(_events);
    _eventEngine.saveState(_persistence);

    notifyListeners();
  }

  // ── Auto-advance ─────────────────────────────────────────────────────────────

  void toggleAutoAdvance() {
    if (_isAutoAdvancing) {
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
      _isAutoAdvancing = false;
    } else {
      _isAutoAdvancing = true;
      advanceDay();
      _autoAdvanceTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => advanceDay(),
      );
    }
    notifyListeners();
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  Future<void> resetSimulation() async {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _isAutoAdvancing = false;

    _stocks = kStockDefinitions.map((seed) => seed.toStock()).toList();
    _events = [];
    _currentDay = 0;
    recentlyUnlocked = [];
    _watchlist = {};

    _eventEngine.reset();

    await _persistence.clearAll();
    notifyListeners();
  }

  // ── Disposal ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
}
