// ─────────────────────────────────────────────────────────────────────────────
// xp_provider.dart
//
// PURPOSE: Manages the player's progression state — XP, trader level,
//          achievements, and insider tips.
//
// XP SOURCES:
//   +5   per trade (any type)
//   +15  for a profitable close (sell or cover with positive P&L)
//   +1   per $10 of profit, capped at +50
//   +20  per gated stock unlocked
//   +3   per day advanced
//   + achievement.xpReward on first unlock
//
// INSIDER TIPS:
//   15% chance each day advance (if player has ever traded and no tip is pending).
//   Tips are flavour only — ~40% are deliberately wrong.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/achievement_definitions.dart';
import '../models/insider_tip.dart';
import '../models/stock.dart';
import '../models/transaction.dart';
import '../providers/portfolio_provider.dart';
import '../services/persistence_service.dart';

// ── Trader level definition ───────────────────────────────────────────────────

class TraderLevel {
  final int level;
  final String title;
  final int xpRequired;

  const TraderLevel({
    required this.level,
    required this.title,
    required this.xpRequired,
  });
}

const List<TraderLevel> kTraderLevels = [
  TraderLevel(level: 1,  title: 'Intern',            xpRequired: 0),
  TraderLevel(level: 2,  title: 'Junior Analyst',     xpRequired: 150),
  TraderLevel(level: 3,  title: 'Analyst',            xpRequired: 400),
  TraderLevel(level: 4,  title: 'Senior Analyst',     xpRequired: 800),
  TraderLevel(level: 5,  title: 'Associate',          xpRequired: 1500),
  TraderLevel(level: 6,  title: 'Vice President',     xpRequired: 2500),
  TraderLevel(level: 7,  title: 'Managing Director',  xpRequired: 4000),
  TraderLevel(level: 8,  title: 'Partner',            xpRequired: 6500),
  TraderLevel(level: 9,  title: 'CIO',                xpRequired: 10000),
  TraderLevel(level: 10, title: 'Hedge Fund God',     xpRequired: 15000),
];

// ── Insider tip content pools ─────────────────────────────────────────────────

const List<String> _kContactNames = [
  'Your uncle Gary',
  'A janitor at the NYSE',
  'Anonymous (definitely not the CEO)',
  'A pigeon with a briefcase',
  'Your dentist (who invests)',
  'A Redditor with 3 karma',
  'The barista who overheard a call',
  'Deep Pockets (identity unknown)',
];

// {ticker} and {company} are replaced at generation time.
const List<String> _kBullishTemplates = [
  'Heard a rumour that {company} is about to land a massive government contract. '
      '{ticker} could pop big. Load up before the news drops.',
  'My guy at the warehouse says {company} shipments are through the roof this week. '
      '{ticker} earnings will be spicy. Just saying.',
  'Word on the street is {company} is getting acquired. '
      'Can\'t say by whom. {ticker}. Think about it.',
  '{company} just quietly hired three ex-NASA engineers. '
      'Something is cooking. {ticker} might be the trade of the year.',
  'A little birdie told me {company}\'s next product announcement will break the internet. '
      '{ticker} is sleeping right now. Not for long.',
];

const List<String> _kBearishTemplates = [
  'I probably shouldn\'t say this but {company}\'s CFO has been updating his LinkedIn. '
      '{ticker} has some rough quarters ahead. Maybe lighten up.',
  'Overheard at a conference: {company}\'s biggest client is switching suppliers. '
      '{ticker} is about to feel it.',
  'Not financial advice, but {ticker} smells like {company}\'s about to miss earnings badly. '
      'I\'d be careful holding this one.',
  'My neighbour works adjacent to {company}. He says morale is "catastrophic." '
      '{ticker} might be due for a correction.',
  '{company} has been quietly cancelling orders from three vendors. '
      'Something is wrong internally. {ticker} could slide hard.',
];

// ── XPProvider ────────────────────────────────────────────────────────────────

class XPProvider extends ChangeNotifier {
  final PersistenceService _persistence;
  final Random _rng = Random();

  int _totalXp = 0;
  Set<String> _unlockedAchievementIds = {};
  List<InsiderTip> _tips = [];
  int _totalTradesAllTime = 0;
  int _tradesToday = 0;
  int _lastTradeDay = -1;

  bool _isLoading = true;

  XPProvider(this._persistence);

  // ── Public getters ────────────────────────────────────────────────────────────

  int get totalXp => _totalXp;
  bool get isLoading => _isLoading;
  int get totalTradesAllTime => _totalTradesAllTime;
  Set<String> get unlockedAchievementIds =>
      Set.unmodifiable(_unlockedAchievementIds);

  /// All tips newest-first, including dismissed ones (for history).
  List<InsiderTip> get allTips => List.unmodifiable(_tips);

  /// Tips that have not been dismissed yet — shown as dialogs.
  List<InsiderTip> get pendingTips =>
      _tips.where((t) => !t.isDismissed).toList();

