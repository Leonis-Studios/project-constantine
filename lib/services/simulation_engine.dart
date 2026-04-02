// ─────────────────────────────────────────────────────────────────────────────
// simulation_engine.dart
//
// PURPOSE: Pure stateless service that advances the market simulation by one
//          day. Given the current stock list and pre-selected events (provided
//          by EventEngine), it applies price movements and returns results.
//
// WHY PURE / STATELESS:
//   The engine holds no state of its own. All inputs come in as parameters and
//   all outputs come out as a SimulationResult. This makes it:
//     • Easy to unit-test: just call advanceOneDay() with fixed inputs and check
//       the outputs (use Random(seed) for a deterministic seed in tests).
//     • Easy to reason about: the same inputs always produce the same shape of
//       output (though amounts are random, bounds are deterministic).
//
// ALGORITHM OVERVIEW (each call to advanceOneDay):
//   0. Process trend state  → tick down active trends; randomly start new ones
//   1. Apply baseline noise → every stock drifts; trending stocks always move
//                             in their trend direction with an extra bias
//   2. Apply pre-selected events → EventEngine already chose which events fire;
//                                  this engine applies their price impacts
//   3. Clamp prices         → nothing falls below $0.50
//   4. Update price history → append new price, cap list at 30 entries
//   5. Return result        → new stock list + generated MarketEvent instances
//
// EVENT SELECTION:
//   Event selection was previously done inline here. It has been moved to
//   EventEngine (lib/systems/events/event_engine.dart) which uses a weighted
//   balancing algorithm. MarketProvider calls EventEngine.selectEvents() first,
//   then passes the result here as [selectedEvents].
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../models/stock.dart';
import '../models/market_event.dart';
import '../systems/events/market_event.dart' as sys;

// ── SimulationResult ──────────────────────────────────────────────────────────
//
// The return value of advanceOneDay. Both fields are new lists — the originals
// passed in are never mutated.

class SimulationResult {
  /// Updated copies of every stock with new prices and extended history.
  final List<Stock> updatedStocks;

  /// The MarketEvent instances that fired this day (used by the UI).
  final List<MarketEvent> events;

  const SimulationResult({
    required this.updatedStocks,
    required this.events,
  });
}

// ── _TrendUpdate ──────────────────────────────────────────────────────────────

class _TrendUpdate {
  final String direction;
  final int daysRemaining;
  const _TrendUpdate(this.direction, this.daysRemaining);
}

// ── SimulationEngine ──────────────────────────────────────────────────────────

class SimulationEngine {
  // The engine is stateless — no fields other than constants.

  // Price history length cap. Older entries are dropped to keep the list short.
  static const int kMaxHistoryLength = 30;

  // Minimum allowable price. Prevents stocks from reaching $0 or going negative.
  static const double kMinPrice = 0.50;

  // Baseline noise range as a percentage of current price (±).
  // Every stock gets a small random walk regardless of events.
  static const double kBaseNoiseMin = 0.005; // 0.5%
  static const double kBaseNoiseMax = 0.015; // 1.5%

  // Trend system constants.
  // Probability a stock with no active trend starts one on any given day.
  static const double kTrendStartProbability = 0.15;
  // Trend duration range in days (inclusive).
  static const int kTrendMinDays = 3;
  static const int kTrendMaxDays = 10;
  // Extra daily directional bias added on top of baseline noise while trending.
  static const double kTrendBiasMin = 0.005; // 0.5%
  static const double kTrendBiasMax = 0.020; // 2.0%

  /// The main entry point. Call this once per "Next Day" press.
  ///
  /// Parameters:
  ///   [currentStocks]   — the market's current state (not mutated)
  ///   [selectedEvents]  — events pre-selected by EventEngine for this tick
  ///   [dayNumber]       — the simulation day being generated (for event records)
  ///   [rng]             — the random number generator
  SimulationResult advanceOneDay({
    required List<Stock> currentStocks,
    required List<sys.MarketEventDefinition> selectedEvents,
    required int dayNumber,
    required Random rng,
  }) {
    // ── Step 0: Process trend state ───────────────────────────────────────

    final Map<String, _TrendUpdate> updatedTrends = {};

    for (final stock in currentStocks) {
      if (stock.trendDirection != 'neutral') {
        final newDays = stock.trendDaysRemaining - 1;
        if (newDays <= 0) {
          updatedTrends[stock.ticker] = const _TrendUpdate('neutral', 0);
        } else {
          updatedTrends[stock.ticker] =
              _TrendUpdate(stock.trendDirection, newDays);
        }
      } else {
        if (rng.nextDouble() < kTrendStartProbability) {
          final direction = rng.nextBool() ? 'up' : 'down';
          final duration =
              kTrendMinDays + rng.nextInt(kTrendMaxDays - kTrendMinDays + 1);
          updatedTrends[stock.ticker] = _TrendUpdate(direction, duration);
        } else {
          updatedTrends[stock.ticker] = const _TrendUpdate('neutral', 0);
        }
      }
    }

    // ── Step 1: Apply baseline noise to every stock ────────────────────────

    final Map<String, double> workingPrices = {
      for (final s in currentStocks) s.ticker: s.currentPrice,
    };

    for (final stock in currentStocks) {
      const noiseRange = kBaseNoiseMax - kBaseNoiseMin;
      final noiseMagnitude = kBaseNoiseMin + rng.nextDouble() * noiseRange;
      final trend = updatedTrends[stock.ticker]!;

      final double noiseMultiplier;
      if (trend.direction == 'up') {
        final bias =
            kTrendBiasMin + rng.nextDouble() * (kTrendBiasMax - kTrendBiasMin);
        noiseMultiplier = 1.0 + noiseMagnitude + bias;
      } else if (trend.direction == 'down') {
        final bias =
            kTrendBiasMin + rng.nextDouble() * (kTrendBiasMax - kTrendBiasMin);
        noiseMultiplier = 1.0 - noiseMagnitude - bias;
      } else {
        final noiseDirection = rng.nextBool() ? 1.0 : -1.0;
        noiseMultiplier = 1.0 + (noiseMagnitude * noiseDirection);
      }

      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * noiseMultiplier);
    }

