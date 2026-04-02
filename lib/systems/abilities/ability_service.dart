// ─────────────────────────────────────────────────────────────────────────────
// ability_service.dart  (lib/systems/abilities/)
//
// PURPOSE: Runtime management of player abilities — tracking which are
//          unlocked, which are equipped, and applying their modifiers to trades.
//
// RESPONSIBILITIES:
//   • Track unlock state for all 9 abilities
//   • Enforce the one-ability-per-slot equip rule
//   • Charge 500 currency + enforce 1hr real-time cooldown on swaps
//   • Apply trade modifiers (block or bonus) when sellStock / buyStock fires
//   • Run stop-loss checks each tick and return tickers to auto-sell
//   • Generate the once-per-day Insider Tip signal
//   • Expose the Sector Scout hint from EventEngine
//   • Persist all state to local storage
//
// THREADING:
//   All methods are synchronous except saveState / loadState.
//   Callers fire-and-forget saves (no await needed) to keep the UI responsive.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../models/transaction.dart';
import '../../models/portfolio_holding.dart';
import '../../models/stock.dart';
import '../../services/persistence_service.dart';
import '../events/event_engine.dart';
import 'ability.dart';
import 'ability_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TUNING CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Cash cost to swap an already-equipped ability for a different one.
/// Raise to discourage frequent ability swapping during a session.
const double kSwapCostCurrency = 500.0;

/// Real-time hours between allowed swaps for the same slot.
/// Raise to extend the cooldown window between swaps.
const int kSwapCooldownHours = 1;

// ─────────────────────────────────────────────────────────────────────────────
// Supporting types
// ─────────────────────────────────────────────────────────────────────────────

/// The result of a pre-flight swap eligibility check.
///
/// Call [AbilityService.canSwap] before showing a confirmation dialog so the
/// UI can surface a human-readable [reason] without actually performing the swap.
class SwapResult {
  /// Whether the swap is permitted right now.
  final bool allowed;

  /// Human-readable explanation when [allowed] is false. Null when allowed.
  final String? reason;

  /// How long until the cooldown expires, when the block is cooldown-related.
  /// Null for non-cooldown blocks and when [allowed] is true.
  final Duration? cooldownRemaining;

  const SwapResult({
    required this.allowed,
    this.reason,
    this.cooldownRemaining,
  });
}

/// A one-tick directional signal for the Insider Tip ability.
class InsiderTipSignal {
  /// The ticker this signal refers to.
  final String ticker;

  /// True if the engine predicts the price will trend up next tick.
  final bool bullish;

  /// True if the signal has a 25% chance of being wrong.
  /// Always true for this ability — shown in the UI as "unverified intel."
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

  /// Incremented whenever equip or swap state changes. Widgets can wrap a
  /// [ValueListenableBuilder] around this to rebuild automatically.
  final ValueNotifier<int> stateVersion = ValueNotifier(0);

  /// Emits an [Ability] whenever a new ability is unlocked. Broadcast so
  /// multiple listeners (e.g. toast, AbilityProvider) can all subscribe.
  final StreamController<Ability> _unlockController =
      StreamController<Ability>.broadcast();

  Stream<Ability> get unlockStream => _unlockController.stream;

  /// Tracks which equipped abilities actively applied a modifier during the
  /// most recent [applyTradeModifiers] call. Keys are ability IDs; true means
  /// the modifier actually fired (produced a bonus or block), false means the
  /// ability was equipped but did not apply this evaluation.
  /// Notifies listeners after every trade evaluation.
  final ValueNotifier<Map<String, bool>> activeModifiers =
      ValueNotifier(const {});

  /// Returns true if [abilityId] applied a modifier in the most recent trade
  /// evaluation. Reads directly from [activeModifiers].
  bool isAbilityActive(String abilityId) =>
      activeModifiers.value[abilityId] ?? false;

  /// IDs of abilities the player has earned.
  final Set<String> _unlockedAbilityIds = {};

  /// Which ability ID is currently equipped in each slot (null = empty slot).
  final Map<AbilitySlot, String?> _equippedAbilityIds = {
    AbilitySlot.timing: null,
    AbilitySlot.risk: null,
    AbilitySlot.info: null,
  };

