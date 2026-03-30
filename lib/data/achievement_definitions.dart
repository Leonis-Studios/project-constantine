// ─────────────────────────────────────────────────────────────────────────────
// achievement_definitions.dart
//
// PURPOSE: Static definitions for every achievement in the game. The XPProvider
//          checks these IDs when deciding what to unlock. Adding a new
//          achievement requires: (1) a new entry here, (2) a check case in
//          XPProvider._checkAchievements().
// ─────────────────────────────────────────────────────────────────────────────

class AchievementDef {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final int xpReward;

  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.xpReward,
  });
}

const List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'first_trade',
    name: 'First Steps',
    emoji: '📈',
    xpReward: 50,
    description: 'Complete your first trade.',
  ),
  AchievementDef(
    id: 'first_profit',
    name: 'In The Black',
    emoji: '💰',
    xpReward: 75,
    description: 'Close a position at a profit.',
  ),
  AchievementDef(
    id: 'bear_hunter',
    name: 'Bear Hunter',
    emoji: '🐻',
    xpReward: 75,
    description: 'Open your first short position.',
  ),
  AchievementDef(
    id: 'short_profit',
    name: 'Short Squeeze',
    emoji: '🎯',
    xpReward: 100,
    description: 'Profit from covering a short.',
  ),
  AchievementDef(
    id: 'diversified',
    name: 'Diversified',
    emoji: '🌐',
    xpReward: 100,
    description: 'Hold stocks in 3+ different sectors at once.',
  ),
  AchievementDef(
    id: 'bull_5',
    name: 'Portfolio Zoo',
    emoji: '🦁',
    xpReward: 75,
    description: 'Own 5 different stocks simultaneously.',
  ),
  AchievementDef(
    id: 'high_roller',
    name: 'High Roller',
    emoji: '🎰',
    xpReward: 50,
    description: 'Execute a single trade worth \$100+.',
  ),
  AchievementDef(
    id: 'insider_club',
    name: 'Insider Club',
    emoji: '🔓',
    xpReward: 150,
    description: 'Unlock your first gated stock.',
  ),
  AchievementDef(
    id: 'portfolio_750',
    name: 'Getting Started',
    emoji: '💼',
    xpReward: 50,
    description: 'Reach \$750 total portfolio value.',
  ),
  AchievementDef(
    id: 'portfolio_1000',
    name: 'Four Figures',
    emoji: '🏦',
    xpReward: 100,
    description: 'Reach \$1,000 total portfolio value.',
  ),
  AchievementDef(
    id: 'portfolio_2500',
    name: 'Serious Money',
    emoji: '🚀',
    xpReward: 150,
    description: 'Reach \$2,500 total portfolio value.',
  ),
  AchievementDef(
    id: 'day_trader',
    name: 'Day Trader',
    emoji: '⚡',
    xpReward: 100,
    description: 'Make 5+ trades in a single day.',
  ),
  AchievementDef(
    id: 'market_veteran',
    name: 'Market Veteran',
    emoji: '🎖️',
    xpReward: 150,
    description: 'Advance to Day 30.',
  ),
  AchievementDef(
    id: 'contrarian',
    name: 'Contrarian',
    emoji: '🔄',
    xpReward: 100,
    description: 'Buy a stock that dropped 5%+ that day.',
  ),
  AchievementDef(
    id: 'trend_rider',
    name: 'Trend Rider',
    emoji: '🌊',
    xpReward: 75,
    description: 'Buy a stock while it\'s in an uptrend.',
  ),
  AchievementDef(
    id: 'analyst_rank',
    name: 'Moving Up',
    emoji: '🏆',
    xpReward: 0,
    description: 'Reach Analyst level (Level 3).',
  ),
];
