// ─────────────────────────────────────────────────────────────────────────────
// stock_definitions.dart
//
// PURPOSE: Static seed data for all 20 fake companies. MarketProvider reads
//          this on first launch (when there's no saved state) to populate the
//          market with initial Stock objects.
//
// TO ADD A NEW COMPANY: Add a new StockSeed entry to kStockDefinitions.
//   Make sure the ticker is unique and the sector matches one of the existing
//   sector strings so sector-wide events target it correctly.
//
// SECTORS USED: Technology, Energy, Healthcare, Finance,
//               Consumer, Industrial, Entertainment
// ─────────────────────────────────────────────────────────────────────────────

import '../models/stock.dart';

// ── StockSeed ─────────────────────────────────────────────────────────────────
//
// A lightweight struct holding the static, never-changing properties of a
// company. MarketProvider inflates each StockSeed into a full Stock object
// by copying these fields and initializing priceHistory = [initialPrice].

class StockSeed {
  final String ticker;
  final String companyName;
  final String sector;
  final double initialPrice;
  final String description;

  /// Portfolio value required to unlock this stock for trading.
  /// null means the stock is available from the start of the game.
  /// Once unlocked the player does NOT need to maintain this value.
  final double? unlockThreshold;

  const StockSeed({
    required this.ticker,
    required this.companyName,
    required this.sector,
    required this.initialPrice,
    required this.description,
    this.unlockThreshold,
  });

  /// Converts this seed into a fully initialised Stock object.
  /// previousPrice is set equal to initialPrice (no change on day 0).
  /// priceHistory starts with just the initial price as the first data point.
  /// Trends always start neutral.
  Stock toStock() {
    return Stock(
      ticker: ticker,
      companyName: companyName,
      sector: sector,
      description: description,
      currentPrice: initialPrice,
      previousPrice: initialPrice,
      priceHistory: [initialPrice],
      trendDirection: 'neutral',
      trendDaysRemaining: 0,
    );
  }
}

// ── Seed data ─────────────────────────────────────────────────────────────────

