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

// ── TIMING slot — iron_flipper ────────────────────────────────────────────────

/// Number of profitable quick-sells required in a single simulated day to
/// unlock Iron Flipper. Higher = harder to earn.
const int kIronFlipperUnlockCount = 15;

/// Bonus percentage on sells of a ticker the player has sold profitably before.
const double kIronFlipperBonusPct = 0.09; // +9%

/// Penalty percentage on sells of a ticker never previously sold profitably.
const double kIronFlipperPenaltyPct = 0.06; // −6%

// ── TIMING slot — trend_surfer ────────────────────────────────────────────────

/// Number of distinct tickers the player must sell profitably during a strong
/// uptrend (≥ kTrendSurferMinDaysRemaining) to unlock Trend Surfer.
const int kTrendSurferUnlockTickers = 8;

/// Minimum trendDaysRemaining on a stock for the Trend Surfer bonus to apply.
/// Prevents the bonus from triggering when a trend is already peaking.
const int kTrendSurferMinDaysRemaining = 3;

/// Bonus percentage for qualifying Trend Surfer sells.
const double kTrendSurferBonusPct = 0.08; // +8%

// ── RISK slot — sector_arbiter ────────────────────────────────────────────────

/// Number of distinct sectors that must have a profitable sell in one
/// simulated day to unlock Sector Arbiter.
const int kSectorArbiterUnlockSectors = 5;

/// Minimum number of stocks the player must hold in the same sector
/// (including the one being sold) for the Sector Arbiter bonus to apply.
const int kSectorArbiterMinSameSectorCount = 3;

/// Fraction of a loss offset when selling at a loss with Sector Arbiter.
const double kSectorArbiterLossReductionPct = 0.40; // 40%

/// Bonus percentage added to sells at a profit with Sector Arbiter.
const double kSectorArbiterProfitBonusPct = 0.06; // +6%

// ── RISK slot — scar_tissue ───────────────────────────────────────────────────

/// Number of distinct losing trading days required to unlock Scar Tissue.
const int kScarTissueUnlockLossDays = 10;

/// Bonus per losing day that stacks on the next sell.
const double kScarTissueStackBonusPerDay = 0.01; // +1% per day

/// Maximum total sell bonus from stacked losing days.
const int kScarTissueMaxStack = 10; // caps at +10%

/// Minimum cash balance required to keep accumulating Scar Tissue stacks.
/// Prevents the ability from stacking while effectively bankrupt.
const double kScarTissueMinCash = 50.0;

// ── INFO slot — macro_analyst ─────────────────────────────────────────────────

/// Number of correctly-timed directional trades required to unlock Macro Analyst.
const int kMacroAnalystUnlockCalls = 10;

/// Probability that the Macro Analyst direction hint is wrong.
const double kMacroHintErrorRate = 0.30; // 30% wrong

/// Real-time hours between Macro Analyst hint activations.
const int kMacroHintCooldownHours = 24;

// ── INFO slot — pattern_recognition ──────────────────────────────────────────

/// Number of simultaneously uptrending holdings required to unlock
/// Pattern Recognition.
const int kPatternRecognitionUnlockCount = 6;

/// Minimum trendDaysRemaining for the Pattern Recognition profit bonus.
const int kPatternRecognitionMinDaysRemaining = 2;

/// Bonus percentage for sells during an uptrend with sufficient days remaining.
const double kPatternRecognitionBonusPct = 0.04; // +4%

