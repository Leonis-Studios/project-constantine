// ─────────────────────────────────────────────────────────────────────────────
// event_engine.dart  (lib/systems/events/)
//
// PURPOSE: Replaces the pure-random event selection in SimulationEngine with a
//          weighted scoring system that keeps the market feeling fair and
//          interesting over extended play sessions.
//
// BALANCING FACTORS (applied each tick):
//   1. Market health check — prevents extended one-direction streaks
//   2. Wealth gap check    — corrects a dominant position in the portfolio
//   3. Catch-up trigger    — helps a recovering portfolio get back on its feet
//   4. Cooldown filter     — prevents the same event repeating too soon
//   5. Volatility dampener — reduces impact magnitude during chaotic stretches
//
// FINAL SELECTION:
//   Top-N candidates by score enter a weighted random draw.
//   At most kMaxEventsPerTick events fire per tick.
//
// STATE PERSISTENCE:
//   Only lightweight rolling state is persisted (last-fired times, recent
//   directions, recent magnitudes, portfolio peak). Session logs are not saved.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../../models/stock.dart';
import '../../models/portfolio_holding.dart';
import '../../services/persistence_service.dart';
import 'market_event.dart';
import 'event_registry.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TUNING CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum events that can fire in a single tick.
/// Raise to allow more simultaneous market news; lower for a calmer feed.
const int kMaxEventsPerTick = 2;

/// Number of top-scoring candidates that enter the final weighted random draw.
/// Raise for more outcome variety; lower for more deterministic high-score wins.
const int kTopCandidateCount = 3;

/// Consecutive bullish ticks before bearish/volatile events get a weight boost.
/// Lower to make corrections kick in sooner; raise for longer bull runs.
const int kBullishStreakThreshold = 3;

/// Consecutive bearish ticks before bullish/recovery events get a weight boost.
/// Lower to accelerate recovery; raise to allow deeper bear markets.
const int kBearishStreakThreshold = 3;

/// Fractional weight multiplier added when a streak condition is met.
/// Raise for more dramatic reversals; lower for gentler market breathing.
const double kStreakWeightBoost = 0.40; // +40%

/// Ratio of largest-position value to median-position value that triggers mild
/// anti-whale / correction weighting. Lower to correct imbalances earlier.
const double kWealthGapRatioMild = 3.0;

/// Ratio threshold for severe imbalance — triggers a guaranteed correction
/// event within kGuaranteedCorrectionWindow ticks.
const double kWealthGapRatioSevere = 5.0;

/// Fractional weight multiplier added to correction/anti-whale events when
/// wealth gap ratio exceeds kWealthGapRatioMild.
const double kWealthGapWeightBoost = 0.50; // +50%

/// Fractional portfolio drop from personal peak that activates the catch-up
/// boost on bullish events. Lower to trigger catch-up sooner.
const double kCatchUpDropThreshold = 0.40; // 40% drop from peak

/// Fractional weight multiplier added to bullish events when catch-up is active.
/// Raise to give a struggling portfolio a stronger tailwind.
const double kCatchUpWeightBoost = 0.30; // +30%

/// Number of ticks of magnitude history used for the volatility score.
/// Raise to smooth out spikes; lower for a more reactive dampener.
const int kVolatilityHistoryLength = 5;

/// Normalised volatility score (0.0–1.0) above which dampening kicks in.
/// Lower to activate dampening earlier; raise to tolerate more chaos.
const double kHighVolatilityThreshold = 0.60;

/// Fraction by which the next events' magnitude is multiplied when dampening.
/// Raise to suppress chaotic stretches more aggressively.
const double kVolatilityMagnitudeDampener = 0.30; // reduce magnitude by 30%

/// Ticks within which a guaranteed correction event fires after severe wealth
/// gap is detected. Lower for faster punishment; raise for a grace period.
const int kGuaranteedCorrectionWindow = 3;

// ─────────────────────────────────────────────────────────────────────────────
// Internal types
// ─────────────────────────────────────────────────────────────────────────────

/// Internal record of why a particular event was selected (for logging).
class _SelectionLog {
  final String eventId;
  final double score;
  final List<String> influencingFactors;
  const _SelectionLog(this.eventId, this.score, this.influencingFactors);
}

/// Lightweight wrapper that pairs a definition with a scaled magnitude,
/// used only during the dampening step to avoid mutating const instances.
class _ScoredEvent {
  final MarketEventDefinition definition;
  final double score;
  final double effectiveMagnitude; // after dampening, if any
  _ScoredEvent(this.definition, this.score, this.effectiveMagnitude);
}

// ─────────────────────────────────────────────────────────────────────────────
// EventEngine
// ─────────────────────────────────────────────────────────────────────────────

