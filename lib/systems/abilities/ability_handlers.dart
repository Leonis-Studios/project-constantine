// ─────────────────────────────────────────────────────────────────────────────
// ability_handlers.dart  (lib/systems/abilities/)
//
// PURPOSE: Concrete AbilityHandler implementations for every ability that
//          needs custom service-side logic beyond a simple onTradeModifier.
//
// TO ADD A NEW ABILITY WITH CUSTOM LOGIC:
//   1. Write a class extending AbilityHandler below.
//   2. Register it in AbilityService._buildHandlers() (one line).
//   3. Add the Ability to AbilityRegistry (one entry + list addition).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../../models/portfolio_holding.dart';
import '../../models/stock.dart';
import '../../models/transaction.dart';
import '../events/market_event.dart';
import 'ability.dart';
import 'ability_handler.dart';
import 'ability_registry.dart';
import 'ability_service.dart' show InsiderTipSignal;

// ═══════════════════════════════════════════════════════════════════════════════
// TIMING slot handlers
// ═══════════════════════════════════════════════════════════════════════════════

// ── SwingTraderHandler ────────────────────────────────────────────────────────

class SwingTraderHandler extends AbilityHandler {
  int _profitCount = 0;

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;
    if (!ctx.activeVolatileEvent) return TradeModifierResult.none;
    // Apply bonus and count for unlock tracking.
    final bonus = ctx.trade.totalAmount * kSwingTraderBonusPct;
    _profitCount++;
    return TradeModifierResult.bonus(bonus);
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) => _profitCount >= 3;

  @override
  Map<String, dynamic> saveState() => {'swingTraderCount': _profitCount};

  @override
  void loadState(Map<String, dynamic> state) {
    _profitCount = (state['swingTraderCount'] as int?) ?? 0;
  }
}

// ── IronFlipperHandler ────────────────────────────────────────────────────────

class IronFlipperHandler extends AbilityHandler {
  /// day → count of qualifying profitable quick sells that day.
  final Map<int, int> _dayCounts = {};

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    // Check if the player has previously sold this ticker profitably.
    final hadPriorProfitableSell = _hasPriorProfitableSell(
        ctx.trade.ticker, ctx.trade, ctx.history);

    if (hadPriorProfitableSell) {
      return TradeModifierResult.bonus(
          ctx.trade.totalAmount * kIronFlipperBonusPct);
    } else {
      return TradeModifierResult.bonus(
          -ctx.trade.totalAmount * kIronFlipperPenaltyPct);
    }
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    // Count qualifying sells (< 2hrs hold, profitable) on current day.
    final qualifyingToday = _countQualifyingToday(ctx.transactions, ctx.currentDay);
    _dayCounts[ctx.currentDay] = qualifyingToday;
    return _dayCounts.values.any((c) => c >= kIronFlipperUnlockCount);
  }

  bool _hasPriorProfitableSell(
      String ticker, Transaction currentSell, List<Transaction> history) {
    // Look for a previous sell of the same ticker that was profitable.
    final earliestBuy = _earliestBuyPrice(ticker, history);
    if (earliestBuy == null) return false;
    return history.any((t) =>
        t.ticker == ticker &&
        t.type == TransactionType.sell &&
        t.timestamp.isBefore(currentSell.timestamp) &&
        t.pricePerShare > earliestBuy);
  }

  double? _earliestBuyPrice(String ticker, List<Transaction> history) {
    final buys = history
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return buys.isEmpty ? null : buys.first.pricePerShare;
  }

  int _countQualifyingToday(List<Transaction> transactions, int day) {
    // "Same simulated day" is approximated by real-time date (same calendar day).
    // In practice we also accept sells whose buy was on the same calendar day.
    final now = DateTime.now();
    int count = 0;
    for (final sell in transactions.where((t) => t.type == TransactionType.sell)) {
      // Must have happened "today" (within last 24 hrs as proxy for same day).
      if (now.difference(sell.timestamp).inHours > 24) continue;
      final buyTx = _earliestBuyTx(sell.ticker, transactions);
      if (buyTx == null) continue;
      final held = sell.timestamp.difference(buyTx.timestamp);
      final profitable = sell.pricePerShare > buyTx.pricePerShare;
      if (profitable && held.inHours < kDayTraderWindowHours) count++;
    }
    return count;
  }

  Transaction? _earliestBuyTx(String ticker, List<Transaction> history) {
    final buys = history
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return buys.isEmpty ? null : buys.first;
  }

  @override
  Map<String, dynamic> saveState() => {
        'ironFlipperDayCounts':
            _dayCounts.map((k, v) => MapEntry(k.toString(), v)),
      };

  @override
  void loadState(Map<String, dynamic> state) {
    final raw = state['ironFlipperDayCounts'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      final day = int.tryParse(e.key);
      if (day != null) _dayCounts[day] = (e.value as num).toInt();
    }
  }
}

