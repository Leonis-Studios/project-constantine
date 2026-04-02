// ─────────────────────────────────────────────────────────────────────────────
// market_event.dart  (lib/systems/events/)
//
// PURPOSE: The new event definition model used by EventEngine and the migrated
//          EventRegistry. This is the template / blueprint for an event — it is
//          never the fired concrete result (that remains lib/models/market_event.dart).
//
// EXTENSIBILITY:
//   Adding a new event type requires only adding an entry to event_registry.dart.
//   No changes to this file are needed unless the model shape itself changes.
//
// NOTE ON const:
//   All fields are primitives or List<String> literals, so MarketEventDefinition
//   instances can be declared `const` in event_registry.dart.
// ─────────────────────────────────────────────────────────────────────────────

/// The broad market direction this event pushes prices toward.
enum EventDirection {
  /// Positive — prices tend to rise.
  bullish,

  /// Negative — prices tend to fall.
  bearish,

  /// Mixed — prices can move either way unpredictably.
  volatile,

  /// Flat — minimal directional impact.
  neutral,
}

/// A template that EventEngine uses when selecting and scoring events each tick.
///
/// Mirrors the role of the old [EventDefinition] in lib/models/event_definition.dart,
/// but adds the fields required by the weighted balancing engine:
///   • [magnitude] — used for volatility tracking and dampening
///   • [baseProbability] — baseline selection weight before scoring adjustments
///   • [cooldownHours] — real-time hours that must pass before re-firing
///   • [balancingTags] — semantic labels EventEngine uses to decide boost/suppress
///
/// [affectedSector] encoding:
///   'ALL'     → global event (all stocks affected)
///   'COMPANY' → company-specific event (SimulationEngine picks a random stock)
///   <name>    → sector-wide event (e.g. 'Technology', 'Energy')
class MarketEventDefinition {
  /// Unique identifier — must match across registry and persistence.
  final String id;

  /// Headline template. May contain the `{company}` placeholder which
  /// SimulationEngine replaces with the target company name or sector.
  final String name;

  /// Longer description template. Same `{company}` placeholder rules apply.
  final String description;

  /// Which stocks are affected. See class doc for encoding.
  final String affectedSector;

  /// Broad direction this event pushes the market.
  final EventDirection direction;

  /// Strength of price movement, normalised to 0.0–1.0.
  /// Used by EventEngine to track rolling volatility and apply dampening.
  /// Does not override [minImpactPercent]/[maxImpactPercent] for price maths.
  final double magnitude;

  /// Minimum price impact percentage (negative for bearish events).
  /// SimulationEngine picks a random value in [minImpactPercent, maxImpactPercent].
  final double minImpactPercent;

  /// Maximum price impact percentage.
  final double maxImpactPercent;

  /// Baseline selection weight before any balancing adjustments.
  /// Expressed as a probability (0.0–1.0). EventEngine multiplies by 100 to
  /// produce a raw score, then applies boost/suppress multipliers.
  final double baseProbability;

  /// Minimum real-time hours that must elapse before this event can fire again.
  /// Cooldowns are wall-clock based, not tick-count based, so the same event
  /// cannot spam repeatedly during fast auto-advance play.
  final int cooldownHours;

  /// Semantic tags used by EventEngine's scoring formula.
  ///
  /// Recognised tags:
  ///   'anti-whale'     — boosted when one position dominates the portfolio
  ///   'correction'     — boosted during bullish streaks or severe wealth gaps
  ///   'catch-up'       — boosted when portfolio is far below personal peak
  ///   'crash-recovery' — boosted after bearish streaks to aid recovery
  final List<String> balancingTags;

  /// Convenience getter — true when the event generally benefits the market.
  bool get isPositive => maxImpactPercent > 0;

  /// True when this event affects all stocks simultaneously.
  bool get isGlobal => affectedSector == 'ALL';

  /// True when this event targets a single randomly chosen company.
  bool get isCompanyEvent => affectedSector == 'COMPANY';

  const MarketEventDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.affectedSector,
    required this.direction,
    required this.magnitude,
    required this.minImpactPercent,
    required this.maxImpactPercent,
    required this.baseProbability,
    required this.cooldownHours,
    required this.balancingTags,
  });
}