  /// The highest level whose xpRequired ≤ totalXp.
  TraderLevel get currentLevel {
    TraderLevel result = kTraderLevels.first;
    for (final lvl in kTraderLevels) {
      if (_totalXp >= lvl.xpRequired) result = lvl;
    }
    return result;
  }

  /// The next level, or null if at max.
  TraderLevel? get nextLevel {
    final cur = currentLevel;
    final idx = kTraderLevels.indexWhere((l) => l.level == cur.level);
    if (idx < 0 || idx >= kTraderLevels.length - 1) return null;
    return kTraderLevels[idx + 1];
  }

  /// Progress from currentLevel to nextLevel as a 0.0–1.0 fraction.
  double get levelProgress {
    final cur = currentLevel;
    final next = nextLevel;
    if (next == null) return 1.0;
    final span = next.xpRequired - cur.xpRequired;
    final earned = _totalXp - cur.xpRequired;
    return (earned / span).clamp(0.0, 1.0);
  }

  // ── Initialisation ────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!_isLoading) return;
    final state = await _persistence.loadXpState();
    _totalXp = state.xp;
    _unlockedAchievementIds = state.achievements;
    _tips = state.tips;
    _totalTradesAllTime = state.totalTrades;
    _isLoading = false;
    notifyListeners();
  }

  // ── Trade event ───────────────────────────────────────────────────────────────

  /// Call this immediately after a successful trade is recorded.
  /// Returns the XP gained and a list of newly unlocked achievement IDs
  /// so the caller can show snackbars.
  ({int xpGained, List<String> newAchievements}) onTrade({
    required TransactionType type,
    required int shares,
    required double price,
    required double? profitOnThisTrade,
    required Stock stock,
    required PortfolioProvider portfolio,
    required List<Stock> stocks,
    required int currentDay,
  }) {
    // Reset today's trade counter when the day changes.
    if (currentDay != _lastTradeDay) {
      _tradesToday = 0;
      _lastTradeDay = currentDay;
    }

    _totalTradesAllTime++;
    _tradesToday++;

    int xp = 5; // base per trade

    // Profitable close bonus.
    if (profitOnThisTrade != null && profitOnThisTrade > 0) {
      xp += 15;
      xp += min(50, (profitOnThisTrade / 10).floor());
    }

    final newAchievements = _checkAchievements(
      type: type,
      shares: shares,
      price: price,
      profitOnThisTrade: profitOnThisTrade,
      stock: stock,
      portfolio: portfolio,
      stocks: stocks,
      currentDay: currentDay,
    );

    // Award achievement XP.
    for (final id in newAchievements) {
      final def = kAchievements.firstWhere((a) => a.id == id,
          orElse: () => const AchievementDef(
              id: '', name: '', description: '', emoji: '', xpReward: 0));
      xp += def.xpReward;
    }

    _totalXp += xp;
    _persist();
    notifyListeners();
    return (xpGained: xp, newAchievements: newAchievements);
  }

  // ── Day advance event ─────────────────────────────────────────────────────────

  /// Call this after advanceDay() completes.
  /// Returns XP gained, new achievements, and an optional insider tip.
  ({int xpGained, List<String> newAchievements, InsiderTip? newTip})
      onDayAdvanced({
    required int day,
    required List<Stock> stocks,
    required PortfolioProvider portfolio,
  }) {
    // Reset today's trade counter for the new day.
    _tradesToday = 0;

    int xp = 3; // base per day

    final newAchievements = _checkAchievements(
      type: null,
      shares: 0,
      price: 0,
      profitOnThisTrade: null,
      stock: null,
      portfolio: portfolio,
      stocks: stocks,
      currentDay: day,
    );

    for (final id in newAchievements) {
      final def = kAchievements.firstWhere((a) => a.id == id,
          orElse: () => const AchievementDef(
              id: '', name: '', description: '', emoji: '', xpReward: 0));
      xp += def.xpReward;
    }

    _totalXp += xp;

    // Try to generate an insider tip.
    InsiderTip? newTip;
    if (_totalTradesAllTime > 0 &&
        pendingTips.isEmpty &&
        _rng.nextDouble() < 0.15) {
      newTip = _generateTip(stocks, portfolio, day);
      if (newTip != null) _tips = [newTip, ..._tips];
    }

    _persist();
    notifyListeners();
    return (xpGained: xp, newAchievements: newAchievements, newTip: newTip);
  }

  // ── Stock unlock event ────────────────────────────────────────────────────────

  /// Call once per newly unlocked stock ticker.
  ({int xpGained, List<String> newAchievements}) onStockUnlocked(
      String ticker) {
    int xp = 20;

    final newAchievements = <String>[];
    if (!_unlockedAchievementIds.contains('insider_club')) {
      _unlockedAchievementIds.add('insider_club');
      newAchievements.add('insider_club');
      final def = kAchievements.firstWhere((a) => a.id == 'insider_club',
          orElse: () => const AchievementDef(
              id: '', name: '', description: '', emoji: '', xpReward: 0));
      xp += def.xpReward;
    }

    _totalXp += xp;
    _persist();
    notifyListeners();
    return (xpGained: xp, newAchievements: newAchievements);
  }

  // ── Tip dismissal ─────────────────────────────────────────────────────────────

  void dismissTip(String tipId) {
    _tips = _tips.map((t) => t.id == tipId ? t.copyWith(isDismissed: true) : t).toList();
    _persist();
    notifyListeners();
  }

  // ── Reset ─────────────────────────────────────────────────────────────────────

  void reset() {
    _totalXp = 0;
    _unlockedAchievementIds = {};
    _tips = [];
    _totalTradesAllTime = 0;
    _tradesToday = 0;
    _lastTradeDay = -1;
    notifyListeners();
    // clearAll() on PersistenceService is called by MarketProvider.resetSimulation().
  }

  // ── Private: achievement checker ──────────────────────────────────────────────

  /// Evaluates which achievements have been newly earned.
  /// [type], [stock], [profitOnThisTrade] are null when called from onDayAdvanced.
  List<String> _checkAchievements({
    required TransactionType? type,
    required int shares,
    required double price,
    required double? profitOnThisTrade,
    required Stock? stock,
    required PortfolioProvider portfolio,
    required List<Stock> stocks,
    required int currentDay,
  }) {
    final gained = <String>[];

    void tryUnlock(String id, bool condition) {
      if (condition && !_unlockedAchievementIds.contains(id)) {
        _unlockedAchievementIds.add(id);
        gained.add(id);
      }
    }

    // Trade-triggered achievements.
    if (type != null) {
      tryUnlock('first_trade', _totalTradesAllTime >= 1);
      tryUnlock('bear_hunter', type == TransactionType.short);
      tryUnlock('high_roller', shares * price >= 100);
      tryUnlock(
        'first_profit',
        (type == TransactionType.sell) &&
            profitOnThisTrade != null &&
            profitOnThisTrade > 0,
      );
      tryUnlock(
        'short_profit',
        type == TransactionType.cover &&
            profitOnThisTrade != null &&
            profitOnThisTrade > 0,
      );
      tryUnlock(
        'contrarian',
        type == TransactionType.buy &&
            stock != null &&
            stock.changePercent <= -5.0,
      );
      tryUnlock(
        'trend_rider',
        type == TransactionType.buy && stock != null && stock.isInUptrend,
      );
      tryUnlock('day_trader', _tradesToday >= 5);
    }

    // Portfolio composition achievements (checked on every trade and day advance).
    final sectors =
        portfolio.holdings.map((h) {
          final s = stocks.firstWhere(
            (st) => st.ticker == h.ticker,
            orElse: () => stocks.first,
          );
          return s.sector;
        }).toSet();
    tryUnlock('diversified', sectors.length >= 3);
    tryUnlock('bull_5', portfolio.holdings.length >= 5);

    // Portfolio value milestones.
    final pv = portfolio.totalPortfolioValue(stocks);
    tryUnlock('portfolio_750', pv >= 750);
    tryUnlock('portfolio_1000', pv >= 1000);
    tryUnlock('portfolio_2500', pv >= 2500);

    // Day-based achievements.
    tryUnlock('market_veteran', currentDay >= 30);

    // Level-based achievement (checks current XP + any just earned).
    // We check after adding xp in onTrade/onDayAdvanced so we use the pre-add
    // value here; the level check will re-run next notification. To avoid a
    // one-cycle delay we peek at the prospective level.
    tryUnlock('analyst_rank', currentLevel.level >= 3);

    return gained;
  }

  // ── Private: insider tip generator ───────────────────────────────────────────

  InsiderTip? _generateTip(
      List<Stock> stocks, PortfolioProvider portfolio, int day) {
    // Only pick from unlocked stocks so the tip is actionable.
    final available = stocks
        .where((s) => portfolio.isStockUnlocked(s.ticker))
        .toList();
    if (available.isEmpty) return null;

    final stock = available[_rng.nextInt(available.length)];
    final bullish = _rng.nextBool();
    final templates = bullish ? _kBullishTemplates : _kBearishTemplates;
    final template = templates[_rng.nextInt(templates.length)];
    final body = template
        .replaceAll('{ticker}', stock.ticker)
        .replaceAll('{company}', stock.companyName);
    final contact = _kContactNames[_rng.nextInt(_kContactNames.length)];
    final id = '${stock.ticker}_${DateTime.now().millisecondsSinceEpoch}';

    return InsiderTip(
      id: id,
      ticker: stock.ticker,
      companyName: stock.companyName,
      contactName: contact,
      body: body,
      bullish: bullish,
      receivedAt: DateTime.now(),
    );
  }

  // ── Private: persistence ──────────────────────────────────────────────────────

  void _persist() {
    _persistence.saveXpState(
      xp: _totalXp,
      achievements: _unlockedAchievementIds,
      tips: _tips,
      totalTrades: _totalTradesAllTime,
    );
  }
}