class EventEngine {
  // ── Rolling state ────────────────────────────────────────────────────────────

  /// Direction of each recent tick, newest last.
  /// Used to detect bullish/bearish streaks.
  final List<EventDirection> _recentDirections = [];

  /// Real-time timestamps of the last fire for each event ID.
  /// Used to enforce per-event cooldowns.
  final Map<String, DateTime> _lastFiredTimes = {};

  /// Magnitude of events from recent ticks, newest last.
  /// Used to compute the rolling volatility score.
  final List<double> _recentMagnitudes = [];

  /// The highest total portfolio value the player has ever reached.
  /// Used as the reference point for the catch-up trigger.
  double _playerPeakPortfolioValue = 0.0;

  /// Countdown ticks until a guaranteed correction event fires.
  /// Set to kGuaranteedCorrectionWindow when a severe wealth gap is detected.
  int _ticksUntilGuaranteedCorrection = 0;

  // ── Derived state exposed for abilities ─────────────────────────────────────

  /// The sector (or 'ALL' / 'COMPANY') that the engine predicts will be
  /// affected on the NEXT tick. Exposed for the Sector Scout ability.
  String? _nextSectorHint;

  String? get nextSectorHint => _nextSectorHint;

  /// Per-session log of selection decisions. Not persisted.
  final List<_SelectionLog> _log = [];

  /// Read-only view of the selection log for debugging (id + score pairs).
  List<Map<String, dynamic>> get selectionLog => List.unmodifiable(
        _log.map((e) => {'id': e.eventId, 'score': e.score}).toList(),
      );

  // ── Main entry point ─────────────────────────────────────────────────────────

