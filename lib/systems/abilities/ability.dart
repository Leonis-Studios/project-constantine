// ─────────────────────────────────────────────────────────────────────────────
// ability.dart  (lib/systems/abilities/)
//
// PURPOSE: Base model and supporting types for the player ability system.
//          Abilities are passive modifiers equippable in one of three slots.
//
// EXTENSIBILITY:
//   Adding a new ability requires only adding an entry to ability_registry.dart.
//   No changes to this file are needed unless the model shape changes.
//
// WHY NOT const:
//   Ability instances hold optional function references (onTradeModifier,
//   onHoldModifier). Dart does not allow const objects with function fields,
//   so the registry uses `static final` instead.
// ─────────────────────────────────────────────────────────────────────────────

import '../../models/transaction.dart';

// ── Slot categories ────────────────────────────────────────────────────────────
//
// Players have exactly three slots, one per category.
// Only one ability may be equipped per slot at any time.

enum AbilitySlot {
  /// Slot 1 — abilities that reward or penalise based on hold duration.
  timing,

  /// Slot 2 — abilities that manage risk exposure.
  risk,

  /// Slot 3 — abilities that provide information advantages.
  info,
}

// ── Modifier return type ───────────────────────────────────────────────────────

/// The result returned by an ability's trade modifier function.
///
/// A result can either block the trade entirely, add a cash bonus/penalty to
/// the proceeds, or both signals can be neutral (no effect).
class TradeModifierResult {
  /// If true the trade must not proceed. [blockReason] will be non-null.
  final bool isBlocked;

  /// Human-readable explanation shown to the player when [isBlocked] is true.
  /// Null when the trade is allowed.
  final String? blockReason;

  /// Extra cash to add to (positive) or subtract from (negative) the sell
  /// proceeds AFTER the normal trade calculation. Zero means no effect.
  final double bonusAmount;

  const TradeModifierResult({
    this.isBlocked = false,
    this.blockReason,
    this.bonusAmount = 0.0,
  });

  /// Convenience constructor: trade is allowed with a cash bonus/penalty.
  const TradeModifierResult.bonus(double amount)
      : isBlocked = false,
        blockReason = null,
        bonusAmount = amount;

  /// Convenience constructor: trade is blocked with a reason.
  const TradeModifierResult.blocked(String reason)
      : isBlocked = true,
        blockReason = reason,
        bonusAmount = 0.0;

  /// Convenience constructor: no effect on the trade at all.
  static const TradeModifierResult none = TradeModifierResult();
}

// ── Modifier function signatures ───────────────────────────────────────────────

/// Called when the player executes a trade (buy or sell).
///
/// Parameters:
///   [trade]        — the transaction being processed
///   [holdDuration] — how long the player has held this ticker; null if no
///                    prior holding was found in transaction history
///   [baseAmount]   — the gross cash value of the trade (shares × price)
///
/// Return a [TradeModifierResult] describing any block or bonus to apply.
typedef TradeModifierFn = TradeModifierResult Function(
  Transaction trade,
  Duration? holdDuration,
  double baseAmount,
);

// ── Ability model ──────────────────────────────────────────────────────────────

/// A passive player ability that modifies trade outcomes or provides
/// information advantages.
///
/// Abilities are defined as `static final` instances in [AbilityRegistry].
/// The [isUnlocked] field is the only mutable field — it is managed at runtime
/// by [AbilityService] and persisted to local storage.
class Ability {
  /// Unique identifier. Persisted to local storage to track unlock/equip state.
  final String id;

  /// Display name shown in the ability selection UI.
  final String name;

  /// Short description of the bonus this ability provides.
  final String description;

  /// Which slot category this ability occupies.
  final AbilitySlot slot;

  /// Human-readable description of how to earn this ability.
  final String unlockCondition;

  /// The built-in tradeoff — every ability has one, never null.
  /// Shown alongside the description so players can make informed choices.
  final String constraint;

  /// Optional modifier applied when the player executes a buy or sell trade.
  /// Null means the ability does not react to trades directly.
  final TradeModifierFn? onTradeModifier;

  /// Optional modifier applied on a per-holding basis (e.g. time-based checks).
  /// Called with the same signature as [onTradeModifier].
  final TradeModifierFn? onHoldModifier;

  /// Whether the player has met the unlock condition for this ability.
  /// Starts false; set to true by [AbilityService.checkUnlockConditions].
  bool isUnlocked;

  Ability({
    required this.id,
    required this.name,
    required this.description,
    required this.slot,
    required this.unlockCondition,
    required this.constraint,
    this.onTradeModifier,
    this.onHoldModifier,
    this.isUnlocked = false,
  });
}