  /// Last real-time swap for each slot — used to enforce the cooldown.
  final Map<AbilitySlot, DateTime?> _lastSwapTime = {
    AbilitySlot.timing: null,
    AbilitySlot.risk: null,
    AbilitySlot.info: null,
  };

  /// Tickers banned from re-buy after a Stop Loss auto-sell.
  /// Maps ticker → ban expiry time.
  final Map<String, DateTime> _stopLossBannedUntil = {};

  /// Whether a global crash event fired on the most recent tick.
  /// Set by MarketProvider; cleared at the start of the next tick.
  bool _crashEventActive = false;

  /// Tracks tickers that dropped 30%+ from avg cost (for Diamond Hands).
  /// Maps ticker → true once the deep-drop was recorded.
  final Map<String, bool> _hasHeldThroughDeepDrop = {};

  /// Pending Contrarian Signal credits (ticker → bonus amount on next sell).
  final Map<String, double> _contrarianCredits = {};

  /// The last generated Insider Tip signal, if any.
  InsiderTipSignal? _lastInsiderTip;

  /// Wall-clock time of the last Insider Tip generation.
  DateTime? _lastInsiderTipTime;

  // ── Crash event flag (called by MarketProvider) ───────────────────────────────

  /// Set by MarketProvider at the start of each tick to indicate whether a
  /// global crash event is included in the events that will fire this tick.
  void setCrashEventActive(bool active) => _crashEventActive = active;

  // ── Read-only accessors ───────────────────────────────────────────────────────

