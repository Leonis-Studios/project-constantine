// ─────────────────────────────────────────────────────────────────────────────
// profile_screen.dart
//
// PURPOSE: The player's public profile — shows trader level, XP progress,
//          lifetime stats, and the full achievement grid (unlocked / locked).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/achievement_definitions.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/xp_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final xp = context.watch<XPProvider>();
    final portfolio = context.watch<PortfolioProvider>();
    final market = context.watch<MarketProvider>();

    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final level = xp.currentLevel;
    final next = xp.nextLevel;
    final totalValue = portfolio.totalPortfolioValue(market.stocks);
    final realizedPnl = totalValue -
        PortfolioProvider.kStartingCash -
        portfolio.totalUnrealizedPnl(market.stocks);
    final unlockedCount =
        xp.unlockedAchievementIds.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Level card ────────────────────────────────────────────────────────
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    border: Border.all(color: AppTheme.accent, width: 2),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 40,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 12),

                // Level title
                Text(level.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                Text(
                  'Level ${level.level}',
                  style: AppTheme.label,
                ),

                const SizedBox(height: 16),

                // XP progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xp.levelProgress,
                    minHeight: 8,
                    backgroundColor: AppTheme.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${xp.totalXp} XP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    Text(
                      next != null
                          ? '${next.xpRequired} XP → ${next.title}'
                          : 'Max Level',
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Stats card ────────────────────────────────────────────────────────
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STATS', style: _kSectionHeader),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: 'Total Trades',
                        value: '${xp.totalTradesAllTime}',
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Days',
                        value: '${market.currentDay}',
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Portfolio',
                        value: currencyFormat.format(totalValue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: 'Realised P&L',
                        value:
                            '${realizedPnl >= 0 ? '+' : ''}${currencyFormat.format(realizedPnl)}',
                        valueColor: realizedPnl >= 0
                            ? AppTheme.positive
                            : AppTheme.negative,
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Buying Power',
                        value: currencyFormat.format(portfolio.cashBalance),
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Holdings',
                        value: '${portfolio.holdings.length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Achievements grid ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              const Text('ACHIEVEMENTS', style: _kSectionHeader),
              const SizedBox(width: 8),
              Text(
                '$unlockedCount / ${kAchievements.length}',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kAchievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemBuilder: (context, index) {
              final achievement = kAchievements[index];
              final isUnlocked =
                  xp.unlockedAchievementIds.contains(achievement.id);
              return _AchievementCell(
                achievement: achievement,
                isUnlocked: isUnlocked,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Section header text style ─────────────────────────────────────────────────

const TextStyle _kSectionHeader = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: AppTheme.textMuted,
  letterSpacing: 1.2,
);

// ── Stat cell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Achievement cell ──────────────────────────────────────────────────────────

class _AchievementCell extends StatelessWidget {
  final AchievementDef achievement;
  final bool isUnlocked;

  const _AchievementCell(
      {required this.achievement, required this.isUnlocked});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.38,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(
            color: isUnlocked ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Text(achievement.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          achievement.name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnlocked) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.check_circle,
                            size: 11, color: AppTheme.positive),
                      ],
                    ],
                  ),
                  Text(
                    achievement.description,
                    style: AppTheme.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