// ── TrendSurferHandler ────────────────────────────────────────────────────────

class TrendSurferHandler extends AbilityHandler {
  /// Distinct tickers sold profitably during an uptrend with >= 3 days remaining.
  final Set<String> _qualifyingTickers = {};

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    final stock = _stockFor(ctx.trade.ticker, ctx.stocks);
    if (stock == null) return TradeModifierResult.none;

    final inStrongUptrend = stock.trendDirection == 'up' &&
        stock.trendDaysRemaining >= kTrendSurferMinDaysRemaining;
    final atPeak = stock.trendDaysRemaining <= 1;

    if (inStrongUptrend && !atPeak) {
      // Track for unlock.
      final holding = _holdingFor(ctx.trade.ticker, ctx.holdings);
      if (holding != null &&
          ctx.trade.pricePerShare > holding.averageCost) {
        _qualifyingTickers.add(ctx.trade.ticker);
      }
      return TradeModifierResult.bonus(
          ctx.trade.totalAmount * kTrendSurferBonusPct);
    }
    // No bonus if trend is peaking or not an uptrend.
    return TradeModifierResult.none;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) =>
      _qualifyingTickers.length >= kTrendSurferUnlockTickers;

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  PortfolioHolding? _holdingFor(String ticker, List<PortfolioHolding> holdings) {
    try {
      return holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic> saveState() =>
      {'trendSurferTickers': _qualifyingTickers.toList()};

  @override
  void loadState(Map<String, dynamic> state) {
    final list =
        (state['trendSurferTickers'] as List<dynamic>? ?? []).cast<String>();
    _qualifyingTickers.addAll(list);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RISK slot handlers
// ═══════════════════════════════════════════════════════════════════════════════

// ── DiamondHandsHandler ───────────────────────────────────────────────────────

class DiamondHandsHandler extends AbilityHandler {
  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    // Crash lock — block sells during active crash.
    if (ctx.activeCrashEvent) {
      return const TradeModifierResult.blocked(
        'Diamond Hands: position locked during crash event. '
        'Wait for the event to resolve.',
      );
    }

    // Bonus: only if stock dropped 30%+ and has now recovered above avg cost.
    final holding = _holdingFor(ctx.trade.ticker, ctx.holdings);
    if (holding != null &&
        ctx.hasHeldThroughDeepDrop[ctx.trade.ticker] == true &&
        ctx.trade.pricePerShare >= holding.averageCost) {
      ctx.hasHeldThroughDeepDrop.remove(ctx.trade.ticker);
      return TradeModifierResult.bonus(
          ctx.trade.totalAmount * kDiamondHandsBonusPct);
    }
    return TradeModifierResult.none;
  }

  // The deep-drop map is shared via AbilityTradeContext and AbilityService.
  // The unlock check here reads the service-level map passed by AbilityService.
  bool checkUnlockWithDropMap(
      AbilityUnlockContext ctx, Map<String, bool> deepDropMap) {
    // Record any currently open deep drops.
    for (final holding in ctx.holdings) {
      final stock = _stockFor(holding.ticker, ctx.stocks);
      if (stock == null) continue;
      final drop =
          (holding.averageCost - stock.currentPrice) / holding.averageCost;
      if (drop >= kDiamondHandsDropThreshold) {
        deepDropMap[holding.ticker] = true;
      }
    }
    return deepDropMap.values.any((v) => v);
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) => false; // Called via checkUnlockWithDropMap.

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  PortfolioHolding? _holdingFor(String ticker, List<PortfolioHolding> holdings) {
    try {
      return holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }
}

// ── StopLossHandler ───────────────────────────────────────────────────────────

class StopLossHandler extends AbilityHandler {
  @override
  List<String> tickCheck(AbilityTickContext ctx) {
    final List<String> toSell = [];
    for (final holding in ctx.holdings) {
      // Skip if currently banned from re-buy (already auto-sold recently).
      final expiry = ctx.stopLossBannedUntil[holding.ticker];
      if (expiry != null && DateTime.now().isBefore(expiry)) continue;

      final stock = _stockFor(holding.ticker, ctx.stocks);
      if (stock == null) continue;
      final drop =
          (holding.averageCost - stock.currentPrice) / holding.averageCost;
      if (drop >= kStopLossThreshold) {
        toSell.add(holding.ticker);
      }
    }
    return toSell;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    for (final sell
        in ctx.transactions.where((t) => t.type == TransactionType.sell)) {
      final buyTx = _earliestBuy(sell.ticker, ctx.transactions);
      if (buyTx == null) continue;
      final loss = (sell.pricePerShare - buyTx.pricePerShare) / buyTx.pricePerShare;
      if (loss < -0.20) return true;
    }
    return false;
  }

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  Transaction? _earliestBuy(String ticker, List<Transaction> transactions) {
    final buys = transactions
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return buys.isEmpty ? null : buys.first;
  }
}

// ── HedgerHandler ─────────────────────────────────────────────────────────────

class HedgerHandler extends AbilityHandler {
  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    final holding = _holdingFor(ctx.trade.ticker, ctx.holdings);
    if (holding == null) return TradeModifierResult.none;

    final sellPnl =
        (ctx.trade.pricePerShare - holding.averageCost) * ctx.trade.shares;
    if (sellPnl >= 0) return TradeModifierResult.none; // Only applies on losses.

    final offset = _computeOffset(ctx.trade.ticker, ctx.holdings, ctx.stocks, sellPnl);
    if (offset <= 0) return TradeModifierResult.none;
    return TradeModifierResult.bonus(offset);
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    final sectors = ctx.holdings
        .map((h) => _stockFor(h.ticker, ctx.stocks)?.sector)
        .where((s) => s != null)
        .toSet();
    return sectors.length >= 3;
  }

  double _computeOffset(
    String sellingTicker,
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
    double sellLoss,
  ) {
    final sellStock = _stockFor(sellingTicker, stocks);
    if (sellStock == null) return 0.0;

    double sectorGains = 0.0;
    for (final h in holdings) {
      if (h.ticker == sellingTicker) continue;
      final s = _stockFor(h.ticker, stocks);
      if (s == null || s.sector != sellStock.sector) continue;
      final gain = (s.currentPrice - h.averageCost) * h.shares;
      if (gain > 0) sectorGains += gain;
    }
    final maxOffset = sellLoss.abs() * kHedgerOffsetPct;
    return sectorGains.clamp(0.0, maxOffset);
  }

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  PortfolioHolding? _holdingFor(String ticker, List<PortfolioHolding> holdings) {
    try {
      return holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }
}

// ── SectorArbiterHandler ──────────────────────────────────────────────────────

class SectorArbiterHandler extends AbilityHandler {
  /// day → set of sectors that had a profitable sell that day.
  final Map<int, Set<String>> _profitSectorsByDay = {};

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    final stock = _stockFor(ctx.trade.ticker, ctx.stocks);
    if (stock == null) return TradeModifierResult.none;

    // Count how many stocks the player holds in the same sector (including the one being sold).
    final sameSectorCount = ctx.holdings
        .where((h) =>
            _stockFor(h.ticker, ctx.stocks)?.sector == stock.sector)
        .length;

    if (sameSectorCount < kSectorArbiterMinSameSectorCount) {
      return TradeModifierResult.none;
    }

    final holding = _holdingFor(ctx.trade.ticker, ctx.holdings);
    if (holding == null) return TradeModifierResult.none;

    final sellPnl =
        (ctx.trade.pricePerShare - holding.averageCost) * ctx.trade.shares;

    // Track profitable sectors per day for unlock.
    if (sellPnl > 0) {
      _profitSectorsByDay
          .putIfAbsent(ctx.currentDay, () => {})
          .add(stock.sector);
    }

    if (sellPnl < 0) {
      // Loss: reduce it by 40%.
      return TradeModifierResult.bonus(sellPnl.abs() * kSectorArbiterLossReductionPct);
    } else {
      // Profit: add 6% bonus.
      return TradeModifierResult.bonus(
          ctx.trade.totalAmount * kSectorArbiterProfitBonusPct);
    }
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    return _profitSectorsByDay.values
        .any((sectors) => sectors.length >= kSectorArbiterUnlockSectors);
  }

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  PortfolioHolding? _holdingFor(String ticker, List<PortfolioHolding> holdings) {
    try {
      return holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic> saveState() => {
        'arbiterSectorsByDay': _profitSectorsByDay.map(
          (day, sectors) => MapEntry(day.toString(), sectors.toList()),
        ),
      };

  @override
  void loadState(Map<String, dynamic> state) {
    final raw =
        state['arbiterSectorsByDay'] as Map<String, dynamic>? ?? {};
    for (final e in raw.entries) {
      final day = int.tryParse(e.key);
      if (day == null) continue;
      _profitSectorsByDay[day] =
          (e.value as List<dynamic>).cast<String>().toSet();
    }
  }
}

// ── ScarTissueHandler ─────────────────────────────────────────────────────────

class ScarTissueHandler extends AbilityHandler {
  int _lossDayCount = 0;
  int _stack = 0; // 0–kScarTissueMaxStack

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;
    if (_stack <= 0) return TradeModifierResult.none;
    final bonusPct = _stack * kScarTissueStackBonusPerDay;
    return TradeModifierResult.bonus(ctx.trade.totalAmount * bonusPct);
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    // Called after each day advance. Update stack and count loss days.
    if (ctx.cashBalance > kScarTissueMinCash) {
      if (!ctx.lastDayWasProfitable) {
        _lossDayCount++;
        _stack = (_stack + 1).clamp(0, kScarTissueMaxStack);
      } else {
        _stack = 0; // Reset stack on profitable day.
      }
    }
    return _lossDayCount >= kScarTissueUnlockLossDays;
  }

  @override
  Map<String, dynamic> saveState() => {
        'scarTissueLossDays': _lossDayCount,
        'scarTissueStack': _stack,
      };

  @override
  void loadState(Map<String, dynamic> state) {
    _lossDayCount = (state['scarTissueLossDays'] as int?) ?? 0;
    _stack = (state['scarTissueStack'] as int?) ?? 0;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INFO slot handlers
// ═══════════════════════════════════════════════════════════════════════════════

// ── ContrarianSignalHandler ───────────────────────────────────────────────────

class ContrarianSignalHandler extends AbilityHandler {
  bool _profitAchieved = false;

  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type == TransactionType.buy && ctx.activeCrashEvent) {
      // Store credit for next sell.
      final credit = ctx.trade.totalAmount * kContrarianBonusPct;
      ctx.contrarianCredits[ctx.trade.ticker] =
          (ctx.contrarianCredits[ctx.trade.ticker] ?? 0) + credit;
      return TradeModifierResult.none;
    }

    if (ctx.trade.type == TransactionType.sell) {
      final credit = ctx.contrarianCredits.remove(ctx.trade.ticker) ?? 0.0;
      if (credit > 0) {
        // Check for profit to unlock the ability.
        if (!_profitAchieved) {
          final holding = _holdingFor(ctx.trade.ticker, ctx.holdings);
          if (holding != null &&
              ctx.trade.pricePerShare > holding.averageCost) {
            _profitAchieved = true;
          }
        }
        return TradeModifierResult.bonus(credit);
      }
    }
    return TradeModifierResult.none;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) => _profitAchieved;

  PortfolioHolding? _holdingFor(String ticker, List<PortfolioHolding> holdings) {
    try {
      return holdings.firstWhere((h) => h.ticker == ticker);
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic> saveState() => {
        'contrarianProfitAchieved': _profitAchieved,
        // contrarianCredits are in the AbilityService-level context map
        // and persisted directly by AbilityService.
      };

  @override
  void loadState(Map<String, dynamic> state) {
    _profitAchieved =
        (state['contrarianProfitAchieved'] as bool?) ?? false;
  }
}

// ── SectorScoutHandler ────────────────────────────────────────────────────────

class SectorScoutHandler extends AbilityHandler {
  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    const allSectors = {
      'Technology', 'Energy', 'Healthcare',
      'Finance', 'Consumer', 'Industrial', 'Entertainment',
    };
    final held = ctx.holdings
        .map((h) {
          try {
            return ctx.stocks.firstWhere((s) => s.ticker == h.ticker).sector;
          } catch (_) {
            return null;
          }
        })
        .where((s) => s != null)
        .toSet();
    return held.containsAll(allSectors);
  }
}

// ── InsiderTipHandler ─────────────────────────────────────────────────────────

class InsiderTipHandler extends AbilityHandler {
  DateTime? _lastTipTime;
  InsiderTipSignal? _lastTip;

  InsiderTipSignal? get lastTip => _lastTip;

  InsiderTipSignal? generateTip(List<Stock> stocks, Random rng) {
    if (_lastTipTime != null) {
      final elapsed = DateTime.now().difference(_lastTipTime!);
      if (elapsed.inHours < kInsiderTipCooldownHours) return null;
    }
    if (stocks.isEmpty) return null;

    final target = stocks[rng.nextInt(stocks.length)];
    final actuallyUp = target.trendDirection == 'up' ||
        (target.trendDirection == 'neutral' && rng.nextBool());
    final bool reported;
    if (rng.nextDouble() < kInsiderTipErrorRate) {
      reported = !actuallyUp;
    } else {
      reported = actuallyUp;
    }
    _lastTip = InsiderTipSignal(
      ticker: target.ticker,
      bullish: reported,
      isUnverified: true,
    );
    _lastTipTime = DateTime.now();
    return _lastTip;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) =>
      ctx.consecutiveProfitableDays >= 7;

  @override
  Map<String, dynamic> saveState() =>
      {'lastTipTime': _lastTipTime?.toIso8601String()};

  @override
  void loadState(Map<String, dynamic> state) {
    final s = state['lastTipTime'] as String?;
    if (s != null) _lastTipTime = DateTime.tryParse(s);
  }
}

// ── MacroAnalystHandler ───────────────────────────────────────────────────────

class MacroAnalystHandler extends AbilityHandler {
  int _correctCallCount = 0;
  DateTime? _lastHintTime;

  /// Previous tick's direction (to detect flips).
  EventDirection? _prevTickDirection;

  /// Whether the player made a trade on the previous tick that would have
  /// been aligned with the direction that came in this tick.
  bool _alignedTradeLastTick = false;

  /// Called by AbilityService after each tick to update the aligned-trade flag
  /// before checkUnlock fires.
  void recordTradeDirection(bool bought) {
    _alignedTradeLastTick = bought;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    final current = ctx.lastTickDirection;
    if (current != null && _prevTickDirection != null) {
      final flipped = current != _prevTickDirection &&
          (current == EventDirection.bullish ||
              current == EventDirection.bearish) &&
          (_prevTickDirection == EventDirection.bullish ||
              _prevTickDirection == EventDirection.bearish);
      if (flipped) {
        // Did the player make an aligned trade last tick?
        final boughtBeforeBullish =
            _alignedTradeLastTick && current == EventDirection.bullish;
        final soldBeforeBearish =
            !_alignedTradeLastTick && current == EventDirection.bearish;
        if (boughtBeforeBullish || soldBeforeBearish) {
          _correctCallCount++;
        }
      }
    }
    _prevTickDirection = current;
    return _correctCallCount >= kMacroAnalystUnlockCalls;
  }

  /// Returns a direction hint (with kMacroHintErrorRate noise) or null if on
  /// cooldown. Called by AbilityService.getMacroDirectionHint().
  EventDirection? generateHint(EventDirection? predictedDirection, Random rng) {
    if (predictedDirection == null) return null;
    if (_lastHintTime != null) {
      final elapsed = DateTime.now().difference(_lastHintTime!);
      if (elapsed.inHours < kMacroHintCooldownHours) return null;
    }
    _lastHintTime = DateTime.now();

    // Apply noise: kMacroHintErrorRate chance of returning the wrong direction.
    if (rng.nextDouble() < kMacroHintErrorRate) {
      return predictedDirection == EventDirection.bullish
          ? EventDirection.bearish
          : EventDirection.bullish;
    }
    return predictedDirection;
  }

  @override
  Map<String, dynamic> saveState() => {
        'macroCorrectCalls': _correctCallCount,
        'lastMacroHintTime': _lastHintTime?.toIso8601String(),
      };

  @override
  void loadState(Map<String, dynamic> state) {
    _correctCallCount = (state['macroCorrectCalls'] as int?) ?? 0;
    final s = state['lastMacroHintTime'] as String?;
    if (s != null) _lastHintTime = DateTime.tryParse(s);
  }
}

// ── PatternRecognitionHandler ─────────────────────────────────────────────────

class PatternRecognitionHandler extends AbilityHandler {
  @override
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) {
    if (ctx.trade.type != TransactionType.sell) return TradeModifierResult.none;

    final stock = _stockFor(ctx.trade.ticker, ctx.stocks);
    if (stock == null) return TradeModifierResult.none;

    if (stock.trendDirection == 'up' &&
        stock.trendDaysRemaining >= kPatternRecognitionMinDaysRemaining) {
      return TradeModifierResult.bonus(
          ctx.trade.totalAmount * kPatternRecognitionBonusPct);
    } else if (stock.trendDirection == 'down') {
      return TradeModifierResult.bonus(
          -ctx.trade.totalAmount * kPatternRecognitionPenaltyPct);
    }
    return TradeModifierResult.none;
  }

  @override
  bool checkUnlock(AbilityUnlockContext ctx) {
    final uptrendCount = ctx.holdings.where((h) {
      final stock = _stockFor(h.ticker, ctx.stocks);
      return stock?.trendDirection == 'up';
    }).length;
    return uptrendCount >= kPatternRecognitionUnlockCount;
  }

  Stock? _stockFor(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }
}