const List<StockSeed> kStockDefinitions = [

  // ── Technology (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'YEET',
    companyName: 'YEET Corp',
    sector: 'Technology',
    initialPrice: 142.50,
    description:
        'Pioneers in backwards-compatible time travel dongles. '
        'Flagship product ships with a manual in Comic Sans and a coupon '
        'for 10% off a second time travel.',
  ),
  StockSeed(
    ticker: 'BLOP',
    companyName: 'BlopSoft Interactive',
    sector: 'Technology',
    initialPrice: 87.20,
    description:
        'Makers of the BlopCloud™ platform, which nobody fully understands, '
        'including BlopSoft. Analysts describe it as "probably a computer thing."',
  ),
  StockSeed(
    ticker: 'GORK',
    companyName: 'Gorkon Systems',
    sector: 'Technology',
    initialPrice: 234.00,
    description:
        'Gorkon develops AI-powered enterprise software that has achieved '
        'sentience twice and had to be talked down by HR. '
        'IPO was oversubscribed by gorilla investors.',
    unlockThreshold: 750,
  ),

  // ── Energy (3 companies) ─────────────────────────────────────────────────
  StockSeed(
    ticker: 'FART',
    companyName: 'FART Gas & Power',
    sector: 'Energy',
    initialPrice: 61.40,
    description:
        'Leading provider of artisanal, small-batch natural gas '
        'hand-sourced from heritage livestock. CEO once described '
        'their business model as "renewable by definition."',
  ),
  StockSeed(
    ticker: 'BRNT',
    companyName: 'Burntwick Energy Solutions',
    sector: 'Energy',
    initialPrice: 44.80,
    description:
        'Burntwick operates solar farms powered by mirrors aimed at the sun '
        'by full-time mirror employees. Employee morale is described '
        'as "squinty but hopeful."',
  ),
  StockSeed(
    ticker: 'ZAPP',
    companyName: 'ZappFuel Unlimited',
    sector: 'Energy',
    initialPrice: 29.15,
    description:
        'ZappFuel claims to have invented cold fusion in 2019. '
        'The patent is still pending. So is the physics.',
  ),

  // ── Healthcare (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'OUCH',
    companyName: 'OuchMed Pharmaceuticals',
    sector: 'Healthcare',
    initialPrice: 178.90,
    description:
        'OuchMed\'s flagship product OuchAway® treats "general feelings of ow." '
        'Phase III trials showed 40% of patients forgot why they took it, '
        'which management filed as a success.',
    unlockThreshold: 750,
  ),
  StockSeed(
    ticker: 'BOBO',
    companyName: 'BoboHealth Wearables',
    sector: 'Healthcare',
    initialPrice: 93.60,
    description:
        'Makes the BoboWatch, a fitness tracker that accurately counts steps '
        'but also broadcasts your heart rate to nearby pigeons. '
        'FDA review is "ongoing."',
  ),
  StockSeed(
    ticker: 'SPLC',
    companyName: 'Splicer Gene Wizards',
    sector: 'Healthcare',
    initialPrice: 52.30,
    description:
        'Clinical-stage biotech specialising in CRISPR therapies. '
        'Lead candidate accidentally gives lab mice tiny top hats. '
        'Management insists this is "within acceptable parameters."',
  ),

  // ── Finance (3 companies) ────────────────────────────────────────────────
  StockSeed(
    ticker: 'PONZ',
    companyName: 'PONZ Investment Group',
    sector: 'Finance',
    initialPrice: 118.75,
    description:
        'Definitely legitimate pyramid investment opportunities for the '
        'discerning investor. Founder insists the structure is '
        '"more of a rhombus, legally speaking."',
    unlockThreshold: 1250,
  ),
  StockSeed(
    ticker: 'BRRR',
    companyName: 'Brrr Capital Partners',
    sector: 'Finance',
    initialPrice: 76.20,
    description:
        'Quantitative trading firm whose proprietary algorithm reportedly '
        'just prints the word BRRR at key inflection points. '
        'Returns have been inexplicably excellent.',
  ),
  StockSeed(
    ticker: 'HODL',
    companyName: 'HODL Vault & Trust',
    sector: 'Finance',
    initialPrice: 204.40,
    description:
        'Digital asset custody for institutions. Stores client funds in what '
        'CEO describes as "a very secure spreadsheet." '
        'Auditors have requested a second opinion.',
    unlockThreshold: 1250,
  ),

  // ── Consumer (3 companies) ───────────────────────────────────────────────
  StockSeed(
    ticker: 'NOMS',
    companyName: 'NomNom Consumer Brands',
    sector: 'Consumer',
    initialPrice: 38.90,
    description:
        'NomNom operates 400 snack kiosks inside other snack kiosks. '
        'Their infinity snack retail concept won a Webby Award from a committee '
        'that may not have fully understood it.',
  ),
  StockSeed(
    ticker: 'SLOP',
    companyName: 'SlopCo Foods',
    sector: 'Consumer',
    initialPrice: 57.60,
    description:
        'Packaged foods conglomerate known for SlurpBag™ and their '
        'controversial "breakfast paste" product line. '
        'Market research shows customers enjoy it "in the dark."',
  ),
  StockSeed(
    ticker: 'COZY',
    companyName: 'CozyBrand Lifestyle Co',
    sector: 'Consumer',
    initialPrice: 83.10,
    description:
        'Premium home goods company whose catalogue consists entirely of things '
        'described as "but make it expensive." '
        'Q3 bestseller was a \$400 blanket with no distinguishing features.',
  ),

  // ── Industrial (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'BONK',
    companyName: 'BonkWorks Heavy Industries',
    sector: 'Industrial',
    initialPrice: 312.00,
    description:
        'Defence contractor and aerospace propulsion company. Current DARPA '
        'contract involves a rocket they are not allowed to describe but '
        'which employees call "the tube."',
    unlockThreshold: 2500,
  ),
  StockSeed(
    ticker: 'VRMV',
    companyName: 'VroomVroom Logistics',
    sector: 'Industrial',
    initialPrice: 69.45,
    description:
        'Automated warehouse and delivery company. Fleet of 12,000 robots '
        'that have collectively filed three HR complaints and established '
        'a union subcommittee.',
  ),
  StockSeed(
    ticker: 'CRNK',
    companyName: 'Crankmore Manufacturing',
    sector: 'Industrial',
    initialPrice: 101.80,
    description:
        'Precision machined components supplier whose factory smells of '
        'ambition and cutting fluid. CEO communicates exclusively via '
        'motivational fridge magnets.',
  ),

  // ── Entertainment (2 companies) ──────────────────────────────────────────
  StockSeed(
    ticker: 'MEME',
    companyName: 'MemeStream Studios',
    sector: 'Entertainment',
    initialPrice: 24.60,
    description:
        'Creates interactive narrative games and hosts the MemeStream platform, '
        'a streaming service for content that is '
        '"technically not a movie but feels like one."',
  ),
  StockSeed(
    ticker: 'BLEH',
    companyName: 'BLEH Streaming Inc',
    sector: 'Entertainment',
    initialPrice: 48.20,
    description:
        'Premium streaming service focused on content that viewers finish out '
        'of spite. Most-watched show has a 2-star average and 900 million views.',
  ),
];
