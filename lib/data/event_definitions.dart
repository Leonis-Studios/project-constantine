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
    headlineTemplate: '{company} accidentally discovers money behind the couch cushions',
    descriptionTemplate:
        '{company} reported quarterly earnings 18% above expectations after '
        'the CFO found an uncashed cheque in a desk drawer. '
        'Guidance raised. Desk drawer to be framed.',
    minImpactPercent: 5.0,
    maxImpactPercent: 14.0,
  ),
  EventDefinition(
    id: 'pos_partnership',
    headlineTemplate: '{company} signs landmark deal with a wizard',
    descriptionTemplate:
        'A licensed wizard endorsed {company}\'s blockchain project in a '
        'notarised letter sealed with glitter wax. Analysts call it '
        '"unverifiable but very bullish."',
    minImpactPercent: 6.0,
    maxImpactPercent: 16.0,
  ),
  EventDefinition(
    id: 'pos_product_launch',
    headlineTemplate: '{company} launches product — customers moderately not confused',
    descriptionTemplate:
        '{company}\'s latest release shipped on time and worked on the first try. '
        'Internal Slack was briefly silent with stunned respect. '
        'Pre-orders exceeded projections by 40%.',
    minImpactPercent: 4.0,
    maxImpactPercent: 12.0,
  ),
  EventDefinition(
    id: 'pos_regulatory_approval',
    headlineTemplate: 'Government approves {company} despite not fully reading the application',
    descriptionTemplate:
        'Regulators granted {company} approval after a committee member '
        'skimmed the executive summary and decided it "sounded fine." '
        'Three new markets now open for business.',
    minImpactPercent: 7.0,
    maxImpactPercent: 18.0,
  ),
  EventDefinition(
    id: 'pos_buyback',
    headlineTemplate: '{company} announces share buyback funded by "found money"',
    descriptionTemplate:
        'The {company} board approved a \$500M repurchase plan funded by '
        'what the CFO described in the earnings call as "various jars '
        'and at least one shoebox." Investors inexplicably reassured.',
    minImpactPercent: 3.0,
    maxImpactPercent: 8.0,
  ),
  EventDefinition(
    id: 'pos_analyst_upgrade',
    headlineTemplate: 'Analyst upgrades {company} after reading their Wikipedia page',
    descriptionTemplate:
        'A sell-side analyst upgraded {company} to Strong Buy, citing '
        'the company\'s "excellent logo" and a hunch described as '
        '"professionally developed intuition." Price target raised 35%.',
    minImpactPercent: 4.0,
    maxImpactPercent: 10.0,
  ),
  EventDefinition(
    id: 'pos_acquisition',
    headlineTemplate: '{company} acquires startup for three goats and a firm handshake',
    descriptionTemplate:
        '{company} completed the acquisition of a private startup for an '
        'undisclosed sum that sources describe as "less than you\'d think." '
        'Both CEOs described the deal as "very real and definitely happening."',
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
  ),

  // ── Negative company-specific events ───────────────────────────────────────

  EventDefinition(
    id: 'neg_earnings_miss',
    headlineTemplate: '{company} misses earnings after CFO confused "revenue" with "vibes"',
    descriptionTemplate:
        '{company} reported earnings well below expectations. The CFO cited '
        '"a fundamental misunderstanding of what numbers mean" and will be '
        'retrained on a spreadsheet course starting Monday.',
    minImpactPercent: -14.0,
    maxImpactPercent: -4.0,
  ),
  EventDefinition(
    id: 'neg_lawsuit',
    headlineTemplate: '{company} sued by a guy who seems really sure about this',
    descriptionTemplate:
        'A class of 200,000 plaintiffs filed suit against {company} alleging '
        'the company\'s product made their Wi-Fi "feel weird." '
        'Legal fees expected to exceed the original product price.',
    minImpactPercent: -12.0,
    maxImpactPercent: -4.0,
  ),
  EventDefinition(
    id: 'neg_ceo_resign',
    headlineTemplate: '{company} CEO resigns to pursue career as a competitive eater',
    descriptionTemplate:
        'The CEO of {company} stepped down effective immediately. A farewell '
        'memo cited "a passion for hot dogs and freedom." '
        'The board is reviewing candidates who have not mentioned hot dogs.',
    minImpactPercent: -18.0,
    maxImpactPercent: -8.0,
  ),
  EventDefinition(
    id: 'neg_recall',
    headlineTemplate: '{company} recalls flagship product after discovering it does the opposite of what it says',
    descriptionTemplate:
        '{company} initiated a recall of 1.8 million units. The safety defect '
        'was described in the filing as "directionally incorrect functionality." '
        'Remediation costs are expected to be considerable.',
    minImpactPercent: -15.0,
    maxImpactPercent: -6.0,
  ),
  EventDefinition(
    id: 'neg_contract_loss',
    headlineTemplate: '{company} loses contract to competitor who showed up in a nicer van',
    descriptionTemplate:
        'A government agency awarded a major contract to a rival after '
        '{company}\'s proposal was described as "grammatically brave." '
        'The lost revenue represented 12% of annual income.',
    minImpactPercent: -11.0,
    maxImpactPercent: -5.0,
  ),
  EventDefinition(
    id: 'neg_analyst_downgrade',
    headlineTemplate: 'Analyst downgrades {company} after personally being annoyed by their app',
    descriptionTemplate:
        'A brokerage downgraded {company} to Sell after an analyst experienced '
        'three loading spinners in one session and "simply could not let it go." '
        'Margin concerns also cited.',
    minImpactPercent: -9.0,
    maxImpactPercent: -3.0,
  ),
  EventDefinition(
    id: 'neg_guidance_cut',
    headlineTemplate: '{company} cuts guidance after COO accidentally tweets internal memo',
    descriptionTemplate:
        '{company} reduced full-year revenue guidance by 8% following what '
        'the company calls "a digital communication incident" and what '
        'Twitter calls "extremely funny."',
    minImpactPercent: -10.0,
    maxImpactPercent: -4.0,
  ),

  // ── Sector-wide positive events ─────────────────────────────────────────────
  //    targetSector set — all stocks in that sector get the same impact.

  EventDefinition(
    id: 'sector_pos_tech',
    headlineTemplate: 'Technology sector surges after someone claims AI can now smell money',
    descriptionTemplate:
        'A research paper claiming AI can detect financial opportunity via '
        '"olfactory market signal modelling" sent technology stocks soaring. '
        'Peer review has been requested and not yet performed.',
    minImpactPercent: 2.0,
    maxImpactPercent: 7.0,
    targetSector: 'Technology',
  ),
  EventDefinition(
    id: 'sector_pos_energy',
    headlineTemplate: 'Energy stocks boom as someone unplugs a very important freezer',
    descriptionTemplate:
        'A supply shock in global energy markets was traced to a freezer '
        'malfunction at a key distribution node. Analysts say the incident '
        'was "preventable but extremely profitable for investors."',
    minImpactPercent: 3.0,
    maxImpactPercent: 9.0,
    targetSector: 'Energy',
  ),
  EventDefinition(
    id: 'sector_pos_healthcare',
    headlineTemplate: 'Healthcare stocks rally after government discovers people are still sick',
    descriptionTemplate:
        'A landmark spending bill expanded coverage for "conditions that are '
        'definitely real and not just vibes," boosting revenue projections '
        'for all listed healthcare companies.',
    minImpactPercent: 2.0,
    maxImpactPercent: 6.0,
    targetSector: 'Healthcare',
  ),
  EventDefinition(
    id: 'sector_pos_consumer',
    headlineTemplate: 'Consumer sector surges: people still buying things, experts confirm',
    descriptionTemplate:
        'A consumer confidence survey hit its highest reading since someone '
        'last felt good about things, driving optimism that people will '
        'continue to exchange money for objects they want.',
    minImpactPercent: 1.5,
    maxImpactPercent: 5.0,
    targetSector: 'Consumer',
  ),
  EventDefinition(
    id: 'sector_pos_industrial',
    headlineTemplate: 'Industrial sector benefits as government builds a very large thing',
    descriptionTemplate:
        'A federal infrastructure bill allocated \$400B to domestic '
        'manufacturing after a senator reportedly said "let\'s build something '
        'big" and nobody disagreed fast enough.',
    minImpactPercent: 2.5,
    maxImpactPercent: 7.0,
    targetSector: 'Industrial',
  ),

  // ── Sector-wide negative events ─────────────────────────────────────────────

  EventDefinition(
    id: 'sector_neg_finance',
    headlineTemplate: 'Finance sector rattled as central bank raises rates to "make money more expensive, somehow"',
    descriptionTemplate:
        'The Federal Reserve raised its benchmark rate by 50 basis points and '
        'issued a statement that economists described as "technically a sentence." '
        'Banking stocks fell on margin pressure fears.',
    minImpactPercent: -7.0,
    maxImpactPercent: -2.0,
    targetSector: 'Finance',
  ),
  EventDefinition(
    id: 'sector_neg_tech',
    headlineTemplate: 'Tech sector slumps after regulator learns what an algorithm is',
    descriptionTemplate:
        'Regulators launched investigations into tech companies after a '
        'committee member Googled "what is software" and became alarmed. '
        'Sentiment darkened across the sector pending a follow-up Google.',
    minImpactPercent: -6.0,
    maxImpactPercent: -2.0,
    targetSector: 'Technology',
  ),
  EventDefinition(
    id: 'sector_neg_energy',
    headlineTemplate: 'Energy sector hit after government proposes "the sun should be free"',
    descriptionTemplate:
        'Proposed energy legislation that one analyst described as "based on '
        'vibes and spite" would significantly raise operating costs. '
        'Solar companies are most confused.',
    minImpactPercent: -8.0,
    maxImpactPercent: -3.0,
    targetSector: 'Energy',
  ),
  EventDefinition(
    id: 'sector_neg_consumer',
    headlineTemplate: 'Consumer sector slumps as people remember they can just not buy things',
    descriptionTemplate:
        'Consumer spending came in well below forecasts after a widely shared '
        'social media post reminded people that saving money is also an option. '
        'Discretionary stocks fell sharply.',
    minImpactPercent: -5.0,
    maxImpactPercent: -2.0,
    targetSector: 'Consumer',
  ),
  EventDefinition(
    id: 'sector_neg_entertainment',
    headlineTemplate: 'Streaming sector tanks as viewers discover skill issues with their remote',
    descriptionTemplate:
        'Subscriber growth decelerated across all platforms after a study '
        'found 40% of cancellations stem from users being unable to find '
        'anything good and blaming the service personally.',
    minImpactPercent: -7.0,
    maxImpactPercent: -2.5,
    targetSector: 'Entertainment',
  ),

  // ── Global market events ────────────────────────────────────────────────────
  //    isGlobalEvent: true — ALL stocks are affected.
  //    These are intentionally rare (5% daily probability in SimulationEngine).

  EventDefinition(
    id: 'global_crash',
    headlineTemplate: 'GLOBAL SELLOFF: Someone accidentally unplugged the internet',
    descriptionTemplate:
        'A facility manager in an undisclosed location tripped over a power '
        'cable and caused cascading failures across global markets. '
        'The individual has been described as "sheepish but uninjured." '
        'All sectors in the red. Circuit breakers triggered.',
    minImpactPercent: -14.0,
    maxImpactPercent: -8.0,
    isGlobalEvent: true,
  ),
  EventDefinition(
    id: 'global_rally',
    headlineTemplate: 'MARKET RALLY: Guy on television seems really confident about everything',
    descriptionTemplate:
        'A charismatic financial commentator appeared on three channels '
        'simultaneously and said "this is fine, actually" with such conviction '
        'that G7 central banks issued a coordinated stimulus package. '
        'Risk assets surged across all sectors.',
    minImpactPercent: 5.0,
    maxImpactPercent: 10.0,
    isGlobalEvent: true,
  ),
  EventDefinition(
    id: 'global_volatility',
    headlineTemplate: 'VOLATILITY SPIKE: Economists disagree on whether numbers go up or down',
    descriptionTemplate:
        'An unusually public disagreement between two macroeconomists about '
        'the direction of literally everything sent markets into disarray. '
        'Some stocks rose, others fell, most just sat there looking confused. '
        'Direction varies wildly.',
    // For global_volatility, SimulationEngine applies a random sign per stock
    // rather than the same direction to all. The range is intentionally wide.
    minImpactPercent: -6.0,
    maxImpactPercent: 6.0,
    isGlobalEvent: true,
  ),
];
