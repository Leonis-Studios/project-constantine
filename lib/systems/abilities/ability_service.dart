// ─────────────────────────────────────────────────────────────────────────────
// ability_service.dart  (lib/systems/abilities/)
//
// PURPOSE: Runtime management of player abilities — tracking which are
//          unlocked, which are equipped, and applying their modifiers to trades.
//
// RESPONSIBILITIES:
//   • Track unlock state for all abilities
//   • Enforce the one-ability-per-slot equip rule
//   • Charge 500 currency + enforce 1hr real-time cooldown on swaps
//   • Apply trade modifiers (block or bonus) when sellStock / buyStock fires
//   • Run stop-loss checks each tick and return tickers to auto-sell
//   • Generate the once-per-day Insider Tip signal
//   • Expose the Sector Scout hint from EventEngine
//   • Expose the Macro Analyst direction hint
//   • Persist all state to local storage
//
// ADDING A NEW ABILITY WITH CUSTOM LOGIC:
//   1. Write a handler class in ability_handlers.dart.
//   2. Register it in _buildHandlers() below (one line).
//   3. Add the Ability to ability_registry.dart.
//   No other changes needed here.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/transaction.dart';
import '../../models/portfolio_holding.dart';
import '../../models/stock.dart';
import '../../services/persistence_service.dart';
import '../events/event_engine.dart';
import '../events/market_event.dart';
import 'ability.dart';
import 'ability_handler.dart';
import 'ability_handlers.dart';
import 'ability_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TUNING CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Cash cost to swap an already-equipped ability for a different one.
const double kSwapCostCurrency = 500.0;

/// Real-time hours between allowed swaps for the same slot.
const int kSwapCooldownHours = 1;

// ─────────────────────────────────────────────────────────────────────────────
// Supporting types
// ─────────────────────────────────────────────────────────────────────────────

/// The result of a pre-flight swap eligibility check.
class SwapResult {
  final bool allowed;
  final String? reason;
  final Duration? cooldownRemaining;

  const SwapResult({
    required this.allowed,
    this.reason,
    this.cooldownRemaining,
  });
}

/// A one-tick directional signal for the Insider Tip ability.
class InsiderTipSignal {
  final String ticker;
  final bool bullish;
  final bool isUnverified;

