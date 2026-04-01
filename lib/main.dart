// ─────────────────────────────────────────────────────────────────────────────
// main.dart
//
// PURPOSE: Application entry point. Sets up dependency injection, wires
//          providers into the widget tree, and launches the app.
//
// STARTUP SEQUENCE:
//   1. WidgetsFlutterBinding.ensureInitialized() — required before any async
//      work in main() so Flutter's engine is ready.
//   2. PersistenceService.init() — opens the shared_preferences instance so
//      providers can read/write to disk as soon as they're created.
//   3. MultiProvider wraps the widget tree — MarketProvider and PortfolioProvider
//      are available to every widget below via context.watch / context.read.
//   4. HomeScreen triggers initialize() on both providers in its initState().
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/market_provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/xp_provider.dart';
import 'services/persistence_service.dart';
import 'theme/app_theme.dart';
import 'design_preview.dart';

Future<void> main() async {
  // Must be called before any async work in main() because it initialises the
  // Flutter engine bindings that shared_preferences depends on.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the persistence layer — this opens shared_preferences so it
  // is ready when the providers call their load methods.
  final persistence = PersistenceService();
  await persistence.init();

  runApp(
    // MultiProvider injects both providers at the root of the widget tree.
    // Order matters if providers depend on each other — here they're independent
    // so order is arbitrary.
    MultiProvider(
      providers: [
        // MarketProvider owns all stock and event state.
        ChangeNotifierProvider(
          create: (_) => MarketProvider(persistence),
        ),
        // PortfolioProvider owns cash, holdings, and transaction history.
        ChangeNotifierProvider(
          create: (_) => PortfolioProvider(persistence),
        ),
        // XPProvider owns progression state: XP, levels, achievements, tips.
        ChangeNotifierProvider(
          create: (_) => XPProvider(persistence),
        ),
      ],
      child: const StockSimulatorApp(),
    ),
  );
}

// ── StockSimulatorApp ─────────────────────────────────────────────────────────
//
// The root widget. Only responsible for configuring MaterialApp — no business
// logic here. All navigation starts from HomeScreen.

class StockSimulatorApp extends StatelessWidget {
  const StockSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Simulator',

      // Use our custom dark theme defined in theme/app_theme.dart.
      theme: AppTheme.buildTheme(),

      // Hides the debug banner in the top-right corner.
      debugShowCheckedModeBanner: false,

      // HomeScreen is the root — it manages the BottomNavigationBar and
      // triggers the provider initialize() calls.
      home: const DesignPreviewScreen(),
      // home: const HomeScreen(),
    );
  }
}
