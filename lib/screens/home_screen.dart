// ─────────────────────────────────────────────────────────────────────────────
// home_screen.dart
//
// PURPOSE: The root Scaffold. Hosts the BottomNavigationBar that switches
//          between the four main sections of the app. Also triggers both
//          providers to load their data from disk on first build.
//
// TABS:
//   0 — Market Overview  (stock list, sorted by movers)
//   1 — Portfolio        (holdings + transaction history)
//   2 — Events Log       (news feed of all fired market events)
//
// AppBar:
//   • Title: "Day {currentDay}" — updates with every Next Day press
//   • "Next Day" button — triggers MarketProvider.advanceDay()
//   • Play/Pause icon   — toggles MarketProvider auto-advance timer
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievement_definitions.dart';
import '../models/insider_tip.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/xp_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/insider_tip_dialog.dart';
import 'market_overview_screen.dart';
import 'portfolio_screen.dart';
import 'events_log_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tracks which tab is currently shown (0 = Market, 1 = Portfolio, 2 = Events).
  int _selectedIndex = 0;

  // The four main screens — built once and kept alive as the user switches tabs.
  static const List<Widget> _screens = [
    MarketOverviewScreen(),
    PortfolioScreen(),
    EventsLogScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Trigger both providers to load their state from disk.
    // We use addPostFrameCallback so the providers are fully wired into the
    // widget tree before we call methods on them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final market = context.read<MarketProvider>();
      final portfolio = context.read<PortfolioProvider>();
      final xp = context.read<XPProvider>();
      market.initialize();
      portfolio.initialize();
      xp.initialize();
      // Wire the portfolio so advanceDay() can trigger unlock checks
      // when prices move without any player trade.
      market.attachPortfolio(portfolio);
    });
  }

  // Handles bottom nav bar taps.
  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  /// Advances the day then fires all notifications: unlocks, XP, achievements,
  /// level-ups, and any generated insider tip.
  Future<void> _advanceDayAndNotify(BuildContext context) async {
    final market = context.read<MarketProvider>();
    final portfolio = context.read<PortfolioProvider>();
    final xp = context.read<XPProvider>();

    final levelBefore = xp.currentLevel.level;

    await market.advanceDay();
    if (!context.mounted) return;

    // Stock unlock snackbars + XP.
    for (final ticker in market.recentlyUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔓 $ticker is now unlocked! You can now invest in it.'),
          backgroundColor: AppTheme.accent,
          duration: const Duration(seconds: 3),
        ),
      );
      final unlockResult = xp.onStockUnlocked(ticker);
      if (!context.mounted) return;
      _showAchievementSnackbars(context, unlockResult.newAchievements, xp);
    }

    // Day advance XP + achievements + tip.
    final dayResult = xp.onDayAdvanced(
      day: market.currentDay,
      stocks: market.stocks,
      portfolio: portfolio,
    );
    if (!context.mounted) return;

    _showAchievementSnackbars(context, dayResult.newAchievements, xp);

    // Level-up notification.
    if (xp.currentLevel.level > levelBefore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🏆 Level up! You are now a ${xp.currentLevel.title}.',
          ),
          backgroundColor: const Color(0xFFE3B341), // amber
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // Insider tip dialog.
    if (dayResult.newTip != null && context.mounted) {
      _showInsiderTipDialog(context, dayResult.newTip!);
    }
  }

  /// Shows a snackbar for each newly unlocked achievement.
  void _showAchievementSnackbars(
      BuildContext context, List<String> ids, XPProvider xp) {
    if (!context.mounted) return;
    for (final id in ids) {
      final def = kAchievements.firstWhere(
        (a) => a.id == id,
        orElse: () => const AchievementDef(
            id: '', name: '', emoji: '', description: '', xpReward: 0),
      );
      if (def.id.isEmpty) continue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${def.emoji} Achievement unlocked: ${def.name}'),
          backgroundColor: AppTheme.surface,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Shows the insider tip modal dialog.
  void _showInsiderTipDialog(BuildContext context, InsiderTip tip) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InsiderTipDialog(
        tip: tip,
        onDismiss: () {
          context.read<XPProvider>().dismissTip(tip.id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the market provider so AppBar updates when the day changes.
    final market = context.watch<MarketProvider>();

    return Scaffold(
      // ── AppBar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        // Show the current simulated day prominently.
        title: Text(
          market.isLoading ? 'Loading...' : 'Day ${market.currentDay}',
          style: AppTheme.headline,
        ),
        actions: [
          // Auto-advance toggle — play icon starts it, pause icon stops it.
          if (!market.isLoading)
            IconButton(
              icon: Icon(
                market.isAutoAdvancing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: market.isAutoAdvancing
                    ? AppTheme.positive
                    : AppTheme.textSecondary,
                size: 28,
              ),
              tooltip: market.isAutoAdvancing
                  ? 'Pause auto-advance'
                  : 'Auto-advance (every 3s)',
              onPressed: () => context.read<MarketProvider>().toggleAutoAdvance(),
            ),
          // Manual "Next Day" button.
          if (!market.isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.skip_next, size: 18),
                label: const Text('Next Day'),
                onPressed: () => _advanceDayAndNotify(context),
              ),
            ),
        ],
      ),

      // ── Body ───────────────────────────────────────────────────────────────
      body: market.isLoading
          // Show a spinner while both providers are initialising from disk.
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading market data...'),
                ],
              ),
            )
          // Once loaded, show the currently selected tab's screen.
          : _screens[_selectedIndex],

      // ── Bottom Navigation Bar ───────────────────────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Market',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed_outlined),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
