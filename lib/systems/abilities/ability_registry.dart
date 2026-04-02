// ─────────────────────────────────────────────────────────────────────────────
// ability_registry.dart  (lib/systems/abilities/)
//
// PURPOSE: The single source of truth for all player ability definitions.
//          All numeric tuning constants live here so balancing is easy.
//
// TO ADD A NEW ABILITY:
//   1. Declare a new `static final Ability` below, in the correct slot section.
//   2. Add it to the `all` list at the bottom.
//   That's it — no other file needs changing.
//
// NOTE ON const:
//   Ability instances hold function fields (onTradeModifier / onHoldModifier),
//   so they cannot be `const`. All instances are `static final` instead.
// ─────────────────────────────────────────────────────────────────────────────

import '../../models/transaction.dart';
import 'ability.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TUNING CONSTANTS
//
// Every magic number used in ability modifiers lives here with a comment
// explaining the gameplay effect of raising or lowering it.
// ═══════════════════════════════════════════════════════════════════════════════

// ── TIMING slot ──────────────────────────────────────────────────────────────

/// Hours a position must be held to qualify for the Day Trader bonus.
/// Lower → easier to earn the bonus (more forgiving for slow players).
const int kDayTraderWindowHours = 2;

/// Bonus percentage added to sell proceeds for qualifying Day Trader sells.
/// Raise to reward aggressive short-term flipping more generously.
const double kDayTraderBonusPct = 0.05; // +5%

/// Penalty percentage subtracted from sell proceeds when holding over 24hrs
/// with Day Trader equipped. Raise to punish long holds more harshly.
const double kDayTraderPenaltyPct = 0.03; // −3%

/// Hours a position must be held before selling is allowed with Patient Investor.
/// Raise to make the block window stricter; lower to ease new players in.
const int kPatientInvestorBlockHours = 4;

/// Hours a position must be held to earn the Patient Investor bonus on sell.
/// Should always be ≥ kPatientInvestorBlockHours.
const int kPatientInvestorBonusHours = 24;

/// Bonus percentage added to sell proceeds for qualifying Patient Investor sells.
/// Raise to reward long-term holding more generously.
const double kPatientInvestorBonusPct = 0.08; // +8%

/// Bonus percentage for Swing Trader sells during a Volatile event tick.
/// Raise to make event-timing more rewarding.
const double kSwingTraderBonusPct = 0.04; // +4%

// ── RISK slot ────────────────────────────────────────────────────────────────

/// Fractional drop from average cost required before Diamond Hands bonus applies.
/// Lower to make the bonus easier to earn (e.g. 0.20 = only 20% drop needed).
const double kDiamondHandsDropThreshold = 0.30; // 30% drop

/// Bonus percentage added to sell proceeds after a Diamond Hands recovery.
/// Raise to reward holding through crashes more generously.
const double kDiamondHandsBonusPct = 0.10; // +10%

/// Fractional drop from average cost that triggers Stop Loss auto-sell.
/// Lower to make the safety net trigger sooner; raise to allow more drawdown.
const double kStopLossThreshold = 0.15; // 15% drop

/// Real-time hours after a Stop Loss auto-sell during which the player
/// cannot re-buy the same ticker. Raise to extend the re-buy ban.
const int kStopLossRebuyBanHours = 1;

/// Maximum fraction of a loss that Hedger can offset from same-sector gains.
/// Raise to make cross-sector hedging more powerful (max 1.0 = full offset).
const double kHedgerOffsetPct = 0.20; // 20% offset cap

// ── INFO slot ────────────────────────────────────────────────────────────────

/// Bonus percentage added to buy proceeds (as a credit on next sell) when
/// Contrarian Signal triggers. Raise to reward contrarian buying more.
const double kContrarianBonusPct = 0.06; // +6%

/// Probability (0.0–1.0) that the Insider Tip signal is wrong.
/// Lower to make tips more reliable; raise to add more uncertainty.
const double kInsiderTipErrorRate = 0.25; // 25% wrong

/// Real-time hours between Insider Tip ability activations.
/// Raise to limit tip frequency; lower to allow more frequent signals.
const int kInsiderTipCooldownHours = 24;