  /// Selects which events will fire this tick using weighted scoring.
  ///
  /// Parameters:
  ///   [stocks]       — current stock prices (used for holding value calc)
  ///   [holdings]     — player's current holdings (for wealth gap & catch-up)
  ///   [cashBalance]  — player's current cash (included in portfolio value)
  ///   [rng]          — random number generator for weighted draw
  ///
  /// Returns up to [kMaxEventsPerTick] event definitions to fire.
  List<MarketEventDefinition> selectEvents({
    required List<Stock> stocks,
    required List<PortfolioHolding> holdings,
    required double cashBalance,
    required Random rng,
  }) {
    // ── Step 1: Compute market state ────────────────────────────────────────
    final double portfolioValue =
        _computePortfolioValue(holdings, stocks, cashBalance);
    if (portfolioValue > _playerPeakPortfolioValue) {
      _playerPeakPortfolioValue = portfolioValue;
    }

    final int bullishStreak = _countTrailingStreak(EventDirection.bullish);
    final int bearishStreak = _countTrailingStreak(EventDirection.bearish);
    final double wealthGapRatio = _computeWealthGapRatio(holdings, stocks);
    final bool isCatchUpActive = _playerPeakPortfolioValue > 0 &&
        portfolioValue <
            _playerPeakPortfolioValue * (1.0 - kCatchUpDropThreshold);
    final double volatilityScore = _computeVolatilityScore();
    final bool isDampening = volatilityScore > kHighVolatilityThreshold;

    // ── Step 2: Handle severe wealth gap countdown ──────────────────────────
    if (wealthGapRatio > kWealthGapRatioSevere &&
        _ticksUntilGuaranteedCorrection <= 0) {
      _ticksUntilGuaranteedCorrection = kGuaranteedCorrectionWindow;
    }

    // ── Step 3: Score all cooled-down events ────────────────────────────────
    final List<_ScoredEvent> scored = [];

    for (final event in EventRegistry.all) {
      if (!_isCooledDown(event)) continue;

      double weight = event.baseProbability * 100.0;
      final List<String> factors = [];

      // Market health — streak correction
      if (bullishStreak >= kBullishStreakThreshold &&
          (event.direction == EventDirection.bearish ||
              event.direction == EventDirection.volatile)) {
        weight *= (1.0 + kStreakWeightBoost);
        factors.add('bullish-streak-correction');
      }
      if (bearishStreak >= kBearishStreakThreshold &&
          (event.direction == EventDirection.bullish)) {
        weight *= (1.0 + kStreakWeightBoost);
        factors.add('bearish-streak-recovery');
      }
      // Crash-recovery tag also gets the streak boost
      if (bearishStreak >= kBearishStreakThreshold &&
          event.balancingTags.contains('crash-recovery')) {
        weight *= (1.0 + kStreakWeightBoost);
        if (!factors.contains('bearish-streak-recovery')) {
          factors.add('crash-recovery-boost');
        }
      }

      // Wealth gap correction
      if (wealthGapRatio > kWealthGapRatioMild &&
          (event.balancingTags.contains('anti-whale') ||
              event.balancingTags.contains('correction'))) {
        weight *= (1.0 + kWealthGapWeightBoost);
        factors.add('wealth-gap-correction');
      }

      // Catch-up boost for bullish events
      if (isCatchUpActive && event.direction == EventDirection.bullish) {
        weight *= (1.0 + kCatchUpWeightBoost);
        factors.add('catch-up');
      }
      if (isCatchUpActive && event.balancingTags.contains('catch-up')) {
        weight *= (1.0 + kCatchUpWeightBoost);
        if (!factors.contains('catch-up')) factors.add('catch-up-tag');
      }

      // Apply volatility dampening to magnitude (not weight)
      final double effectiveMag = isDampening
          ? event.magnitude * (1.0 - kVolatilityMagnitudeDampener)
          : event.magnitude;

      scored.add(_ScoredEvent(event, weight, effectiveMag));
    }

    if (scored.isEmpty) return [];

    // ── Step 4: Sort and take top candidates ────────────────────────────────
    scored.sort((a, b) => b.score.compareTo(a.score));
    final candidates = scored.take(kTopCandidateCount).toList();

    // ── Step 5: Weighted random draw ────────────────────────────────────────
    final List<MarketEventDefinition> selected = [];
    final Set<String> usedIds = {};

    for (int i = 0; i < kMaxEventsPerTick; i++) {
      final pick = _weightedRandomPick(candidates, usedIds, rng);
      if (pick == null) break;
      selected.add(pick.definition);
      usedIds.add(pick.definition.id);
    }

    // ── Step 6: Guaranteed correction override ───────────────────────────────
    if (_ticksUntilGuaranteedCorrection > 0) {
      _ticksUntilGuaranteedCorrection--;
      final hasCorrection = selected.any((e) =>
          e.balancingTags.contains('correction') ||
          e.balancingTags.contains('anti-whale'));
      if (!hasCorrection) {
        // Force the highest-weight correction event that isn't already selected.
        final correctionCandidates = scored
            .where((s) =>
                !usedIds.contains(s.definition.id) &&
                (s.definition.balancingTags.contains('correction') ||
                    s.definition.balancingTags.contains('anti-whale')))
            .toList();
        if (correctionCandidates.isNotEmpty) {
          // Already sorted by score descending.
          if (selected.length < kMaxEventsPerTick) {
            selected.add(correctionCandidates.first.definition);
          } else {
            // Replace the last selected event with the correction.
            selected[selected.length - 1] =
                correctionCandidates.first.definition;
          }
        }
      }
    }

    // ── Step 7: Update state ─────────────────────────────────────────────────
    _recordFired(selected);

    // Determine dominant direction of this tick for streak tracking.
    if (selected.isNotEmpty) {
      final dominantDir = _dominantDirection(selected);
      _recentDirections.add(dominantDir);
      if (_recentDirections.length > kBullishStreakThreshold + 2) {
        _recentDirections.removeAt(0);
      }

      // Record average magnitude for volatility tracking.
      final avgMag =
          selected.map((e) => e.magnitude).reduce((a, b) => a + b) /
              selected.length;
      _recentMagnitudes.add(avgMag);
      if (_recentMagnitudes.length > kVolatilityHistoryLength) {
        _recentMagnitudes.removeAt(0);
      }
    }

    // Update sector hint for next tick (Sector Scout ability).
    _nextSectorHint = selected.isNotEmpty ? selected.first.affectedSector : null;

    // Log selections.
    for (final s in selected) {
      final scoredEntry = scored.firstWhere(
        (e) => e.definition.id == s.id,
        orElse: () => _ScoredEvent(s, 0, s.magnitude),
      );
      _log.add(_SelectionLog(s.id, scoredEntry.score, const <String>[]));
      // Keep log from growing unbounded.
      if (_log.length > 200) _log.removeAt(0);
    }

    return selected;
  }

  // ── Reset ────────────────────────────────────────────────────────────────────

