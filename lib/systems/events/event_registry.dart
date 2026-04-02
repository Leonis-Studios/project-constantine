// ─────────────────────────────────────────────────────────────────────────────
// event_registry.dart  (lib/systems/events/)
//
// PURPOSE: The single source of truth for all market event definitions.
//          All 30 original events are migrated here with the new model shape,
//          retaining identical impact ranges to preserve existing game balance.
//
// TO ADD A NEW EVENT:
//   1. Declare a new `static const MarketEventDefinition` in this file.
//   2. Add it to the `all` list at the bottom.
//   That's it — no other file needs changing.
//
// BALANCING TAG GUIDE:
//   'correction'     — suitable when market has been too bullish; bearish
//   'anti-whale'     — suitable when one position dominates a portfolio
//   'catch-up'       — suitable to help a portfolio recover after a large drop
//   'crash-recovery' — suitable after a sustained bearish streak
// ─────────────────────────────────────────────────────────────────────────────

import 'market_event.dart';

class EventRegistry {

  // ── Positive company-specific events ────────────────────────────────────────
  // Company events target a single randomly chosen stock.
  // affectedSector: 'COMPANY'

  static const MarketEventDefinition posEarningsBeat = MarketEventDefinition(
    id: 'pos_earnings_beat',
    name: '{company} accidentally discovers money behind the couch cushions',
    description:
        '{company} reported quarterly earnings 18% above expectations after '
        'the CFO found an uncashed cheque in a desk drawer. '
        'Guidance raised. Desk drawer to be framed.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.65,
    minImpactPercent: 5.0,
    maxImpactPercent: 14.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: [],
  );

  static const MarketEventDefinition posPartnership = MarketEventDefinition(
    id: 'pos_partnership',
    name: '{company} signs landmark deal with a wizard',
    description:
        'A licensed wizard endorsed {company}\'s blockchain project in a '
        'notarised letter sealed with glitter wax. Analysts call it '
        '"unverifiable but very bullish."',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.70,
    minImpactPercent: 6.0,
    maxImpactPercent: 16.0,
    baseProbability: 0.18,
    cooldownHours: 8,
    balancingTags: [],
  );

  static const MarketEventDefinition posProductLaunch = MarketEventDefinition(
    id: 'pos_product_launch',
    name: '{company} launches product — customers moderately not confused',
    description:
        '{company}\'s latest release shipped on time and worked on the first try. '
        'Internal Slack was briefly silent with stunned respect. '
        'Pre-orders exceeded projections by 40%.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.50,
    minImpactPercent: 4.0,
    maxImpactPercent: 12.0,
    baseProbability: 0.22,
    cooldownHours: 8,
    balancingTags: [],
  );

  static const MarketEventDefinition posRegulatoryApproval = MarketEventDefinition(
    id: 'pos_regulatory_approval',
    name: 'Government approves {company} despite not fully reading the application',
    description:
        'Regulators granted {company} approval after a committee member '
        'skimmed the executive summary and decided it "sounded fine." '
        'Three new markets now open for business.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.75,
    minImpactPercent: 7.0,
    maxImpactPercent: 18.0,
    baseProbability: 0.15,
    cooldownHours: 10,
    balancingTags: [],
  );

  static const MarketEventDefinition posBuyback = MarketEventDefinition(
    id: 'pos_buyback',
    name: '{company} announces share buyback funded by "found money"',
    description:
        'The {company} board approved a \$500M repurchase plan funded by '
        'what the CFO described in the earnings call as "various jars '
        'and at least one shoebox." Investors inexplicably reassured.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.35,
    minImpactPercent: 3.0,
    maxImpactPercent: 8.0,
    baseProbability: 0.25,
    cooldownHours: 8,
    balancingTags: [],
  );

  static const MarketEventDefinition posAnalystUpgrade = MarketEventDefinition(
    id: 'pos_analyst_upgrade',
    name: 'Analyst upgrades {company} after reading their Wikipedia page',
    description:
        'A sell-side analyst upgraded {company} to Strong Buy, citing '
        'the company\'s "excellent logo" and a hunch described as '
        '"professionally developed intuition." Price target raised 35%.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.45,
    minImpactPercent: 4.0,
    maxImpactPercent: 10.0,
    baseProbability: 0.22,
    cooldownHours: 8,
    balancingTags: [],
  );

