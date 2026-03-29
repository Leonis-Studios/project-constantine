// ─────────────────────────────────────────────────────────────────────────────
// simulation_engine.dart
//
// PURPOSE: Pure stateless service that advances the market simulation by one
//          day. Given the current stock list and event pool, it applies random
//          price movements and fires news events, then returns the results.
//
// WHY PURE / STATELESS:
//   The engine holds no state of its own. All inputs come in as parameters and
//   all outputs come out as a SimulationResult. This makes it:
//     • Easy to unit-test: just call advanceOneDay() with fixed inputs and check
//       the outputs (use Random(42) for a deterministic seed in tests).
//     • Easy to reason about: the same inputs always produce the same shape of
//       output (though amounts are random, bounds are deterministic).
//
// ALGORITHM OVERVIEW (each call to advanceOneDay):
//   1. Apply baseline noise  → every stock drifts ±0.5% to ±1.5%
//   2. Decide events         → pick 1–3 events; global events are 5% likely
//   3. Apply event impacts   → sector or specific stock prices are adjusted
//   4. Clamp prices          → nothing falls below $0.50
//   5. Update price history  → append new price, cap list at 30 entries
//   6. Return result         → new stock list + generated events
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import '../models/stock.dart';
import '../models/market_event.dart';
import '../models/event_definition.dart';

// ── SimulationResult ──────────────────────────────────────────────────────────
//
// The return value of advanceOneDay. Both fields are new lists — the originals
// passed in are never mutated.

class SimulationResult {
  /// Updated copies of every stock with new prices and extended history.
  final List<Stock> updatedStocks;

  /// The events that fired this day (0 to 3, rarely more).
  final List<MarketEvent> events;

  const SimulationResult({
    required this.updatedStocks,
    required this.events,
  });
}

// ── SimulationEngine ──────────────────────────────────────────────────────────

class SimulationEngine {
  // The engine is stateless — no fields other than constants.

  // Price history length cap. Older entries are dropped to keep the list short.
  static const int kMaxHistoryLength = 30;

  // Minimum allowable price. Prevents stocks from reaching $0 or going negative.
  static const double kMinPrice = 0.50;

  // Probability (0.0–1.0) that a global event fires on any given day.
  // At 0.05, players see roughly one global event every 20 days.
  static const double kGlobalEventProbability = 0.05;

  // How many company/sector events can fire in one day (uniform range).
  static const int kMinEventsPerDay = 1;
  static const int kMaxEventsPerDay = 3;

  // Baseline noise range as a percentage of current price (±).
  // Every stock gets a small random walk regardless of events.
  static const double kBaseNoiseMin = 0.005; // 0.5%
  static const double kBaseNoiseMax = 0.015; // 1.5%

  /// The main entry point. Call this once per "Next Day" press.
  ///
  /// Parameters:
  ///   [currentStocks]  — the market's current state (not mutated)
  ///   [eventPool]      — all available EventDefinitions to choose from
  ///   [dayNumber]      — the simulation day being generated (for event records)
  ///   [rng]            — the random number generator; pass Random(seed) in
  ///                      tests for deterministic output
  SimulationResult advanceOneDay({
    required List<Stock> currentStocks,
    required List<EventDefinition> eventPool,
    required int dayNumber,
    required Random rng,
  }) {
    // ── Step 1: Apply baseline noise to every stock ────────────────────────
    //
    // Even on quiet days with no events, prices move slightly. This simulates
    // natural market micromovement (order flow, small trades, sentiment shifts).
    // We build a mutable working map from ticker → price so event application
    // in Step 3 is O(1) lookups.

    // Start with all current prices.
    final Map<String, double> workingPrices = {
      for (final s in currentStocks) s.ticker: s.currentPrice,
    };

    // Apply noise to each stock independently.
    for (final stock in currentStocks) {
      const noiseRange = kBaseNoiseMax - kBaseNoiseMin;
      // Noise magnitude: random value in [kBaseNoiseMin, kBaseNoiseMax]
      final noiseMagnitude = kBaseNoiseMin + rng.nextDouble() * noiseRange;
      // Coin flip: noise goes up (+1) or down (-1)
      final noiseDirection = rng.nextBool() ? 1.0 : -1.0;
      final noiseMultiplier = 1.0 + (noiseMagnitude * noiseDirection);
      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * noiseMultiplier);
    }