  /// Returns the ability equipped in [slot], or null if the slot is empty.
  Ability? equippedAbility(AbilitySlot slot) {
    final id = _equippedAbilityIds[slot];
    if (id == null) return null;
    try {
      return AbilityRegistry.all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the ability with [id], or null if not found.
  Ability? abilityById(String id) {
    try {
      return AbilityRegistry.all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Returns the time remaining in the swap cooldown for [slot], or null if
  /// the slot is not on cooldown. Used by the UI to show a countdown.
  Duration? swapCooldownRemaining(AbilitySlot slot) {
    final lastSwap = _lastSwapTime[slot];
    if (lastSwap == null) return null;
    final elapsed = DateTime.now().difference(lastSwap);
    final remaining = const Duration(hours: kSwapCooldownHours) - elapsed;
    return remaining.isNegative ? null : remaining;
  }

  /// Pre-flight check for swapping [abilityId] into its slot.
  ///
  /// Returns a [SwapResult] describing whether the swap is currently permitted
  /// and, if not, a human-readable [SwapResult.reason] suitable for display in
  /// a SnackBar. Does NOT perform the swap — call [swapAbility] on confirm.
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

  /// True if [ticker] was auto-sold by Stop Loss and cannot be re-bought yet.
  bool isTickerStopLossBanned(String ticker) {
    final expiry = _stopLossBannedUntil[ticker];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _stopLossBannedUntil.remove(ticker);
      return false;
    }
    return true;
  }

  /// The latest Insider Tip signal, or null if none has been generated yet.
  InsiderTipSignal? get lastInsiderTip => _lastInsiderTip;

  // ── Equip / swap ─────────────────────────────────────────────────────────────

  /// Equips [abilityId] in its slot.
  ///
  /// If the slot is empty, the equip is free and instant.
  /// If a different ability is already equipped, delegates to [swapAbility].
  ///
  /// Returns an error string on failure, null on success.
  String? equipAbility(String abilityId, {required double cashBalance}) {
    final ability = abilityById(abilityId);
    if (ability == null) return 'Unknown ability: $abilityId';
    if (!_unlockedAbilityIds.contains(abilityId)) {
      return '${ability.name} has not been unlocked yet.';
    }

    final current = _equippedAbilityIds[ability.slot];
    if (current == abilityId) return 'Already equipped.';

    if (current == null) {
      // Empty slot — equip for free.
      _equippedAbilityIds[ability.slot] = abilityId;
      stateVersion.value++;
      return null;
    }

    // Slot is occupied — treat as a swap.
    return swapAbility(abilityId, cashBalance: cashBalance);
  }

  /// Swaps the equipped ability in the relevant slot to [abilityId].
  ///
  /// Costs [kSwapCostCurrency] cash and enforces a [kSwapCooldownHours]
  /// real-time cooldown per slot.
  ///
  /// Returns an error string on failure, null on success.
  /// On success, the caller must deduct [kSwapCostCurrency] from cash balance.
  String? swapAbility(String abilityId, {required double cashBalance}) {
    final ability = abilityById(abilityId);
    if (ability == null) return 'Unknown ability: $abilityId';
    if (!_unlockedAbilityIds.contains(abilityId)) {
      return '${ability.name} has not been unlocked yet.';
    }

    // Cooldown check.
    final lastSwap = _lastSwapTime[ability.slot];
    if (lastSwap != null) {
      final elapsed = DateTime.now().difference(lastSwap);
      if (elapsed.inHours < kSwapCooldownHours) {
        final remaining = kSwapCooldownHours - elapsed.inHours;
        return 'Swap on cooldown. Wait $remaining more hour${remaining == 1 ? '' : 's'}.';
      }
    }

    // Cash check.
    if (cashBalance < kSwapCostCurrency) {
      return 'Swapping costs \$${kSwapCostCurrency.toStringAsFixed(0)}. '
          'You need \$${(kSwapCostCurrency - cashBalance).toStringAsFixed(2)} more.';
    }

    // All checks passed — apply the swap.
    _equippedAbilityIds[ability.slot] = abilityId;
    _lastSwapTime[ability.slot] = DateTime.now();
    stateVersion.value++;
    // Cash deduction is performed by the caller after receiving null.
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
  }) {
    final List<String> newlyUnlocked = [];

    void tryUnlock(String id) {
      if (!_unlockedAbilityIds.contains(id)) {
        _unlockedAbilityIds.add(id);
        // Mark the ability object as unlocked.
        final unlockedAbility = abilityById(id);
        if (unlockedAbility != null) {
          unlockedAbility.isUnlocked = true;
          _unlockController.add(unlockedAbility);
        }
        newlyUnlocked.add(id);
      }
    }

    // ── day_trader: sell 10 stocks profitably within 2hrs of buying ─────────
    if (!_unlockedAbilityIds.contains('day_trader')) {
      final qualifyingSells = _countProfitableQuickSells(transactions);
      if (qualifyingSells >= 10) tryUnlock('day_trader');
    }

    // ── patient_investor: hold a stock 3+ simulated days (72+ hrs) ──────────
    if (!_unlockedAbilityIds.contains('patient_investor')) {
      for (final holding in holdings) {
        final firstBuy = _earliestBuyFor(holding.ticker, transactions);
        if (firstBuy != null) {
          final held = DateTime.now().difference(firstBuy);
          if (held.inHours >= 72) {
            tryUnlock('patient_investor');
            break;
          }
        }
      }
    }

    // ── swing_trader: profit from 3 separate volatile event sells ───────────
    // (Tracked via _swingTraderProfitCount incremented in applyTradeModifiers)
    if (!_unlockedAbilityIds.contains('swing_trader') &&
        _swingTraderProfitCount >= 3) {
      tryUnlock('swing_trader');
    }

    // ── diamond_hands: hold through 30%+ drop without selling ───────────────
    if (!_unlockedAbilityIds.contains('diamond_hands')) {
      for (final holding in holdings) {
        final stock = _stockForTicker(holding.ticker, stocks);
        if (stock == null) continue;
        // Check if current price is 30%+ below avg cost (still in the drop)
        // or if we've previously recorded a deep drop for this ticker.
        final dropFraction =
            (holding.averageCost - stock.currentPrice) / holding.averageCost;
        if (dropFraction >= kDiamondHandsDropThreshold) {
          _hasHeldThroughDeepDrop[holding.ticker] = true;
        }
        if (_hasHeldThroughDeepDrop[holding.ticker] == true) {
          tryUnlock('diamond_hands');
          break;
        }
      }
    }

    // ── stop_loss: lose more than 20% on a single trade ─────────────────────
    if (!_unlockedAbilityIds.contains('stop_loss')) {
      for (final tx in transactions.where((t) => t.type == TransactionType.sell)) {
        final buyTx = _earliestBuyTransactionFor(tx.ticker, transactions);
        if (buyTx == null) continue;
        final loss = (tx.pricePerShare - buyTx.pricePerShare) / buyTx.pricePerShare;
        if (loss < -0.20) {
          tryUnlock('stop_loss');
          break;
        }
      }
    }

    // ── hedger: hold stocks in 3 different sectors simultaneously ───────────
    if (!_unlockedAbilityIds.contains('hedger')) {
      final sectors = holdings
          .map((h) => _stockForTicker(h.ticker, stocks)?.sector)
          .where((s) => s != null)
          .toSet();
      if (sectors.length >= 3) tryUnlock('hedger');
    }

    // ── contrarian_signal: buy during correction event and profit ────────────
    // (Tracked via _contrarianProfitAchieved flag set in applyTradeModifiers)
    if (!_unlockedAbilityIds.contains('contrarian_signal') &&
        _contrarianProfitAchieved) {
      tryUnlock('contrarian_signal');
    }

    // ── sector_scout: own stocks in all 7 sectors ────────────────────────────
    if (!_unlockedAbilityIds.contains('sector_scout')) {
      const allSectors = {
        'Technology', 'Energy', 'Healthcare',
        'Finance', 'Consumer', 'Industrial', 'Entertainment',
      };
      final heldSectors = holdings
          .map((h) => _stockForTicker(h.ticker, stocks)?.sector)
          .where((s) => s != null)
          .toSet();
      if (heldSectors.containsAll(allSectors)) tryUnlock('sector_scout');
    }

    // ── insider_tip_ability: 7 consecutive profitable trading days ───────────
    if (!_unlockedAbilityIds.contains('insider_tip_ability') &&
        consecutiveProfitableDays >= 7) {
      tryUnlock('insider_tip_ability');
    }

    return newlyUnlocked;
  }

  // ── Trade modifiers ───────────────────────────────────────────────────────────

  /// Applies equipped ability modifiers to an incoming trade.
  ///
  /// Call this BEFORE executing the trade (so blocks can be enforced).
  ///
  /// Parameters:
  ///   [trade]               — the transaction about to be executed
  ///   [history]             — full transaction history for hold-duration lookup
  ///   [holdings]            — current holdings for Hedger sector lookup
  ///   [stocks]              — current stock list for sector data
  ///   [activeVolatileEvent] — true if a Volatile event fires this tick
  ///   [activeCrashEvent]    — true if a global crash event fires this tick
  TradeModifierResult applyTradeModifiers({
    required Transaction trade,
    required List<Transaction> history,
    required List<PortfolioHolding> holdings,
    required List<Stock> stocks,
    bool activeVolatileEvent = false,
    bool activeCrashEvent = false,
  }) {
    // Initialise modifier-activity tracking: every equipped ability starts false.
    final Map<String, bool> mods = {};
    for (final slot in AbilitySlot.values) {
      final a = equippedAbility(slot);
      if (a != null) mods[a.id] = false;
    }

    // ── Diamond Hands crash lock ─────────────────────────────────────────────
    if (trade.type == TransactionType.sell) {
      final riskAbility = equippedAbility(AbilitySlot.risk);
      if (riskAbility?.id == 'diamond_hands' &&
          (activeCrashEvent || _crashEventActive)) {
        mods['diamond_hands'] = true;
        activeModifiers.value = Map.unmodifiable(mods);
        return const TradeModifierResult.blocked(
          'Diamond Hands: position locked during crash event. '
          'Wait for the event to resolve.',
        );
      }
    }

    // Compute hold duration from transaction history.
    final Duration? holdDuration = trade.type == TransactionType.sell
        ? _holdDurationFor(trade.ticker, history)
        : null;

    // ── Timing slot modifier ─────────────────────────────────────────────────
    double totalBonus = 0.0;
    final timingAbility = equippedAbility(AbilitySlot.timing);
    if (timingAbility != null) {
      // Swing Trader only fires during active volatile events.
      if (timingAbility.id == 'swing_trader') {
        if (activeVolatileEvent && trade.type == TransactionType.sell) {
          final result = timingAbility.onTradeModifier
              ?.call(trade, holdDuration, trade.totalAmount);
          if (result != null) {
            if (result.isBlocked) {
              mods[timingAbility.id] = true;
              activeModifiers.value = Map.unmodifiable(mods);
              return result;
            }
            totalBonus += result.bonusAmount;
            if (result.bonusAmount > 0) {
              mods[timingAbility.id] = true;
              // Track for unlock check.
              _swingTraderProfitCount++;
            }
          }
        }
      } else {
        final result = timingAbility.onTradeModifier
            ?.call(trade, holdDuration, trade.totalAmount);
        if (result != null) {
          if (result.isBlocked) {
            mods[timingAbility.id] = true;
            activeModifiers.value = Map.unmodifiable(mods);
            return result;
          }
          totalBonus += result.bonusAmount;
          if (result.bonusAmount > 0) mods[timingAbility.id] = true;
        }
      }
    }

    // ── Risk slot modifier ───────────────────────────────────────────────────
    final riskAbility = equippedAbility(AbilitySlot.risk);
    if (riskAbility != null && trade.type == TransactionType.sell) {
      if (riskAbility.id == 'diamond_hands') {
        // Diamond Hands bonus: only if stock dropped 30%+ from avg cost
        // and has now recovered above avg cost.
        final holding = holdings.firstWhere(
          (h) => h.ticker == trade.ticker,
          orElse: () => const PortfolioHolding(
              ticker: '', shares: 0, averageCost: 0),
        );
        if (holding.ticker.isNotEmpty &&
            _hasHeldThroughDeepDrop[trade.ticker] == true &&
            trade.pricePerShare >= holding.averageCost) {
          final result = riskAbility.onTradeModifier
              ?.call(trade, holdDuration, trade.totalAmount);
          if (result != null) {
            totalBonus += result.bonusAmount;
            if (result.bonusAmount > 0) mods[riskAbility.id] = true;
          }
          _hasHeldThroughDeepDrop.remove(trade.ticker);
        }
      } else if (riskAbility.id == 'hedger') {
        // Hedger: if selling at a loss, find same-sector gains to offset.
        final holding = holdings.firstWhere(
          (h) => h.ticker == trade.ticker,
          orElse: () => const PortfolioHolding(
              ticker: '', shares: 0, averageCost: 0),
        );
        if (holding.ticker.isNotEmpty) {
          final sellPnl =
              (trade.pricePerShare - holding.averageCost) * trade.shares;
          if (sellPnl < 0) {
            final offset =
                _computeHedgerOffset(trade.ticker, holdings, stocks, sellPnl);
            if (offset > 0) {
              final result = riskAbility.onTradeModifier
                  ?.call(trade, holdDuration, offset);
              if (result != null) {
                totalBonus += result.bonusAmount;
                if (result.bonusAmount > 0) mods[riskAbility.id] = true;
              }
            }
          }
        }
      }
    }

    // ── Info slot modifier ───────────────────────────────────────────────────
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id == 'contrarian_signal') {
      if (trade.type == TransactionType.buy && activeCrashEvent) {
        // Store credit for next sell.
        final credit = trade.totalAmount * kContrarianBonusPct;
        _contrarianCredits[trade.ticker] =
            (_contrarianCredits[trade.ticker] ?? 0) + credit;
      } else if (trade.type == TransactionType.sell) {
        // Apply stored Contrarian credit.
        final credit = _contrarianCredits.remove(trade.ticker) ?? 0.0;
        if (credit > 0) {
          totalBonus += credit;
          mods[infoAbility!.id] = true;
          // Check for profit to unlock the ability.
          if (!_contrarianProfitAchieved) {
            final holding = holdings.firstWhere(
              (h) => h.ticker == trade.ticker,
              orElse: () => const PortfolioHolding(
                  ticker: '', shares: 0, averageCost: 0),
            );
            if (holding.ticker.isNotEmpty &&
                trade.pricePerShare > holding.averageCost) {
              _contrarianProfitAchieved = true;
            }
          }
        }
      }
    }

    activeModifiers.value = Map.unmodifiable(mods);
    return TradeModifierResult(bonusAmount: totalBonus);
  }

  // ── Stop Loss ─────────────────────────────────────────────────────────────────

  /// Returns the tickers of holdings that have breached the Stop Loss threshold.
  /// Call this after each tick's price update.
  ///
  /// The caller is responsible for executing the auto-sells and should call
  /// [recordStopLossSell] after each one so the re-buy ban can be applied.
  List<String> applyStopLossCheck(
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
  ) {
    final riskAbility = equippedAbility(AbilitySlot.risk);
    if (riskAbility?.id != 'stop_loss') return [];

    final List<String> toSell = [];
    for (final holding in holdings) {
      if (isTickerStopLossBanned(holding.ticker)) continue;
      final stock = _stockForTicker(holding.ticker, stocks);
      if (stock == null) continue;
      final dropFraction =
          (holding.averageCost - stock.currentPrice) / holding.averageCost;
      if (dropFraction >= kStopLossThreshold) {
        toSell.add(holding.ticker);
      }
    }
    return toSell;
  }

  /// Records that a Stop Loss auto-sell occurred for [ticker], starting the
  /// re-buy ban timer.
  void recordStopLossSell(String ticker) {
    _stopLossBannedUntil[ticker] =
        DateTime.now().add(const Duration(hours: kStopLossRebuyBanHours));
  }

  // ── Insider Tip ───────────────────────────────────────────────────────────────

  /// Generates an Insider Tip signal if the ability is equipped and the
  /// per-day cooldown has elapsed.
  ///
  /// Returns null if the ability is not equipped, not yet unlocked, or the
  /// cooldown hasn't expired.
  InsiderTipSignal? generateInsiderTip(List<Stock> stocks, Random rng) {
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id != 'insider_tip_ability') return null;
    if (!_unlockedAbilityIds.contains('insider_tip_ability')) return null;

    // Check cooldown.
    if (_lastInsiderTipTime != null) {
      final elapsed = DateTime.now().difference(_lastInsiderTipTime!);
      if (elapsed.inHours < kInsiderTipCooldownHours) return null;
    }

    if (stocks.isEmpty) return null;

    final targetStock = stocks[rng.nextInt(stocks.length)];
    // 25% chance the signal is wrong.
    final trendIsActuallyUp = targetStock.trendDirection == 'up' ||
        (targetStock.trendDirection == 'neutral' && rng.nextBool());
    final bool reportedBullish;
    if (rng.nextDouble() < kInsiderTipErrorRate) {
      // Signal is deliberately wrong.
      reportedBullish = !trendIsActuallyUp;
    } else {
      reportedBullish = trendIsActuallyUp;
    }

    _lastInsiderTip = InsiderTipSignal(
      ticker: targetStock.ticker,
      bullish: reportedBullish,
      isUnverified: true, // always shown as unverified per spec
    );
    _lastInsiderTipTime = DateTime.now();
    return _lastInsiderTip;
  }

