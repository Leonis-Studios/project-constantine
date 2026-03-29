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

  const StockSeed({
    required this.ticker,
    required this.companyName,
    required this.sector,
    required this.initialPrice,
    required this.description,
  });

  /// Converts this seed into a fully initialised Stock object.
  /// previousPrice is set equal to initialPrice (no change on day 0).
  /// priceHistory starts with just the initial price as the first data point.
  Stock toStock() {
    return Stock(
      ticker: ticker,
      companyName: companyName,
      sector: sector,
      description: description,
      currentPrice: initialPrice,
      previousPrice: initialPrice, // no change yet on day 0
      priceHistory: [initialPrice], // chart starts with a single point
    );
  }
}

// ── Seed data ─────────────────────────────────────────────────────────────────

const List<StockSeed> kStockDefinitions = [

  // ── Technology (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'NXCO',
    companyName: 'Nexacor Industries',
    sector: 'Technology',
    initialPrice: 142.50,
    description:
        'Nexacor develops orbital computing infrastructure and sells '
        'bandwidth to commercial satellites.',
  ),
  StockSeed(
    ticker: 'PLVT',
    companyName: 'Polyvant Systems',
    sector: 'Technology',
    initialPrice: 87.20,
    description:
        'Polyvant builds enterprise AI platforms for supply-chain '
        'logistics and predictive inventory management.',
  ),
  StockSeed(
    ticker: 'DRYX',
    companyName: 'Dryxon Corp',
    sector: 'Technology',
    initialPrice: 234.00,
    description:
        'Dryxon manufactures quantum-resistant encryption chips used '
        'in government and financial networks worldwide.',
  ),

  // ── Energy (3 companies) ─────────────────────────────────────────────────
  StockSeed(
    ticker: 'VELM',
    companyName: 'Velmont Energy',
    sector: 'Energy',
    initialPrice: 61.40,
    description:
        'Velmont operates offshore wind farms and sells electricity '
        'directly to grid operators across the eastern seaboard.',
  ),
  StockSeed(
    ticker: 'ORXP',
    companyName: 'Orexpa Petroleum',
    sector: 'Energy',
    initialPrice: 44.80,
    description:
        'Orexpa is a mid-size oil exploration company with active '
        'drilling contracts in the Gulf of Marenco.',
  ),
  StockSeed(
    ticker: 'ZYNF',
    companyName: 'Zynfuel Renewables',
    sector: 'Energy',
    initialPrice: 29.15,
    description:
        'Zynfuel produces hydrogen fuel cells for heavy industrial '
        'equipment and long-haul freight vehicles.',
  ),

  // ── Healthcare (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'MERD',
    companyName: 'Meridian Pharma',
    sector: 'Healthcare',
    initialPrice: 178.90,
    description:
        'Meridian Pharma is developing a next-generation mRNA platform '
        'targeting autoimmune conditions with two drugs in Phase III trials.',
  ),
  StockSeed(
    ticker: 'BXHL',
    companyName: 'Bioxel Health',
    sector: 'Healthcare',
    initialPrice: 93.60,
    description:
        'Bioxel manufactures biosensor wearables for continuous glucose '
        'and cardiac monitoring sold through hospitals and pharmacies.',
  ),
  StockSeed(
    ticker: 'CRVO',
    companyName: 'Corvona Biotech',
    sector: 'Healthcare',
    initialPrice: 52.30,
    description:
        'Corvona is a clinical-stage biotech pursuing CRISPR gene-editing '
        'therapies for rare hereditary blood disorders.',
  ),

  // ── Finance (3 companies) ────────────────────────────────────────────────
  StockSeed(
    ticker: 'FNVX',
    companyName: 'Finvex Capital',
    sector: 'Finance',
    initialPrice: 118.75,
    description:
        'Finvex is an algorithmic trading firm that manages quant funds '
        'specialising in commodity derivatives.',
  ),
  StockSeed(
    ticker: 'GRLD',
    companyName: 'Greyhold Banking',
    sector: 'Finance',
    initialPrice: 76.20,
    description:
        'Greyhold is a mid-size retail bank with strong commercial '
        'lending operations in the industrial midwest.',
  ),
  StockSeed(
    ticker: 'VSTK',
    companyName: 'Vaultstock Inc',
    sector: 'Finance',
    initialPrice: 204.40,
    description:
        'Vaultstock provides digital asset custody and settlement '
        'infrastructure for institutional investors.',
  ),

  // ── Consumer (3 companies) ───────────────────────────────────────────────
  StockSeed(
    ticker: 'KLMR',
    companyName: 'Kalomar Retail',
    sector: 'Consumer',
    initialPrice: 38.90,
    description:
        'Kalomar operates a chain of 400 discount retail stores and '
        'is expanding its private-label grocery brand.',
  ),
  StockSeed(
    ticker: 'PRXN',
    companyName: 'Proxon Foods',
    sector: 'Consumer',
    initialPrice: 57.60,
    description:
        'Proxon is a packaged foods conglomerate known for its '
        'Apex snack and Grandia frozen meal product lines.',
  ),
  StockSeed(
    ticker: 'TMVL',
    companyName: 'Timovel Goods',
    sector: 'Consumer',
    initialPrice: 83.10,
    description:
        'Timovel designs and sells premium home goods and appliances '
        'with a strong direct-to-consumer online channel.',
  ),

  // ── Industrial (3 companies) ─────────────────────────────────────────────
  StockSeed(
    ticker: 'AEVR',
    companyName: 'Aevros Aerospace',
    sector: 'Industrial',
    initialPrice: 312.00,
    description:
        'Aevros builds propulsion systems for medium-lift rockets '
        'and holds multi-year contracts with two national space agencies.',
  ),
  StockSeed(
    ticker: 'CMTX',
    companyName: 'Cometix Logistics',
    sector: 'Industrial',
    initialPrice: 69.45,
    description:
        'Cometix operates an automated warehouse and last-mile delivery '
        'network serving e-commerce clients across 30 metro areas.',
  ),
  StockSeed(
    ticker: 'ZNTH',
    companyName: 'Zenith Manufacturing',
    sector: 'Industrial',
    initialPrice: 101.80,
    description:
        'Zenith produces precision machined components for aerospace, '
        'defence, and heavy-equipment OEMs.',
  ),

  // ── Entertainment (2 companies) ──────────────────────────────────────────
  StockSeed(
    ticker: 'QDRN',
    companyName: 'Quadron Media',
    sector: 'Entertainment',
    initialPrice: 24.60,
    description:
        'Quadron creates interactive narrative games and has a rapidly '
        'growing subscription gaming platform with 8 million subscribers.',
  ),
  StockSeed(
    ticker: 'BLVD',
    companyName: 'Boulevard Streaming',
    sector: 'Entertainment',
    initialPrice: 48.20,
    description:
        'Boulevard is a streaming service focused on documentary and '
        'independent film content, competing against major platforms.',
  ),
];