    // ── Step 2: Select events for this day ────────────────────────────────
    //
    // We either fire a single global event OR a set of normal events (not both).
    // This keeps the day's narrative readable — one big story OR a few smaller
    // ones, never both a crash and a product launch on the same day.

    final List<MarketEvent> generatedEvents = [];

    // Roll for a global event first.
    final bool globalEventFires = rng.nextDouble() < kGlobalEventProbability;

    if (globalEventFires) {
      // Pick one global event definition at random.
      final globalDefs =
          eventPool.where((e) => e.isGlobalEvent).toList();

      if (globalDefs.isNotEmpty) {
        final def = globalDefs[rng.nextInt(globalDefs.length)];
        final event = _applyGlobalEvent(
          def: def,
          workingPrices: workingPrices,
          allStocks: currentStocks,
          dayNumber: dayNumber,
          rng: rng,
        );
        generatedEvents.add(event);
      }
    } else {
      // Normal day: pick 1–3 non-global events.
      final int eventCount = kMinEventsPerDay +
          rng.nextInt(kMaxEventsPerDay - kMinEventsPerDay + 1);

      // Shuffle a copy of non-global event definitions so we pick without
      // replacement (avoids the same event firing twice in one day).
      final normalDefs =
          eventPool.where((e) => !e.isGlobalEvent).toList()..shuffle(rng);

      // Keep track of tickers already targeted this day to avoid double-hitting
      // the same stock with two separate events.
      final Set<String> usedTickers = {};

      for (int i = 0; i < eventCount && i < normalDefs.length; i++) {
        final def = normalDefs[i];

        if (def.targetSector != null) {
          // ── Sector-wide event ────────────────────────────────────────────
          // Apply the same impact to all stocks in the target sector.
          final event = _applySectorEvent(
            def: def,
            workingPrices: workingPrices,
            allStocks: currentStocks,
            dayNumber: dayNumber,
            rng: rng,
          );
          generatedEvents.add(event);
        } else {
          // ── Company-specific event ───────────────────────────────────────
          // Pick a random stock that hasn't been hit today.
          final candidates = currentStocks
              .where((s) => !usedTickers.contains(s.ticker))
              .toList();

          if (candidates.isNotEmpty) {
            final targetStock =
                candidates[rng.nextInt(candidates.length)];
            usedTickers.add(targetStock.ticker);

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
      }
    }

    // ── Step 3: Clamp prices and update history ────────────────────────────
    //
    // Build the final updated Stock list. For each stock:
    //   • Clamp price to kMinPrice
    //   • Set previousPrice = old currentPrice (today becomes yesterday)
    //   • Append new price to history, drop oldest if over the cap

    final List<Stock> updatedStocks = currentStocks.map((stock) {
      final rawNewPrice = workingPrices[stock.ticker]!;
      // Ensure the price never drops below the minimum.
      final newPrice = rawNewPrice.clamp(kMinPrice, double.infinity);

      // Append today's price to history, keeping only the last kMaxHistoryLength.
      final newHistory = [
        ...stock.priceHistory,
        newPrice,
      ];
      // If history exceeds cap, drop the oldest entry from the front.
      final trimmedHistory = newHistory.length > kMaxHistoryLength
          ? newHistory.sublist(newHistory.length - kMaxHistoryLength)
          : newHistory;

      return stock.copyWith(
        currentPrice: newPrice,
        previousPrice: stock.currentPrice, // yesterday = today's old price
        priceHistory: trimmedHistory,
      );
    }).toList();

    return SimulationResult(
      updatedStocks: updatedStocks,
      events: generatedEvents,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Applies a global event to ALL stocks in workingPrices.
  /// For the global_volatility event the sign is randomised per stock,
  /// giving a mixed market. For other global events, all stocks move the
  /// same direction.
  MarketEvent _applyGlobalEvent({
    required EventDefinition def,
    required Map<String, double> workingPrices,
    required List<Stock> allStocks,
    required int dayNumber,
    required Random rng,
  }) {
    // Roll the impact magnitude (always within the definition's range).
    final double impactPercent = _rollImpact(def, rng);

    for (final stock in allStocks) {
      double actualImpact = impactPercent;

      // Special case: the volatility event randomises sign per stock.
      // This gives a realistic "mixed bag" day where some stocks rise and
      // others fall on the same news.
      if (def.id == 'global_volatility') {
        final magnitude = impactPercent.abs();
        actualImpact = rng.nextBool() ? magnitude : -magnitude;
      }

      final multiplier = 1.0 + (actualImpact / 100.0);
      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * multiplier);
    }

    return MarketEvent(
      dayNumber: dayNumber,
      headline: def.headlineTemplate.replaceAll('{company}', 'the market'),
      description: def.descriptionTemplate.replaceAll('{company}', 'the market'),
      affectedTicker: null, // global — no single ticker
      affectedSector: null,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: true,
      timestamp: DateTime.now(),
    );
  }

  /// Applies a sector-wide event — same impact to every stock in the sector.
  MarketEvent _applySectorEvent({
    required EventDefinition def,
    required Map<String, double> workingPrices,
    required List<Stock> allStocks,
    required int dayNumber,
    required Random rng,
  }) {
    final double impactPercent = _rollImpact(def, rng);
    final String sector = def.targetSector!;
    final multiplier = 1.0 + (impactPercent / 100.0);

    // Apply to all stocks whose sector matches.
    for (final stock in allStocks.where((s) => s.sector == sector)) {
      workingPrices[stock.ticker] =
          (workingPrices[stock.ticker]! * multiplier);
    }

    return MarketEvent(
      dayNumber: dayNumber,
      headline: def.headlineTemplate.replaceAll('{company}', sector),
      description: def.descriptionTemplate.replaceAll('{company}', sector),
      affectedTicker: null, // sector event — no single ticker
      affectedSector: sector,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: false,
      timestamp: DateTime.now(),
    );
  }

  /// Applies a company-specific event — impacts only one stock.
  MarketEvent _applyCompanyEvent({
    required EventDefinition def,
    required Stock targetStock,
    required Map<String, double> workingPrices,
    required int dayNumber,
    required Random rng,
  }) {
    final double impactPercent = _rollImpact(def, rng);
    final multiplier = 1.0 + (impactPercent / 100.0);

    workingPrices[targetStock.ticker] =
        (workingPrices[targetStock.ticker]! * multiplier);

    // Substitute the real company name into the headline/description templates.
    final headline = def.headlineTemplate
        .replaceAll('{company}', targetStock.companyName);
    final description = def.descriptionTemplate
        .replaceAll('{company}', targetStock.companyName);

    return MarketEvent(
      dayNumber: dayNumber,
      headline: headline,
      description: description,
      affectedTicker: targetStock.ticker,
      affectedSector: null,
      impactPercent: impactPercent,
      isPositive: def.isPositive,
      isGlobal: false,
      timestamp: DateTime.now(),
    );
  }

  /// Rolls a random impact percentage within the definition's [min, max] range.
  /// For definitions where both min and max are negative, the result is negative.
  double _rollImpact(EventDefinition def, Random rng) {
    final range = def.maxImpactPercent - def.minImpactPercent;
    // nextDouble() returns [0.0, 1.0), so result is in [min, max).
    return def.minImpactPercent + rng.nextDouble() * range;
  }
}
