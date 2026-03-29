// ─────────────────────────────────────────────────────────────────────────────
// event_definition.dart
//
// PURPOSE: A template that the SimulationEngine uses to generate MarketEvents.
//          These are compile-time constants defined in event_definitions.dart —
//          they are never stored to disk or modified at runtime.
//
// HOW TEMPLATES WORK:
//   headlineTemplate and descriptionTemplate may contain the placeholder
//   "{company}" which the SimulationEngine replaces with the target company name
//   when generating the concrete MarketEvent. For sector/global events,
//   the placeholder is replaced with the sector name or "the market".
//
//   Example:
//     headlineTemplate: "{company} reports record quarterly earnings"
//     → generated headline: "Nexacor Industries reports record quarterly earnings"
// ─────────────────────────────────────────────────────────────────────────────

class EventDefinition {
  /// Unique identifier — used for debugging and to avoid selecting the same
  /// event twice in one day.
  final String id;

  /// Headline template with optional {company} placeholder.
  final String headlineTemplate;

  /// Longer description template with optional {company} placeholder.
  final String descriptionTemplate;

  /// Minimum price impact as a percentage.
  /// For positive events this will be > 0; for negative events < 0.
  final double minImpactPercent;

  /// Maximum price impact as a percentage.
  /// The SimulationEngine picks a random value in [minImpact, maxImpact].
  final double maxImpactPercent;

  /// If non-null, this event only targets stocks in this specific sector.
  /// If null, the event can target any single stock (company-level event)
  /// or all stocks (if isGlobalEvent is true).
  final String? targetSector;

  /// If true, this event affects ALL stocks simultaneously.
  /// These are rare (market crash, Federal Reserve announcement, etc.).
  /// isGlobalEvent and targetSector should not both be set.
  final bool isGlobalEvent;

  /// Convenience getter — true if the impact is generally positive.
  /// Used by the SimulationEngine to correctly set MarketEvent.isPositive.
  bool get isPositive => maxImpactPercent > 0;

  const EventDefinition({
    required this.id,
    required this.headlineTemplate,
    required this.descriptionTemplate,
    required this.minImpactPercent,
    required this.maxImpactPercent,
    this.targetSector,
    this.isGlobalEvent = false,
  });
}
