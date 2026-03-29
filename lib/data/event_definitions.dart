// ─────────────────────────────────────────────────────────────────────────────
// event_definitions.dart
//
// PURPOSE: The pool of ~30 event templates that the SimulationEngine draws from
//          each day to generate concrete MarketEvents.
//
// STRUCTURE OF THE POOL:
//   1. Positive company-specific events — good news for a single stock
//   2. Negative company-specific events — bad news for a single stock
//   3. Sector-wide positive events     — whole sector gets a boost
//   4. Sector-wide negative events     — whole sector takes a hit
//   5. Global market events            — all 20 stocks are affected (rare)
//
// TO ADD MORE EVENTS:
//   Just append a new EventDefinition to kAllEventDefinitions. Make sure:
//   • id is unique
//   • {company} placeholder is used where the company name should appear
//   • minImpact ≤ maxImpact
//   • For global events, set isGlobalEvent: true and leave targetSector null
//   • For sector events, set targetSector to one of the valid sector strings
// ─────────────────────────────────────────────────────────────────────────────

import '../models/event_definition.dart';

const List<EventDefinition> kAllEventDefinitions = [

  // ── Positive company-specific events ───────────────────────────────────────
  //    These are randomly assigned to any stock regardless of sector.
  //    The SimulationEngine replaces {company} with the stock's companyName.

  EventDefinition(
    id: 'pos_earnings_beat',
    headlineTemplate: '{company} smashes analyst earnings estimates',
    descriptionTemplate:
        '{company} reported quarterly revenue 18% above consensus forecasts, '
        'citing strong demand and disciplined cost management. The CFO raised '
        'full-year guidance.',
    minImpactPercent: 5.0,
    maxImpactPercent: 14.0,
  ),
  EventDefinition(
    id: 'pos_partnership',
    headlineTemplate: '{company} announces landmark government partnership',
    descriptionTemplate:
        '{company} signed a multi-year contract worth an estimated \$2.1B '
        'with a federal agency, securing a major revenue stream through 2029.',
    minImpactPercent: 6.0,
    maxImpactPercent: 16.0,
  ),
  EventDefinition(
    id: 'pos_product_launch',
    headlineTemplate: '{company} launches flagship product to rave reviews',
    descriptionTemplate:
        'Early adoption of {company}\'s latest product exceeded internal '
        'projections by 40%, with pre-orders sold out within 48 hours of '
        'the announcement.',
    minImpactPercent: 4.0,
    maxImpactPercent: 12.0,
  ),
  EventDefinition(
    id: 'pos_regulatory_approval',
    headlineTemplate: '{company} wins key regulatory approval',
    descriptionTemplate:
        'Regulators granted {company} a long-awaited approval, clearing the '
        'path for the company to enter three new markets previously blocked '
        'by compliance requirements.',
    minImpactPercent: 7.0,
    maxImpactPercent: 18.0,
  ),
  EventDefinition(
    id: 'pos_buyback',
    headlineTemplate: '{company} authorises \$500M share buyback program',
    descriptionTemplate:
        'The board of directors at {company} approved a \$500 million share '
        'repurchase program, signalling management\'s confidence in the '
        'company\'s long-term value.',
    minImpactPercent: 3.0,
    maxImpactPercent: 8.0,
  ),
  EventDefinition(
    id: 'pos_analyst_upgrade',
    headlineTemplate: 'Major bank upgrades {company} to Strong Buy',
    descriptionTemplate:
        'Analysts at Veltman & Co. upgraded {company} from Hold to Strong Buy, '
        'raising their price target by 35% citing undervalued assets and '
        'improving margin outlook.',
    minImpactPercent: 4.0,
    maxImpactPercent: 10.0,
  ),
  EventDefinition(
    id: 'pos_acquisition',
    headlineTemplate: '{company} acquires hot startup for strategic expansion',
    descriptionTemplate:
        '{company} announced the acquisition of a fast-growing private startup '
        'for \$340M in cash. Analysts praised the deal as complementary to '
        '{company}\'s core business roadmap.',
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
  ),

  // ── Negative company-specific events ───────────────────────────────────────

  EventDefinition(
    id: 'neg_earnings_miss',
    headlineTemplate: '{company} misses earnings — revenue down 14%',
    descriptionTemplate:
        '{company} reported quarterly earnings well below expectations. '
        'Revenue fell 14% year-over-year as the company struggled with '
        'supply chain disruptions and softening demand.',
    minImpactPercent: -14.0,
    maxImpactPercent: -4.0,
  ),
  EventDefinition(
    id: 'neg_lawsuit',
    headlineTemplate: '{company} faces class-action lawsuit over data breach',
    descriptionTemplate:
        'A class of over 200,000 plaintiffs filed suit against {company}, '
        'alleging negligent handling of customer data following a major '
        'security incident disclosed last quarter.',
    minImpactPercent: -12.0,
    maxImpactPercent: -4.0,
  ),
  EventDefinition(
    id: 'neg_ceo_resign',
    headlineTemplate: '{company} CEO resigns amid internal investigation',
    descriptionTemplate:
        'The CEO of {company} stepped down effective immediately. The board '
        'appointed an interim executive while an independent committee '
        'investigates alleged financial irregularities.',
    minImpactPercent: -18.0,
    maxImpactPercent: -8.0,
  ),
  EventDefinition(
    id: 'neg_recall',
    headlineTemplate: '{company} issues major product recall',
    descriptionTemplate:
        '{company} announced a voluntary recall of its flagship product '
        'affecting an estimated 1.8 million units due to a safety defect. '
        'Remediation costs are expected to exceed \$120M.',
    minImpactPercent: -15.0,
    maxImpactPercent: -6.0,
  ),
  EventDefinition(
    id: 'neg_contract_loss',
    headlineTemplate: '{company} loses key contract to rival',
    descriptionTemplate:
        'A government agency announced it will not renew its contract with '
        '{company}, awarding the deal to a competitor. The lost contract '
        'represented 12% of annual revenue.',
    minImpactPercent: -11.0,
    maxImpactPercent: -5.0,
  ),
  EventDefinition(
    id: 'neg_analyst_downgrade',
    headlineTemplate: '{company} downgraded to Sell on margin concerns',
    descriptionTemplate:
        'Brokerage firm Harwick Capital downgraded {company} to Sell, '
        'warning that rising input costs and competitive pressure will '
        'compress margins over the next two quarters.',
    minImpactPercent: -9.0,
    maxImpactPercent: -3.0,
  ),
  EventDefinition(
    id: 'neg_guidance_cut',
    headlineTemplate: '{company} cuts full-year revenue guidance',
    descriptionTemplate:
        '{company}\'s management issued a profit warning, reducing full-year '
        'revenue guidance by 8%, blaming macroeconomic headwinds and slower '
        'than expected customer adoption.',
    minImpactPercent: -10.0,
    maxImpactPercent: -4.0,
  ),

  // ── Sector-wide positive events ─────────────────────────────────────────────
  //    targetSector set — all stocks in that sector get the same impact.

  EventDefinition(
    id: 'sector_pos_tech',
    headlineTemplate: 'Technology sector surges on AI breakthrough announcement',
    descriptionTemplate:
        'A major research consortium published results of a breakthrough in '
        'large-language model efficiency, boosting investor confidence across '
        'the entire technology sector.',
    minImpactPercent: 2.0,
    maxImpactPercent: 7.0,
    targetSector: 'Technology',
  ),
  EventDefinition(
    id: 'sector_pos_energy',
    headlineTemplate: 'Global energy prices spike on supply disruption fears',
    descriptionTemplate:
        'Geopolitical tensions in a major oil-producing region sent energy '
        'commodity prices sharply higher, benefiting all listed energy firms.',
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
    targetSector: 'Energy',
  ),
  EventDefinition(
    id: 'sector_pos_healthcare',
    headlineTemplate: 'Healthcare reform bill boosts pharma outlook',
    descriptionTemplate:
        'A landmark healthcare bill passed, expanding reimbursement '
        'coverage for a broad range of treatments and bolstering revenue '
        'prospects for healthcare companies.',
    minImpactPercent: 2.0,
    maxImpactPercent: 6.0,
    targetSector: 'Healthcare',
  ),
  EventDefinition(
    id: 'sector_pos_consumer',
    headlineTemplate: 'Consumer confidence index hits 5-year high',
    descriptionTemplate:
        'The monthly consumer sentiment survey reached its highest reading '
        'since 2019, driving optimism that household spending will accelerate '
        'through the holiday season.',
    minImpactPercent: 1.5,
    maxImpactPercent: 5.0,
    targetSector: 'Consumer',
  ),
  EventDefinition(
    id: 'sector_pos_industrial',
    headlineTemplate: 'Infrastructure spending bill unlocks billions for industry',
    descriptionTemplate:
        'A new federal infrastructure bill allocates \$400B over five years '
        'to domestic manufacturing, logistics, and aerospace, directly '
        'benefiting industrial sector companies.',
    minImpactPercent: 2.5,
    maxImpactPercent: 7.0,
    targetSector: 'Industrial',
  ),

  // ── Sector-wide negative events ─────────────────────────────────────────────

  EventDefinition(
    id: 'sector_neg_finance',
    headlineTemplate: 'Central bank raises interest rates — banks under pressure',
    descriptionTemplate:
        'The Federal Reserve raised its benchmark rate by 50 basis points, '
        'tightening financial conditions and raising concerns about loan '
        'default rates across the banking sector.',
    minImpactPercent: -7.0,
    maxImpactPercent: -2.0,
    targetSector: 'Finance',
  ),
  EventDefinition(
    id: 'sector_neg_tech',
    headlineTemplate: 'Antitrust crackdown targets major tech firms',
    descriptionTemplate:
        'Regulators announced investigations into anti-competitive practices '
        'across the technology industry, creating legal overhang and '
        'dampening investor sentiment sector-wide.',
    minImpactPercent: -6.0,
    maxImpactPercent: -2.0,
    targetSector: 'Technology',
  ),
  EventDefinition(
    id: 'sector_neg_energy',
    headlineTemplate: 'Carbon tax legislation threatens energy sector margins',
    descriptionTemplate:
        'Proposed carbon pricing legislation would significantly increase '
        'operating costs for fossil fuel companies, weighing on near-term '
        'earnings expectations.',
    minImpactPercent: -8.0,
    maxImpactPercent: -3.0,
    targetSector: 'Energy',
  ),
  EventDefinition(
    id: 'sector_neg_consumer',
    headlineTemplate: 'Retail spending contracts amid rising inflation',
    descriptionTemplate:
        'Consumer spending data for the month came in well below forecasts, '
        'with households cutting back on discretionary purchases due to '
        'sustained inflation in essentials.',
    minImpactPercent: -5.0,
    maxImpactPercent: -2.0,
    targetSector: 'Consumer',
  ),
  EventDefinition(
    id: 'sector_neg_entertainment',
    headlineTemplate: 'Streaming wars intensify — entertainment stocks pressured',
    descriptionTemplate:
        'Subscriber growth data revealed broad-based deceleration across '
        'streaming platforms, sparking fears of an industry saturation point '
        'and a wave of price competition.',
    minImpactPercent: -7.0,
    maxImpactPercent: -2.5,
    targetSector: 'Entertainment',
  ),

  // ── Global market events ────────────────────────────────────────────────────
  //    isGlobalEvent: true — ALL stocks are affected.
  //    These are intentionally rare (5% daily probability in SimulationEngine).

  EventDefinition(
    id: 'global_crash',
    headlineTemplate:
        'GLOBAL SELLOFF: Geopolitical crisis triggers market-wide panic',
    descriptionTemplate:
        'Escalating tensions between major powers sparked a broad risk-off '
        'selloff. Every sector is in the red as investors flee to safety. '
        'Circuit breakers were triggered on several exchanges.',
    minImpactPercent: -14.0,
    maxImpactPercent: -8.0,
    isGlobalEvent: true,
  ),
  EventDefinition(
    id: 'global_rally',
    headlineTemplate:
        'MARKET RALLY: Central banks announce coordinated stimulus package',
    descriptionTemplate:
        'G7 central banks announced a coordinated quantitative easing program '
        'injecting \$1.2T into global markets. Risk assets surged across '
        'all sectors as liquidity conditions improved dramatically.',
    minImpactPercent: 5.0,
    maxImpactPercent: 10.0,
    isGlobalEvent: true,
  ),
  EventDefinition(
    id: 'global_volatility',
    headlineTemplate:
        'VOLATILITY SPIKE: Inflation data shocks economists',
    descriptionTemplate:
        'Unexpectedly high inflation figures sent markets into disarray. '
        'Some stocks rose on pricing power optimism while others fell '
        'sharply on margin compression fears. Direction varies by sector.',
    // For global_volatility, SimulationEngine applies a random sign per stock
    // rather than the same direction to all. The range is intentionally wide.
    minImpactPercent: -6.0,
    maxImpactPercent: 6.0,
    isGlobalEvent: true,
  ),
];