  // ── Sector Scout ─────────────────────────────────────────────────────────────

  /// Returns the sector hint for the next tick, or null if Sector Scout is not
  /// equipped or no hint is available yet.
  String? getSectorScoutHint(EventEngine engine) {
    final infoAbility = equippedAbility(AbilitySlot.info);
    if (infoAbility?.id != 'sector_scout') return null;
    if (!_unlockedAbilityIds.contains('sector_scout')) return null;
    return engine.nextSectorHint;
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
      'contrarianCredits': _contrarianCredits,
      'swingTraderCount': _swingTraderProfitCount,
      'contrarianProfitAchieved': _contrarianProfitAchieved,
      'deepDropTickers': _hasHeldThroughDeepDrop,
      'lastTipTime': _lastInsiderTipTime?.toIso8601String(),
    };
    await persistence.saveAbilityState(state);
  }

  Future<void> loadState(PersistenceService persistence) async {
    final state = await persistence.loadAbilityState();
    if (state == null) return;

    final unlocked = (state['unlocked'] as List<dynamic>? ?? []).cast<String>();
    _unlockedAbilityIds.addAll(unlocked);
    for (final id in unlocked) {
      abilityById(id)?.isUnlocked = true;
    }

    final equipped = state['equipped'] as Map<String, dynamic>? ?? {};
    for (final entry in equipped.entries) {
      try {
        final slot = AbilitySlot.values.byName(entry.key);
        _equippedAbilityIds[slot] = entry.value as String?;
      } catch (_) {
        // Unknown slot name — skip.
      }
    }

    final swapTimes = state['swapTimes'] as Map<String, dynamic>? ?? {};
    for (final entry in swapTimes.entries) {
      try {
        final slot = AbilitySlot.values.byName(entry.key);
        _lastSwapTime[slot] =
            entry.value != null ? DateTime.parse(entry.value as String) : null;
      } catch (_) {
        // Skip unknown entries.
      }
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

    _swingTraderProfitCount = (state['swingTraderCount'] as int?) ?? 0;
    _contrarianProfitAchieved =
        (state['contrarianProfitAchieved'] as bool?) ?? false;

    final deepDropMap =
        state['deepDropTickers'] as Map<String, dynamic>? ?? {};
    for (final entry in deepDropMap.entries) {
      _hasHeldThroughDeepDrop[entry.key] = entry.value as bool? ?? false;
    }

    final tipTimeStr = state['lastTipTime'] as String?;
    if (tipTimeStr != null) {
      _lastInsiderTipTime = DateTime.tryParse(tipTimeStr);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  /// Mutable counters for unlock tracking (persisted).
  int _swingTraderProfitCount = 0;
  bool _contrarianProfitAchieved = false;

  /// Counts profitable sell transactions where the hold duration was under
  /// [kDayTraderWindowHours] hours.
  int _countProfitableQuickSells(List<Transaction> transactions) {
    int count = 0;
    for (final tx in transactions.where((t) => t.type == TransactionType.sell)) {
      final buyTx = _earliestBuyTransactionFor(tx.ticker, transactions);
      if (buyTx == null) continue;
      final held = tx.timestamp.difference(buyTx.timestamp);
      final profitable = tx.pricePerShare > buyTx.pricePerShare;
      if (profitable && held.inHours < kDayTraderWindowHours) count++;
    }
    return count;
  }

  /// Wall-clock timestamp of the earliest buy transaction for [ticker] that
  /// has not been fully offset by subsequent sells.
  /// Used to compute how long a position has been held.
  DateTime? _earliestBuyFor(String ticker, List<Transaction> transactions) {
    final buys = transactions
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return buys.isEmpty ? null : buys.first.timestamp;
  }

  /// Returns the earliest buy Transaction object for [ticker], or null.
  Transaction? _earliestBuyTransactionFor(
      String ticker, List<Transaction> transactions) {
    final buys = transactions
        .where((t) => t.ticker == ticker && t.type == TransactionType.buy)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return buys.isEmpty ? null : buys.first;
  }

  /// Duration since the position in [ticker] was first opened.
  /// Returns null if no buy transaction is found.
  Duration? _holdDurationFor(String ticker, List<Transaction> transactions) {
    final earliest = _earliestBuyFor(ticker, transactions);
    if (earliest == null) return null;
    return DateTime.now().difference(earliest);
  }

  /// Computes the Hedger offset amount for a sell at a loss.
  ///
  /// Finds same-sector holdings that have unrealised gains and computes
  /// how much of the loss can be offset (capped at [kHedgerOffsetPct] of loss).
  double _computeHedgerOffset(
    String sellingTicker,
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
    double sellLoss, // negative value
  ) {
    final sellStock = _stockForTicker(sellingTicker, stocks);
    if (sellStock == null) return 0.0;

    double sectorGains = 0.0;
    for (final h in holdings) {
      if (h.ticker == sellingTicker) continue;
      final s = _stockForTicker(h.ticker, stocks);
      if (s == null || s.sector != sellStock.sector) continue;
      final gain = (s.currentPrice - h.averageCost) * h.shares;
      if (gain > 0) sectorGains += gain;
    }

    // Offset is the minimum of: available sector gains and kHedgerOffsetPct
    // of the absolute loss.
    final maxOffset = sellLoss.abs() * kHedgerOffsetPct;
    return sectorGains.clamp(0.0, maxOffset);
  }

  /// Looks up a Stock by ticker from the provided list.
  Stock? _stockForTicker(String ticker, List<Stock> stocks) {
    try {
      return stocks.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }
}