/// Penalty percentage for sells of stocks currently in a downtrend.
const double kPatternRecognitionPenaltyPct = 0.03; // −3%

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
  // SLOT 1 — TIMING (advanced)
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability ironFlipper = Ability(
    id: 'iron_flipper',
    name: 'Iron Flipper',
    description:
        '+${(kIronFlipperBonusPct * 100).toStringAsFixed(0)}% on sells of '
        'tickers you have previously sold profitably.',
    slot: AbilitySlot.timing,
    unlockCondition:
        'Execute $kIronFlipperUnlockCount profitable quick-sells '
        '(under ${kDayTraderWindowHours}h hold) within a single trading day.',
    constraint:
        '−${(kIronFlipperPenaltyPct * 100).toStringAsFixed(0)}% on sells of '
        'any ticker you have never previously sold profitably.',
    // Logic handled entirely by IronFlipperHandler — no onTradeModifier needed.
  );

  static final Ability trendSurfer = Ability(
    id: 'trend_surfer',
    name: 'Trend Surfer',
    description:
        '+${(kTrendSurferBonusPct * 100).toStringAsFixed(0)}% when selling a '
        'stock in a strong uptrend ($kTrendSurferMinDaysRemaining+ trend days remaining).',
    slot: AbilitySlot.timing,
    unlockCondition:
        'Sell $kTrendSurferUnlockTickers different stocks profitably while each '
        'had an uptrend with $kTrendSurferMinDaysRemaining+ days remaining.',
    constraint:
        'No bonus if the trend has 1 or fewer days remaining — '
        'you must catch the trend early, not at the peak.',
    // Logic handled by TrendSurferHandler — needs List<Stock> access.
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT 2 — RISK (advanced)
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability sectorArbiter = Ability(
    id: 'sector_arbiter',
    name: 'Sector Arbiter',
    description:
        'When selling in a sector where you hold $kSectorArbiterMinSameSectorCount+ '
        'stocks: losses reduced by '
        '${(kSectorArbiterLossReductionPct * 100).toStringAsFixed(0)}%, '
        'profits boosted by '
        '+${(kSectorArbiterProfitBonusPct * 100).toStringAsFixed(0)}%.',
    slot: AbilitySlot.risk,
    unlockCondition:
        'In a single trading day, record profitable sells in '
        '$kSectorArbiterUnlockSectors or more distinct sectors.',
    constraint:
        'No bonus if you hold fewer than $kSectorArbiterMinSameSectorCount '
        'stocks in the selling sector.',
    // Logic handled by SectorArbiterHandler.
  );

  static final Ability scarTissue = Ability(
    id: 'scar_tissue',
    name: 'Scar Tissue',
    description:
        'Each losing trading day stacks +'
        '${(kScarTissueStackBonusPerDay * 100).toStringAsFixed(0)}% on your '
        'next sell (up to +$kScarTissueMaxStack% max).',
    slot: AbilitySlot.risk,
    unlockCondition:
        'Lose money on $kScarTissueUnlockLossDays distinct trading days '
        'without going bankrupt (keep cash above \$${kScarTissueMinCash.toStringAsFixed(0)})'
        '.',
    constraint:
        'Stack resets to 0 after any profitable trading day. '
        'Bonus only applies while the stack is active.',
    // Logic handled by ScarTissueHandler.
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SLOT 3 — INFO (advanced)
  // ═══════════════════════════════════════════════════════════════════════════

  static final Ability macroAnalyst = Ability(
    id: 'macro_analyst',
    name: 'Macro Analyst',
    description:
        'Once per day, see whether the next market tick will trend '
        'bullish or bearish — with '
        '${((1 - kMacroHintErrorRate) * 100).toStringAsFixed(0)}% accuracy.',
    slot: AbilitySlot.info,
    unlockCondition:
        'Correctly anticipate $kMacroAnalystUnlockCalls market direction '
        'changes — buy before a bullish flip or sell before a bearish flip.',
    constraint:
        'Direction only — not sector or specific event. '
        '${(kMacroHintErrorRate * 100).toStringAsFixed(0)}% chance of being '
        'wrong, shown as "unverified forecast."',
    // Logic handled by MacroAnalystHandler via AbilityService.getMacroDirectionHint().
  );

  static final Ability patternRecognition = Ability(
    id: 'pattern_recognition',
    name: 'Pattern Recognition',
    description:
        '+${(kPatternRecognitionBonusPct * 100).toStringAsFixed(0)}% when '
        'selling a stock in an uptrend with $kPatternRecognitionMinDaysRemaining+ '
        'days remaining.',
    slot: AbilitySlot.info,
    unlockCondition:
        'Hold $kPatternRecognitionUnlockCount or more stocks simultaneously '
        'that are all trending up.',
    constraint:
        '−${(kPatternRecognitionPenaltyPct * 100).toStringAsFixed(0)}% on '
        'sells of stocks currently in a downtrend.',
    // Logic handled by PatternRecognitionHandler — needs List<Stock> access.
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
    ironFlipper,
    trendSurfer,
    // Risk slot
    diamondHands,
    stopLoss,
    hedger,
    sectorArbiter,
    scarTissue,
    // Info slot
    contrarianSignal,
    sectorScout,
    insiderTipAbility,
    macroAnalyst,
    patternRecognition,
  ];
}