  static const MarketEventDefinition posAcquisition = MarketEventDefinition(
    id: 'pos_acquisition',
    name: '{company} acquires startup for three goats and a firm handshake',
    description:
        '{company} completed the acquisition of a private startup for an '
        'undisclosed sum that sources describe as "less than you\'d think." '
        'Both CEOs described the deal as "very real and definitely happening."',
    affectedSector: 'COMPANY',
    direction: EventDirection.bullish,
    magnitude: 0.40,
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: [],
  );

  // ── Negative company-specific events ────────────────────────────────────────

  static const MarketEventDefinition negEarningsMiss = MarketEventDefinition(
    id: 'neg_earnings_miss',
    name: '{company} misses earnings after CFO confused "revenue" with "vibes"',
    description:
        '{company} reported earnings well below expectations. The CFO cited '
        '"a fundamental misunderstanding of what numbers mean" and will be '
        'retrained on a spreadsheet course starting Monday.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.60,
    minImpactPercent: -14.0,
    maxImpactPercent: -4.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition negLawsuit = MarketEventDefinition(
    id: 'neg_lawsuit',
    name: '{company} sued by a guy who seems really sure about this',
    description:
        'A class of 200,000 plaintiffs filed suit against {company} alleging '
        'the company\'s product made their Wi-Fi "feel weird." '
        'Legal fees expected to exceed the original product price.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.55,
    minImpactPercent: -12.0,
    maxImpactPercent: -4.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition negCeoResign = MarketEventDefinition(
    id: 'neg_ceo_resign',
    name: '{company} CEO resigns to pursue career as a competitive eater',
    description:
        'The CEO of {company} stepped down effective immediately. A farewell '
        'memo cited "a passion for hot dogs and freedom." '
        'The board is reviewing candidates who have not mentioned hot dogs.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.80,
    minImpactPercent: -18.0,
    maxImpactPercent: -8.0,
    baseProbability: 0.15,
    cooldownHours: 12,
    balancingTags: ['correction', 'anti-whale'],
  );

  static const MarketEventDefinition negRecall = MarketEventDefinition(
    id: 'neg_recall',
    name: '{company} recalls flagship product after discovering it does the opposite of what it says',
    description:
        '{company} initiated a recall of 1.8 million units. The safety defect '
        'was described in the filing as "directionally incorrect functionality." '
        'Remediation costs are expected to be considerable.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.80,
    minImpactPercent: -15.0,
    maxImpactPercent: -6.0,
    baseProbability: 0.15,
    cooldownHours: 12,
    balancingTags: ['correction', 'anti-whale'],
  );

  static const MarketEventDefinition negContractLoss = MarketEventDefinition(
    id: 'neg_contract_loss',
    name: '{company} loses contract to competitor who showed up in a nicer van',
    description:
        'A government agency awarded a major contract to a rival after '
        '{company}\'s proposal was described as "grammatically brave." '
        'The lost revenue represented 12% of annual income.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.55,
    minImpactPercent: -11.0,
    maxImpactPercent: -5.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition negAnalystDowngrade = MarketEventDefinition(
    id: 'neg_analyst_downgrade',
    name: 'Analyst downgrades {company} after personally being annoyed by their app',
    description:
        'A brokerage downgraded {company} to Sell after an analyst experienced '
        'three loading spinners in one session and "simply could not let it go." '
        'Margin concerns also cited.',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.45,
    minImpactPercent: -9.0,
    maxImpactPercent: -3.0,
    baseProbability: 0.22,
    cooldownHours: 8,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition negGuidanceCut = MarketEventDefinition(
    id: 'neg_guidance_cut',
    name: '{company} cuts guidance after COO accidentally tweets internal memo',
    description:
        '{company} reduced full-year revenue guidance by 8% following what '
        'the company calls "a digital communication incident" and what '
        'Twitter calls "extremely funny."',
    affectedSector: 'COMPANY',
    direction: EventDirection.bearish,
    magnitude: 0.50,
    minImpactPercent: -10.0,
    maxImpactPercent: -4.0,
    baseProbability: 0.20,
    cooldownHours: 8,
    balancingTags: ['correction'],
  );

  // ── Sector-wide positive events ──────────────────────────────────────────────
  // affectedSector: one of the seven sector names

  static const MarketEventDefinition sectorPosTech = MarketEventDefinition(
    id: 'sector_pos_tech',
    name: 'Technology sector surges after someone claims AI can now smell money',
    description:
        'A research paper claiming AI can detect financial opportunity via '
        '"olfactory market signal modelling" sent technology stocks soaring. '
        'Peer review has been requested and not yet performed.',
    affectedSector: 'Technology',
    direction: EventDirection.bullish,
    magnitude: 0.40,
    minImpactPercent: 2.0,
    maxImpactPercent: 7.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['catch-up'],
  );

  static const MarketEventDefinition sectorPosEnergy = MarketEventDefinition(
    id: 'sector_pos_energy',
    name: 'Energy stocks boom as someone unplugs a very important freezer',
    description:
        'A supply shock in global energy markets was traced to a freezer '
        'malfunction at a key distribution node. Analysts say the incident '
        'was "preventable but extremely profitable for investors."',
    affectedSector: 'Energy',
    direction: EventDirection.bullish,
    magnitude: 0.50,
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['catch-up'],
  );

  static const MarketEventDefinition sectorPosHealthcare = MarketEventDefinition(
    id: 'sector_pos_healthcare',
    name: 'Healthcare stocks rally after government discovers people are still sick',
    description:
        'A landmark spending bill expanded coverage for "conditions that are '
        'definitely real and not just vibes," boosting revenue projections '
        'for all listed healthcare companies.',
    affectedSector: 'Healthcare',
    direction: EventDirection.bullish,
    magnitude: 0.35,
    minImpactPercent: 2.0,
    maxImpactPercent: 6.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['catch-up'],
  );

  static const MarketEventDefinition sectorPosConsumer = MarketEventDefinition(
    id: 'sector_pos_consumer',
    name: 'Consumer sector surges: people still buying things, experts confirm',
    description:
        'A consumer confidence survey hit its highest reading since someone '
        'last felt good about things, driving optimism that people will '
        'continue to exchange money for objects they want.',
    affectedSector: 'Consumer',
    direction: EventDirection.bullish,
    magnitude: 0.30,
    minImpactPercent: 1.5,
    maxImpactPercent: 5.0,
    baseProbability: 0.20,
    cooldownHours: 12,
    balancingTags: ['catch-up'],
  );

  static const MarketEventDefinition sectorPosIndustrial = MarketEventDefinition(
    id: 'sector_pos_industrial',
    name: 'Industrial sector benefits as government builds a very large thing',
    description:
        'A federal infrastructure bill allocated \$400B to domestic '
        'manufacturing after a senator reportedly said "let\'s build something '
        'big" and nobody disagreed fast enough.',
    affectedSector: 'Industrial',
    direction: EventDirection.bullish,
    magnitude: 0.40,
    minImpactPercent: 2.5,
    maxImpactPercent: 7.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['catch-up'],
  );

  // ── Sector-wide negative events ──────────────────────────────────────────────

  static const MarketEventDefinition sectorNegFinance = MarketEventDefinition(
    id: 'sector_neg_finance',
    name:
        'Finance sector rattled as central bank raises rates to "make money more expensive, somehow"',
    description:
        'The Federal Reserve raised its benchmark rate by 50 basis points and '
        'issued a statement that economists described as "technically a sentence." '
        'Banking stocks fell on margin pressure fears.',
    affectedSector: 'Finance',
    direction: EventDirection.bearish,
    magnitude: 0.45,
    minImpactPercent: -7.0,
    maxImpactPercent: -2.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition sectorNegTech = MarketEventDefinition(
    id: 'sector_neg_tech',
    name: 'Tech sector slumps after regulator learns what an algorithm is',
    description:
        'Regulators launched investigations into tech companies after a '
        'committee member Googled "what is software" and became alarmed. '
        'Sentiment darkened across the sector pending a follow-up Google.',
    affectedSector: 'Technology',
    direction: EventDirection.bearish,
    magnitude: 0.40,
    minImpactPercent: -6.0,
    maxImpactPercent: -2.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition sectorNegEnergy = MarketEventDefinition(
    id: 'sector_neg_energy',
    name: 'Energy sector hit after government proposes "the sun should be free"',
    description:
        'Proposed energy legislation that one analyst described as "based on '
        'vibes and spite" would significantly raise operating costs. '
        'Solar companies are most confused.',
    affectedSector: 'Energy',
    direction: EventDirection.bearish,
    magnitude: 0.50,
    minImpactPercent: -8.0,
    maxImpactPercent: -3.0,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition sectorNegConsumer = MarketEventDefinition(
    id: 'sector_neg_consumer',
    name: 'Consumer sector slumps as people remember they can just not buy things',
    description:
        'Consumer spending came in well below forecasts after a widely shared '
        'social media post reminded people that saving money is also an option. '
        'Discretionary stocks fell sharply.',
    affectedSector: 'Consumer',
    direction: EventDirection.bearish,
    magnitude: 0.35,
    minImpactPercent: -5.0,
    maxImpactPercent: -2.0,
    baseProbability: 0.20,
    cooldownHours: 12,
    balancingTags: ['correction'],
  );

  static const MarketEventDefinition sectorNegEntertainment = MarketEventDefinition(
    id: 'sector_neg_entertainment',
    name: 'Streaming sector tanks as viewers discover skill issues with their remote',
    description:
        'Subscriber growth decelerated across all platforms after a study '
        'found 40% of cancellations stem from users being unable to find '
        'anything good and blaming the service personally.',
    affectedSector: 'Entertainment',
    direction: EventDirection.bearish,
    magnitude: 0.45,
    minImpactPercent: -7.0,
    maxImpactPercent: -2.5,
    baseProbability: 0.18,
    cooldownHours: 12,
    balancingTags: ['correction'],
  );

  // ── Global market events ─────────────────────────────────────────────────────
  // affectedSector: 'ALL' — all stocks affected simultaneously.
  // Rare by design: low baseProbability + long cooldown.

  static const MarketEventDefinition globalCrash = MarketEventDefinition(
    id: 'global_crash',
    name: 'GLOBAL SELLOFF: Someone accidentally unplugged the internet',
    description:
        'A facility manager in an undisclosed location tripped over a power '
        'cable and caused cascading failures across global markets. '
        'The individual has been described as "sheepish but uninjured." '
        'All sectors in the red. Circuit breakers triggered.',
    affectedSector: 'ALL',
    direction: EventDirection.bearish,
    magnitude: 0.85,
    minImpactPercent: -14.0,
    maxImpactPercent: -8.0,
    baseProbability: 0.03,
    cooldownHours: 48,
    balancingTags: ['anti-whale', 'correction'],
  );

  static const MarketEventDefinition globalRally = MarketEventDefinition(
    id: 'global_rally',
    name: 'MARKET RALLY: Guy on television seems really confident about everything',
    description:
        'A charismatic financial commentator appeared on three channels '
        'simultaneously and said "this is fine, actually" with such conviction '
        'that G7 central banks issued a coordinated stimulus package. '
        'Risk assets surged across all sectors.',
    affectedSector: 'ALL',
    direction: EventDirection.bullish,
    magnitude: 0.75,
    minImpactPercent: 5.0,
    maxImpactPercent: 10.0,
    baseProbability: 0.03,
    cooldownHours: 48,
    balancingTags: ['catch-up', 'crash-recovery'],
  );

  static const MarketEventDefinition globalVolatility = MarketEventDefinition(
    id: 'global_volatility',
    name: 'VOLATILITY SPIKE: Economists disagree on whether numbers go up or down',
    description:
        'An unusually public disagreement between two macroeconomists about '
        'the direction of literally everything sent markets into disarray. '
        'Some stocks rose, others fell, most just sat there looking confused. '
        'Direction varies wildly.',
    affectedSector: 'ALL',
    direction: EventDirection.volatile,
    magnitude: 0.50,
    minImpactPercent: -6.0,
    maxImpactPercent: 6.0,
    baseProbability: 0.04,
    cooldownHours: 24,
    balancingTags: [],
  );

  // ── Master list ──────────────────────────────────────────────────────────────
  //
  // Add new event constants above, then reference them here.
  // EventEngine and SimulationEngine pull from this list at runtime.

  static const List<MarketEventDefinition> all = [
    // Company positive
    posEarningsBeat,
    posPartnership,
    posProductLaunch,
    posRegulatoryApproval,
    posBuyback,
    posAnalystUpgrade,
    posAcquisition,
    // Company negative
    negEarningsMiss,
    negLawsuit,
    negCeoResign,
    negRecall,
    negContractLoss,
    negAnalystDowngrade,
    negGuidanceCut,
    // Sector positive
    sectorPosTech,
    sectorPosEnergy,
    sectorPosHealthcare,
    sectorPosConsumer,
    sectorPosIndustrial,
    // Sector negative
    sectorNegFinance,
    sectorNegTech,
    sectorNegEnergy,
    sectorNegConsumer,
    sectorNegEntertainment,
    // Global
    globalCrash,
    globalRally,
    globalVolatility,
  ];
}