    // ── Step 2: Apply pre-selected events ─────────────────────────────────
    //
    // EventEngine has already decided which events fire. We apply their
    // price impacts here using the same mechanics as before.

    final List<MarketEvent> generatedEvents = [];

    for (final def in selectedEvents) {
      if (def.isGlobal) {
        final event = _applyGlobalEvent(
          def: def,
          workingPrices: workingPrices,
          allStocks: currentStocks,
          dayNumber: dayNumber,
          rng: rng,
        );
        generatedEvents.add(event);
      } else if (!def.isCompanyEvent) {
        // Sector event.
        final event = _applySectorEvent(
          def: def,
          workingPrices: workingPrices,
          allStocks: currentStocks,
          dayNumber: dayNumber,
          rng: rng,
        );
        generatedEvents.add(event);
      } else {
        // Company event — pick a random stock not yet used this tick.
        final usedTickers =
            generatedEvents.map((e) => e.affectedTicker).toSet();
        final candidates = currentStocks
            .where((s) => !usedTickers.contains(s.ticker))
            .toList();
        if (candidates.isEmpty) continue;
        final targetStock = candidates[rng.nextInt(candidates.length)];
        final event = _applyCompanyEvent(
          def: def,
          targetStock: targetStock,
          workingPrices: workingPrices,
          dayNumber: dayNumber,
          rng: rng,
        );
        generatedEvents.add(event);
      }
    }

    // ── Step 3: Clamp prices and update history ────────────────────────────

    final List<Stock> updatedStocks = currentStocks.map((stock) {
      final rawNewPrice = workingPrices[stock.ticker]!;
      final newPrice = rawNewPrice.clamp(kMinPrice, double.infinity);

      final newHistory = [
        ...stock.priceHistory,
        newPrice,
      ];
      final trimmedHistory = newHistory.length > kMaxHistoryLength
          ? newHistory.sublist(newHistory.length - kMaxHistoryLength)
          : newHistory;

      final trend = updatedTrends[stock.ticker]!;

      return stock.copyWith(
        currentPrice: newPrice,
        previousPrice: stock.currentPrice,
        priceHistory: trimmedHistory,
        trendDirection: trend.direction,
        trendDaysRemaining: trend.daysRemaining,
      );
    }).toList();

    return SimulationResult(
      updatedStocks: updatedStocks,
      events: generatedEvents,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Applies a global event to ALL stocks.
  /// For volatile events the sign is randomised per stock.
  MarketEvent _applyGlobalEvent({
    required sys.MarketEventDefinition def,
    required Map<String, double> workingPrices,
    required List<Stock> allStocks,
    required int dayNumber,
    required Random rng,
  }) {
    final double impactPercent = _rollImpact(def, rng);

    for (final stock in allStocks) {
      double actualImpact = impactPercent;
      if (def.direction == sys.EventDirection.volatile) {
        final magnitude = impactPercent.abs();
        actualImpact = rng.nextBool() ? magnitude : -magnitude;
      }
      final multiplier = 1.0 + (actualImpact / 100.0);
      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * multiplier);
    }

    return MarketEvent(
      dayNumber: dayNumber,
      headline: def.name.replaceAll('{company}', 'the market'),
      description: def.description.replaceAll('{company}', 'the market'),
      affectedTicker: null,
      affectedSector: null,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: true,
      timestamp: DateTime.now(),
    );
  }

  /// Applies a sector-wide event — same impact to every stock in the sector.
  MarketEvent _applySectorEvent({
    required sys.MarketEventDefinition def,
    required Map<String, double> workingPrices,
    required List<Stock> allStocks,
    required int dayNumber,
    required Random rng,
  }) {
    final double impactPercent = _rollImpact(def, rng);
    final String sector = def.affectedSector;
    final multiplier = 1.0 + (impactPercent / 100.0);

    for (final stock in allStocks.where((s) => s.sector == sector)) {
      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * multiplier);
    }

    return MarketEvent(
      dayNumber: dayNumber,
      headline: def.name.replaceAll('{company}', sector),
      description: def.description.replaceAll('{company}', sector),
      affectedTicker: null,
      affectedSector: sector,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: false,
      timestamp: DateTime.now(),
    );
  }

  /// Applies a company-specific event to one stock.
  MarketEvent _applyCompanyEvent({
    required sys.MarketEventDefinition def,
    required Stock targetStock,
    required Map<String, double> workingPrices,
    required int dayNumber,
    required Random rng,
  }) {
    final double impactPercent = _rollImpact(def, rng);
    final multiplier = 1.0 + (impactPercent / 100.0);
    workingPrices[targetStock.ticker] =
        (workingPrices[targetStock.ticker]! * multiplier);

    return MarketEvent(
      dayNumber: dayNumber,
      headline: def.name.replaceAll('{company}', targetStock.companyName),
      description:
          def.description.replaceAll('{company}', targetStock.companyName),
      affectedTicker: targetStock.ticker,
      affectedSector: null,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: false,
      timestamp: DateTime.now(),
    );
  }

  /// Rolls a random impact percentage within [def]'s min/max range.
  double _rollImpact(sys.MarketEventDefinition def, Random rng) {
    final range = def.maxImpactPercent - def.minImpactPercent;
    return def.minImpactPercent + rng.nextDouble() * range;
  }
}