  const InsiderTipSignal({
    required this.ticker,
    required this.bullish,
    required this.isUnverified,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AbilityService
// ─────────────────────────────────────────────────────────────────────────────

class AbilityService {
  // ── State ────────────────────────────────────────────────────────────────────

  final ValueNotifier<int> stateVersion = ValueNotifier(0);

  final StreamController<Ability> _unlockController =
      StreamController<Ability>.broadcast();

  Stream<Ability> get unlockStream => _unlockController.stream;

  final ValueNotifier<Map<String, bool>> activeModifiers =
      ValueNotifier(const {});

  bool isAbilityActive(String abilityId) =>
      activeModifiers.value[abilityId] ?? false;

  final Set<String> _unlockedAbilityIds = {};

  final Map<AbilitySlot, String?> _equippedAbilityIds = {
    AbilitySlot.timing: null,
    AbilitySlot.risk: null,
    AbilitySlot.info: null,
  };

  final Map<AbilitySlot, DateTime?> _lastSwapTime = {
    AbilitySlot.timing: null,
    AbilitySlot.risk: null,
    AbilitySlot.info: null,
  };

  /// Tickers banned from re-buy after a Stop Loss auto-sell.
  final Map<String, DateTime> _stopLossBannedUntil = {};

  /// Whether a global crash event fired on the most recent tick.
  bool _crashEventActive = false;

  /// Tracks tickers that dropped 30%+ from avg cost (for Diamond Hands).
  final Map<String, bool> _hasHeldThroughDeepDrop = {};

  /// Pending Contrarian Signal credits (ticker → bonus amount on next sell).
  /// Shared with ContrarianSignalHandler via AbilityTradeContext.
  final Map<String, double> _contrarianCredits = {};

  // ── Handler registry ─────────────────────────────────────────────────────────

  late final Map<String, AbilityHandler> _handlers = _buildHandlers();

  static Map<String, AbilityHandler> _buildHandlers() => {
        'swing_trader': SwingTraderHandler(),
        'iron_flipper': IronFlipperHandler(),
        'trend_surfer': TrendSurferHandler(),
        'diamond_hands': DiamondHandsHandler(),
        'stop_loss': StopLossHandler(),
        'hedger': HedgerHandler(),
        'sector_arbiter': SectorArbiterHandler(),
        'scar_tissue': ScarTissueHandler(),
        'contrarian_signal': ContrarianSignalHandler(),
        'sector_scout': SectorScoutHandler(),
        'insider_tip_ability': InsiderTipHandler(),
        'macro_analyst': MacroAnalystHandler(),
        'pattern_recognition': PatternRecognitionHandler(),
      };

  // ── Crash event flag (called by MarketProvider) ───────────────────────────────

  void setCrashEventActive(bool active) => _crashEventActive = active;

  // ── Read-only accessors ───────────────────────────────────────────────────────

  Ability? equippedAbility(AbilitySlot slot) {
    final id = _equippedAbilityIds[slot];
    if (id == null) return null;
    try {
      return AbilityRegistry.all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Ability? abilityById(String id) {
    try {
      return AbilityRegistry.all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  Duration? swapCooldownRemaining(AbilitySlot slot) {
    final lastSwap = _lastSwapTime[slot];
    if (lastSwap == null) return null;
    final elapsed = DateTime.now().difference(lastSwap);
    final remaining = const Duration(hours: kSwapCooldownHours) - elapsed;
    return remaining.isNegative ? null : remaining;
  }

  SwapResult canSwap(String abilityId, {required double cashBalance}) {
    final ability = abilityById(abilityId);
    if (ability == null) {
      return const SwapResult(allowed: false, reason: 'Unknown ability.');
    }
    if (!_unlockedAbilityIds.contains(abilityId)) {
      return SwapResult(
        allowed: false,
        reason: '${ability.name} has not been unlocked yet.',
      );
    }

    final cooldown = swapCooldownRemaining(ability.slot);
    if (cooldown != null) {
      final h = cooldown.inHours;
      final m = cooldown.inMinutes.remainder(60);
      final timeStr = h > 0 ? '${h}h ${m}m' : '${cooldown.inMinutes}m';
      return SwapResult(
        allowed: false,
        reason: 'Swap on cooldown — $timeStr remaining',
        cooldownRemaining: cooldown,
      );
    }

    if (cashBalance < kSwapCostCurrency) {
      final shortfall = kSwapCostCurrency - cashBalance;
      return SwapResult(
        allowed: false,
        reason: 'Insufficient funds — need '
            '\$${shortfall.toStringAsFixed(0)} more',
      );
    }

    return const SwapResult(allowed: true);
  }

  bool isTickerStopLossBanned(String ticker) {
    final expiry = _stopLossBannedUntil[ticker];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _stopLossBannedUntil.remove(ticker);
      return false;
    }
    return true;
  }

  InsiderTipSignal? get lastInsiderTip =>
      (_handlers['insider_tip_ability'] as InsiderTipHandler?)?.lastTip;

  // ── Equip / swap ─────────────────────────────────────────────────────────────

  String? equipAbility(String abilityId, {required double cashBalance}) {
    final ability = abilityById(abilityId);
    if (ability == null) return 'Unknown ability: $abilityId';
    if (!_unlockedAbilityIds.contains(abilityId)) {
      return '${ability.name} has not been unlocked yet.';
    }

    final current = _equippedAbilityIds[ability.slot];
    if (current == abilityId) return 'Already equipped.';

    if (current == null) {
      _equippedAbilityIds[ability.slot] = abilityId;
      stateVersion.value++;
      return null;
    }

    return swapAbility(abilityId, cashBalance: cashBalance);
  }

  String? swapAbility(String abilityId, {required double cashBalance}) {
    final ability = abilityById(abilityId);
    if (ability == null) return 'Unknown ability: $abilityId';
    if (!_unlockedAbilityIds.contains(abilityId)) {
      return '${ability.name} has not been unlocked yet.';
    }

    final lastSwap = _lastSwapTime[ability.slot];
    if (lastSwap != null) {
      final elapsed = DateTime.now().difference(lastSwap);
      if (elapsed.inHours < kSwapCooldownHours) {
        final remaining = kSwapCooldownHours - elapsed.inHours;
        return 'Swap on cooldown. Wait $remaining more hour${remaining == 1 ? '' : 's'}.';
      }
    }

    if (cashBalance < kSwapCostCurrency) {
      return 'Swapping costs \$${kSwapCostCurrency.toStringAsFixed(0)}. '
          'You need \$${(kSwapCostCurrency - cashBalance).toStringAsFixed(2)} more.';
    }

    _equippedAbilityIds[ability.slot] = abilityId;
    _lastSwapTime[ability.slot] = DateTime.now();
    stateVersion.value++;
    return null;
  }

  // ── Unlock checks ─────────────────────────────────────────────────────────────

  /// Evaluates unlock conditions for all unearned abilities and marks any
  /// that are now satisfied. Returns the list of newly unlocked ability IDs.
  ///
  /// Call this after every trade and after each day advance.
  List<String> checkUnlockConditions({
    required List<Transaction> transactions,
    required List<PortfolioHolding> holdings,
    required List<Stock> stocks,
    required bool lastTickHadCorrectionEvent,
    required bool lastTickHadVolatileEvent,
    int consecutiveProfitableDays = 0,
    bool lastDayWasProfitable = true,
    double cashBalance = 0.0,
    int currentDay = 0,
    EventDirection? lastTickDirection,
  }) {
    final List<String> newlyUnlocked = [];

    void tryUnlock(String id) {
      if (!_unlockedAbilityIds.contains(id)) {
        _unlockedAbilityIds.add(id);
        final unlockedAbility = abilityById(id);
        if (unlockedAbility != null) {
          unlockedAbility.isUnlocked = true;
          _unlockController.add(unlockedAbility);
        }
        newlyUnlocked.add(id);
      }
    }

    // Update macro analyst's aligned-trade flag before running unlock checks.
    final macroHandler = _handlers['macro_analyst'] as MacroAnalystHandler?;
    final hasSellThisTick = transactions.isNotEmpty &&
        transactions.last.type == TransactionType.sell;
    macroHandler?.recordTradeDirection(!hasSellThisTick);

    final ctx = AbilityUnlockContext(
      transactions: transactions,
      holdings: holdings,
      stocks: stocks,
      lastTickHadCorrectionEvent: lastTickHadCorrectionEvent,
      lastTickHadVolatileEvent: lastTickHadVolatileEvent,
      consecutiveProfitableDays: consecutiveProfitableDays,
      lastDayWasProfitable: lastDayWasProfitable,
      cashBalance: cashBalance,
      currentDay: currentDay,
      lastTickDirection: lastTickDirection,
    );

    for (final ability in AbilityRegistry.all) {
      if (_unlockedAbilityIds.contains(ability.id)) continue;

      // Diamond Hands has a special unlock path needing the deep-drop map.
      if (ability.id == 'diamond_hands') {
        final handler = _handlers['diamond_hands'] as DiamondHandsHandler?;
        if (handler != null &&
            handler.checkUnlockWithDropMap(ctx, _hasHeldThroughDeepDrop)) {
          tryUnlock(ability.id);
        }
        continue;
      }

      final handler = _handlers[ability.id];
      if (handler != null && handler.checkUnlock(ctx)) {
        tryUnlock(ability.id);
      }
    }

    return newlyUnlocked;
  }

  // ── Trade modifiers ───────────────────────────────────────────────────────────

  /// Applies equipped ability modifiers to an incoming trade.
  /// Call this BEFORE executing the trade (so blocks can be enforced).
  TradeModifierResult applyTradeModifiers({
    required Transaction trade,
    required List<Transaction> history,
    required List<PortfolioHolding> holdings,
    required List<Stock> stocks,
    bool activeVolatileEvent = false,
    bool activeCrashEvent = false,
    int currentDay = 0,
  }) {
    final Map<String, bool> mods = {};
    for (final slot in AbilitySlot.values) {
      final a = equippedAbility(slot);
      if (a != null) mods[a.id] = false;
    }

    final ctx = AbilityTradeContext(
      trade: trade,
      holdDuration: trade.type == TransactionType.sell
          ? _holdDurationFor(trade.ticker, history)
          : null,
      holdings: holdings,
      stocks: stocks,
      activeVolatileEvent: activeVolatileEvent,
      activeCrashEvent: activeCrashEvent || _crashEventActive,
      hasHeldThroughDeepDrop: _hasHeldThroughDeepDrop,
      contrarianCredits: _contrarianCredits,
      currentDay: currentDay,
      history: history,
    );

    double totalBonus = 0.0;

    for (final slot in AbilitySlot.values) {
      final ability = equippedAbility(slot);
      if (ability == null) continue;

      final handler = _handlers[ability.id];
      TradeModifierResult? result;

      if (handler != null) {
        result = handler.handleTrade(ctx);
      } else {
        result = ability.onTradeModifier
            ?.call(trade, ctx.holdDuration, trade.totalAmount);
      }

      if (result == null) continue;
      if (result.isBlocked) {
        mods[ability.id] = true;
        activeModifiers.value = Map.unmodifiable(mods);
        return result;
      }
      if (result.bonusAmount != 0) {
        totalBonus += result.bonusAmount;
        mods[ability.id] = true;
      }
    }

    activeModifiers.value = Map.unmodifiable(mods);
    return TradeModifierResult(bonusAmount: totalBonus);
  }

  // ── Stop Loss ─────────────────────────────────────────────────────────────────

  /// Returns the tickers of holdings that have breached the Stop Loss threshold.
  /// Call this after each tick's price update.
  List<String> applyStopLossCheck(
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
  ) {
    final riskAbility = equippedAbility(AbilitySlot.risk);
    if (riskAbility?.id != 'stop_loss') return [];

    final tickCtx = AbilityTickContext(
      holdings: holdings,
      stocks: stocks,
      stopLossBannedUntil: _stopLossBannedUntil,
    );

    final handler = _handlers['stop_loss'];
    return handler?.tickCheck(tickCtx) ?? [];
  }

  void recordStopLossSell(String ticker) {
    _stopLossBannedUntil[ticker] =
        DateTime.now().add(const Duration(hours: kStopLossRebuyBanHours));
  }

  // ── Insider Tip ───────────────────────────────────────────────────────────────

  InsiderTipSignal? generateInsiderTip(List<Stock> stocks, Random rng) {
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id != 'insider_tip_ability') return null;
    if (!_unlockedAbilityIds.contains('insider_tip_ability')) return null;

    final handler = _handlers['insider_tip_ability'] as InsiderTipHandler?;
    return handler?.generateTip(stocks, rng);
  }

  // ── Sector Scout ─────────────────────────────────────────────────────────────

  String? getSectorScoutHint(EventEngine engine) {
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id != 'sector_scout') return null;
    if (!_unlockedAbilityIds.contains('sector_scout')) return null;
    return engine.nextSectorHint;
  }

  // ── Macro Analyst ─────────────────────────────────────────────────────────────

  /// Returns a direction hint (bullish/bearish/null) for the next tick.
  /// Only available when Macro Analyst is equipped and unlocked.
  EventDirection? getMacroDirectionHint(EventEngine engine, Random rng) {
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id != 'macro_analyst') return null;
    if (!_unlockedAbilityIds.contains('macro_analyst')) return null;

    final handler = _handlers['macro_analyst'] as MacroAnalystHandler?;
    final predicted = engine.lastTickDirection;
    return handler?.generateHint(predicted, rng);
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  Future<void> saveState(PersistenceService persistence) async {
    final state = <String, dynamic>{
      'unlocked': _unlockedAbilityIds.toList(),
      'equipped': _equippedAbilityIds.map(
        (slot, id) => MapEntry(slot.name, id),
      ),
      'swapTimes': _lastSwapTime.map(
        (slot, dt) => MapEntry(slot.name, dt?.toIso8601String()),
      ),
      'stopLossBans': _stopLossBannedUntil.map(
        (ticker, dt) => MapEntry(ticker, dt.toIso8601String()),
      ),
      // contrarianCredits persisted here since they're service-level state.
      'contrarianCredits': _contrarianCredits,
      'deepDropTickers': _hasHeldThroughDeepDrop,
    };

    // Merge in each handler's own state.
    for (final handler in _handlers.values) {
      state.addAll(handler.saveState());
    }

    await persistence.saveAbilityState(state);
  }

  Future<void> loadState(PersistenceService persistence) async {
    final state = await persistence.loadAbilityState();
    if (state == null) return;

    final unlocked =
        (state['unlocked'] as List<dynamic>? ?? []).cast<String>();
    _unlockedAbilityIds.addAll(unlocked);
    for (final id in unlocked) {
      abilityById(id)?.isUnlocked = true;
    }

    final equipped = state['equipped'] as Map<String, dynamic>? ?? {};
    for (final entry in equipped.entries) {
      try {
        final slot = AbilitySlot.values.byName(entry.key);
        _equippedAbilityIds[slot] = entry.value as String?;
      } catch (_) {}
    }

    final swapTimes = state['swapTimes'] as Map<String, dynamic>? ?? {};
    for (final entry in swapTimes.entries) {
      try {
        final slot = AbilitySlot.values.byName(entry.key);
        _lastSwapTime[slot] =
            entry.value != null ? DateTime.parse(entry.value as String) : null;
      } catch (_) {}
    }

    final bans = state['stopLossBans'] as Map<String, dynamic>? ?? {};
    for (final entry in bans.entries) {
      try {
        _stopLossBannedUntil[entry.key] =
            DateTime.parse(entry.value as String);
      } catch (_) {}
    }

    final credits = state['contrarianCredits'] as Map<String, dynamic>? ?? {};
    for (final entry in credits.entries) {
      _contrarianCredits[entry.key] = (entry.value as num).toDouble();
    }

    final deepDropMap =
        state['deepDropTickers'] as Map<String, dynamic>? ?? {};
    for (final entry in deepDropMap.entries) {
      _hasHeldThroughDeepDrop[entry.key] = entry.value as bool? ?? false;
    }

    // Restore each handler's state from the same map.
    for (final handler in _handlers.values) {
      handler.loadState(state);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  Duration? _holdDurationFor(String ticker, List<Transaction> transactions) {
    final buys = transactions
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (buys.isEmpty) return null;
    return DateTime.now().difference(buys.first.timestamp);
  }
}
