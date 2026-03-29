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

import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';
import 'market_overview_screen.dart';
import 'portfolio_screen.dart';
import 'events_log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Tracks which tab is currently shown (0 = Market, 1 = Portfolio, 2 = Events).
  int _selectedIndex = 0;

  // The three main screens — built once and kept alive as the user switches tabs.
  // Using a list here so we can index by _selectedIndex.
  static const List<Widget> _screens = [
    MarketOverviewScreen(),
    PortfolioScreen(),
    EventsLogScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Trigger both providers to load their state from disk.
    // We use addPostFrameCallback so the providers are fully wired into the
    // widget tree before we call methods on them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketProvider>().initialize();
      context.read<PortfolioProvider>().initialize();
    });
  }

  // Handles bottom nav bar taps.
  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
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
                onPressed: () => context.read<MarketProvider>().advanceDay(),
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
        ],
      ),
    );
  }
}
