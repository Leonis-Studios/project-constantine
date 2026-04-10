// ─────────────────────────────────────────────────────────────────────────────
// ability_handler.dart  (lib/systems/abilities/)
//
// PURPOSE: Abstract handler interface and context structs for the ability
//          dispatch system.
//
// HOW IT WORKS:
//   AbilityService keeps a Map<String, AbilityHandler> keyed by ability ID.
//   When a trade, unlock check, or tick fires, the service builds a context
//   struct and dispatches to the handler. This removes all hardcoded ID
//   if-blocks from ability_service.dart.
//
// TO ADD A NEW ABILITY WITH CUSTOM LOGIC:
//   1. Write a class extending AbilityHandler in ability_handlers.dart.
//   2. Register it in AbilityService._buildHandlers().
//   3. Add the Ability definition to ability_registry.dart.
//   No other file needs touching.
// ─────────────────────────────────────────────────────────────────────────────

import '../../models/portfolio_holding.dart';
import '../../models/stock.dart';
import '../../models/transaction.dart';
import '../events/market_event.dart';
import 'ability.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Context structs — plain data carriers, no methods
// ─────────────────────────────────────────────────────────────────────────────

/// Context passed to [AbilityHandler.handleTrade].
class AbilityTradeContext {
  final Transaction trade;
  final Duration? holdDuration;
  final List<PortfolioHolding> holdings;
  final List<Stock> stocks;
  final bool activeVolatileEvent;
  final bool activeCrashEvent;

  /// Shared mutable map owned by AbilityService.
  /// Keys are tickers; true = drop threshold was crossed.
  final Map<String, bool> hasHeldThroughDeepDrop;

  /// Shared mutable map owned by AbilityService (or ContrarianSignalHandler).
  /// Keys are tickers; value = pending credit on next sell.
  final Map<String, double> contrarianCredits;

  /// Current simulated day number (used by IronFlipper, SectorArbiter).
  final int currentDay;

  /// Full transaction history (used by IronFlipper prior-sell check).
  final List<Transaction> history;

  const AbilityTradeContext({
    required this.trade,
    required this.holdDuration,
    required this.holdings,
    required this.stocks,
    required this.activeVolatileEvent,
    required this.activeCrashEvent,
    required this.hasHeldThroughDeepDrop,
    required this.contrarianCredits,
    required this.currentDay,
    required this.history,
  });
}

/// Context passed to [AbilityHandler.checkUnlock].
class AbilityUnlockContext {
  final List<Transaction> transactions;
  final List<PortfolioHolding> holdings;
  final List<Stock> stocks;
  final bool lastTickHadCorrectionEvent;
  final bool lastTickHadVolatileEvent;
  final int consecutiveProfitableDays;
  final bool lastDayWasProfitable;
  final double cashBalance;
  final int currentDay;

  /// The dominant direction of the most recently resolved tick.
  /// Null if no tick has fired yet.
  final EventDirection? lastTickDirection;

  const AbilityUnlockContext({
    required this.transactions,
    required this.holdings,
    required this.stocks,
    required this.lastTickHadCorrectionEvent,
    required this.lastTickHadVolatileEvent,
    required this.consecutiveProfitableDays,
    required this.lastDayWasProfitable,
    required this.cashBalance,
    required this.currentDay,
    required this.lastTickDirection,
  });
}

/// Context passed to [AbilityHandler.tickCheck].
class AbilityTickContext {
  final List<PortfolioHolding> holdings;
  final List<Stock> stocks;

  /// Shared mutable map owned by AbilityService.
  /// Keys are tickers; values are ban-expiry timestamps.
  final Map<String, DateTime> stopLossBannedUntil;

  const AbilityTickContext({
    required this.holdings,
    required this.stocks,
    required this.stopLossBannedUntil,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AbilityHandler — abstract base
// ─────────────────────────────────────────────────────────────────────────────

/// Custom service-side logic for one ability.
///
/// Implement only the methods that the ability actually needs.
/// All methods have no-op defaults so concrete handlers stay minimal.
abstract class AbilityHandler {
  /// Called inside [AbilityService.applyTradeModifiers] for every slot that
  /// has this ability equipped.
  ///
  /// Return a [TradeModifierResult] to override the default modifier logic.
  /// Return null to fall through to the ability's [Ability.onTradeModifier].
  TradeModifierResult? handleTrade(AbilityTradeContext ctx) => null;

  /// Called inside [AbilityService.checkUnlockConditions] for this ability.
  ///
  /// Return true the first time the unlock condition is satisfied.
  /// After that, [AbilityService] will no longer call this handler for the
  /// ability (it skips already-unlocked IDs).
  bool checkUnlock(AbilityUnlockContext ctx) => false;

  /// Called inside [AbilityService.applyStopLossCheck] after each tick.
  ///
  /// Return the list of tickers that should be auto-sold. Most handlers
  /// return an empty list.
  List<String> tickCheck(AbilityTickContext ctx) => const [];

  /// Serialises this handler's private state into a flat map.
  /// Keys must be globally unique (prefix with ability id to be safe).
  Map<String, dynamic> saveState() => const {};

  /// Restores private state from [state] (the full ability-service save map).
  void loadState(Map<String, dynamic> state) {}
}