// ─────────────────────────────────────────────────────────────────────────────
// ABILITY DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class AbilityRegistry {

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT 1 — TIMING
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability dayTrader = Ability(
    id: 'day_trader',
    name: 'Day Trader',
    description:
        '+${(kDayTraderBonusPct * 100).toStringAsFixed(0)}% on any stock sold '
        'within $kDayTraderWindowHours hours of buying.',
    slot: AbilitySlot.timing,
    unlockCondition: 'Sell 10 stocks profitably within $kDayTraderWindowHours hours of buying.',
    constraint:
        '−${(kDayTraderPenaltyPct * 100).toStringAsFixed(0)}% penalty on any '
        'stock held over 24 hours.',
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.sell) return TradeModifierResult.none;
      if (holdDuration == null) return TradeModifierResult.none;

      if (holdDuration.inHours < kDayTraderWindowHours) {
        // Sold within the bonus window — apply bonus.
        return TradeModifierResult.bonus(baseAmount * kDayTraderBonusPct);
      } else if (holdDuration.inHours >= 24) {
        // Held too long — apply penalty.
        return TradeModifierResult.bonus(-baseAmount * kDayTraderPenaltyPct);
      }
      return TradeModifierResult.none;
    },
  );

  static final Ability patientInvestor = Ability(
    id: 'patient_investor',
    name: 'Patient Investor',
    description:
        '+${(kPatientInvestorBonusPct * 100).toStringAsFixed(0)}% on stocks held '
        'over $kPatientInvestorBonusHours hours before selling.',
    slot: AbilitySlot.timing,
    unlockCondition: 'Hold any single stock for 3 consecutive simulated days.',
    constraint:
        'Cannot sell any position within the first $kPatientInvestorBlockHours hours of buying.',
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.sell) return TradeModifierResult.none;
      if (holdDuration == null) return TradeModifierResult.none;

      if (holdDuration.inHours < kPatientInvestorBlockHours) {
        return const TradeModifierResult.blocked(
          'Patient Investor: cannot sell within $kPatientInvestorBlockHours hours of buying.',
        );
      }
      if (holdDuration.inHours >= kPatientInvestorBonusHours) {
        return TradeModifierResult.bonus(baseAmount * kPatientInvestorBonusPct);
      }
      return TradeModifierResult.none;
    },
  );

  static final Ability swingTrader = Ability(
    id: 'swing_trader',
    name: 'Swing Trader',
    description:
        '+${(kSwingTraderBonusPct * 100).toStringAsFixed(0)}% when selling '
        'during an active price spike (Volatile) event.',
    slot: AbilitySlot.timing,
    unlockCondition: 'Profit from 3 separate Volatile market events.',
    constraint: 'No bonus applies outside of active Volatile events.',
    // The volatile-event flag is checked externally in AbilityService and
    // passed through the trade context. The modifier itself just applies the
    // bonus unconditionally when called — the service gates the call.
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.sell) return TradeModifierResult.none;
      return TradeModifierResult.bonus(baseAmount * kSwingTraderBonusPct);
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT 2 — RISK
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability diamondHands = Ability(
    id: 'diamond_hands',
    name: 'Diamond Hands',
    description:
        '+${(kDiamondHandsBonusPct * 100).toStringAsFixed(0)}% if you hold '
        'through a crash and the price recovers above your buy price.',
    slot: AbilitySlot.risk,
    unlockCondition:
        'Hold a stock through a ${(kDiamondHandsDropThreshold * 100).toStringAsFixed(0)}% '
        'price drop without selling.',
    constraint:
        'Position is locked during active global crash events — '
        'cannot sell until the crash event resolves.',
    // Bonus is applied by AbilityService when it detects recovery.
    // The modifier here handles the bonus amount calculation.
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.sell) return TradeModifierResult.none;
      return TradeModifierResult.bonus(baseAmount * kDiamondHandsBonusPct);
    },
  );

  static final Ability stopLoss = Ability(
    id: 'stop_loss',
    name: 'Stop Loss',
    description:
        'Auto-sells a position if it drops '
        '${(kStopLossThreshold * 100).toStringAsFixed(0)}% from your buy price, '
        'preventing further loss.',
    slot: AbilitySlot.risk,
    unlockCondition: 'Lose more than 20% on a single stock position once.',
    constraint:
        'If price recovers after auto-sell, you miss the recovery and '
        'cannot re-buy for $kStopLossRebuyBanHours hour.',
    // Auto-sell logic is handled in AbilityService.applyStopLossCheck().
    // No onTradeModifier needed — this ability acts on market ticks, not
    // manual trades.
  );

  static final Ability hedger = Ability(
    id: 'hedger',
    name: 'Hedger',
    description:
        'Gains on one stock offset losses on another in the same sector, '
        'reducing net loss by up to ${(kHedgerOffsetPct * 100).toStringAsFixed(0)}%.',
    slot: AbilitySlot.risk,
    unlockCondition: 'Hold stocks in 3 different sectors simultaneously.',
    constraint:
        'Only applies within the same sector. '
        'Offset is capped at ${(kHedgerOffsetPct * 100).toStringAsFixed(0)}% maximum.',
    // Hedger bonus is calculated in AbilityService using portfolio context.
    // The modifier receives the pre-calculated offset amount as baseAmount.
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.sell) return TradeModifierResult.none;
      // baseAmount here is the pre-calculated offset passed by AbilityService.
      return TradeModifierResult.bonus(baseAmount);
    },
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT 3 — INFO
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability contrarianSignal = Ability(
    id: 'contrarian_signal',
    name: 'Contrarian Signal',
    description:
        '+${(kContrarianBonusPct * 100).toStringAsFixed(0)}% credit applied to '
        'your next sell when buying during a mass correction/crash event.',
    slot: AbilitySlot.info,
    unlockCondition: 'Buy during a mass sell-off (correction) event and profit.',
    constraint:
        'Only triggers when the engine confirms a correction/anti-whale event '
        'is active — not on demand.',
    // Bonus is applied as a credit on the NEXT sell, tracked in AbilityService.
    // The modifier is called for buy transactions during qualifying events.
    onTradeModifier: (trade, holdDuration, baseAmount) {
      if (trade.type != TransactionType.buy) return TradeModifierResult.none;
      // Returns the credit amount; AbilityService stores it per-ticker.
      return TradeModifierResult.bonus(baseAmount * kContrarianBonusPct);
    },
  );

  static final Ability sectorScout = Ability(
    id: 'sector_scout',
    name: 'Sector Scout',
    description:
        'See which sector will be affected by the next market event, '
        'one tick before it fires.',
    slot: AbilitySlot.info,
    unlockCondition: 'Own stocks in every available sector at once (7 sectors).',
    constraint:
        'Reveals the sector only — not the specific stock or direction '
        'of the upcoming event.',
    // No modifier function — this ability exposes data via
    // AbilityService.getSectorScoutHint(engine).
  );

  static final Ability insiderTipAbility = Ability(
    id: 'insider_tip_ability',
    name: 'Insider Tip',
    description:
        'Once per day, receive a signal on one random stock showing whether '
        'it will trend up or down next tick.',
    slot: AbilitySlot.info,
    unlockCondition: 'Complete 7 consecutive profitable trading days.',
    constraint:
        'Signal has a ${(kInsiderTipErrorRate * 100).toStringAsFixed(0)}% '
        'chance of being wrong. Shown clearly as "unverified intel."',
    // Tip generation is handled by AbilityService.generateInsiderTip().
    // No modifier function needed here.
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // MASTER LIST
  //
  // Add new Ability instances above, then reference them here.
  // AbilityService.checkUnlockConditions() iterates this list.
  // ═══════════════════════════════════════════════════════════════════════════

  static final List<Ability> all = [
    // Timing slot
    dayTrader,
    patientInvestor,
    swingTrader,
    // Risk slot
    diamondHands,
    stopLoss,
    hedger,
    // Info slot
    contrarianSignal,
    sectorScout,
    insiderTipAbility,
  ];
}