  void reset() {
    _recentDirections.clear();
    _lastFiredTimes.clear();
    _recentMagnitudes.clear();
    _playerPeakPortfolioValue = 0.0;
    _ticksUntilGuaranteedCorrection = 0;
    _nextSectorHint = null;
    _log.clear();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Future<void> saveState(PersistenceService persistence) async {
    final state = <String, dynamic>{
      'lastFiredTimes': _lastFiredTimes
          .map((id, dt) => MapEntry(id, dt.toIso8601String())),
      'recentDirections':
          _recentDirections.map((d) => d.name).toList(),
      'recentMagnitudes': _recentMagnitudes,
      'peakPortfolio': _playerPeakPortfolioValue,
      'guaranteedCorrectionCountdown': _ticksUntilGuaranteedCorrection,
    };
    await persistence.saveEventEngineState(state);
  }

  Future<void> loadState(PersistenceService persistence) async {
    final state = await persistence.loadEventEngineState();
    if (state == null) return;

    final firedMap = state['lastFiredTimes'] as Map<String, dynamic>? ?? {};
    _lastFiredTimes.clear();
    for (final entry in firedMap.entries) {
      _lastFiredTimes[entry.key] = DateTime.parse(entry.value as String);
    }

    _recentDirections.clear();
    final dirList = state['recentDirections'] as List<dynamic>? ?? [];
    for (final name in dirList) {
      try {
        _recentDirections
            .add(EventDirection.values.byName(name as String));
      } catch (_) {
        // Unknown direction name — skip.
      }
    }

    _recentMagnitudes.clear();
    final magList = state['recentMagnitudes'] as List<dynamic>? ?? [];
    for (final m in magList) {
      _recentMagnitudes.add((m as num).toDouble());
    }

    _playerPeakPortfolioValue =
        ((state['peakPortfolio'] as num?) ?? 0).toDouble();
    _ticksUntilGuaranteedCorrection =
        (state['guaranteedCorrectionCountdown'] as int?) ?? 0;
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Total portfolio value: cash + all current holding market values.
  double _computePortfolioValue(
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
    double cashBalance,
  ) {
    double value = cashBalance;
    for (final h in holdings) {
      try {
        final stock = stocks.firstWhere((s) => s.ticker == h.ticker);
        value += h.shares * stock.currentPrice;
      } catch (_) {
        // Stock not found; skip.
      }
    }
    return value;
  }

  /// Ratio of the largest single-position value to the median position value.
  /// Returns 1.0 when there are fewer than 2 holdings (no meaningful ratio).
  double _computeWealthGapRatio(
    List<PortfolioHolding> holdings,
    List<Stock> stocks,
  ) {
    if (holdings.length < 2) return 1.0;

    final values = <double>[];
    for (final h in holdings) {
      try {
        final stock = stocks.firstWhere((s) => s.ticker == h.ticker);
        values.add(h.shares * stock.currentPrice);
      } catch (_) {
        // Skip unknown tickers.
      }
    }
    if (values.length < 2) return 1.0;

    values.sort();
    final largest = values.last;
    final median = values[values.length ~/ 2];
    if (median <= 0) return 1.0;
    return largest / median;
  }

  /// Counts how many of the most recent ticks had the given [direction].
  /// Stops counting at the first tick with a different direction.
  int _countTrailingStreak(EventDirection direction) {
    int count = 0;
    for (int i = _recentDirections.length - 1; i >= 0; i--) {
      if (_recentDirections[i] == direction) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  /// True if the event's cooldown period has expired (or it has never fired).
  bool _isCooledDown(MarketEventDefinition event) {
    final last = _lastFiredTimes[event.id];
    if (last == null) return true;
    return DateTime.now().difference(last).inHours >= event.cooldownHours;
  }

  /// Rolling average of recent magnitudes, normalised to 0.0–1.0.
  double _computeVolatilityScore() {
    if (_recentMagnitudes.isEmpty) return 0.0;
    return _recentMagnitudes.reduce((a, b) => a + b) /
        _recentMagnitudes.length;
  }

  /// Picks one event from [candidates] by weighted random, skipping already
  /// selected [usedIds]. Returns null if no eligible candidate remains.
  _ScoredEvent? _weightedRandomPick(
    List<_ScoredEvent> candidates,
    Set<String> usedIds,
    Random rng,
  ) {
    final eligible =
        candidates.where((c) => !usedIds.contains(c.definition.id)).toList();
    if (eligible.isEmpty) return null;

    final totalWeight = eligible.fold(0.0, (sum, e) => sum + e.score);
    if (totalWeight <= 0) return eligible[rng.nextInt(eligible.length)];

    double roll = rng.nextDouble() * totalWeight;
    for (final candidate in eligible) {
      roll -= candidate.score;
      if (roll <= 0) return candidate;
    }
    return eligible.last;
  }

  /// Returns the direction that represents the majority of [events].
  /// Falls back to volatile if mixed.
  EventDirection _dominantDirection(List<MarketEventDefinition> events) {
    if (events.isEmpty) return EventDirection.neutral;
    final bullish = events.where((e) => e.direction == EventDirection.bullish).length;
    final bearish = events.where((e) => e.direction == EventDirection.bearish).length;
    if (bullish > bearish) return EventDirection.bullish;
    if (bearish > bullish) return EventDirection.bearish;
    return EventDirection.volatile;
  }

  /// Records that [events] have fired by stamping their last-fired time.
  void _recordFired(List<MarketEventDefinition> events) {
    final now = DateTime.now();
    for (final e in events) {
      _lastFiredTimes[e.id] = now;
    }
  }
}
