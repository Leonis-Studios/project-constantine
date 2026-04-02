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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ability_provider.dart';
import 'providers/market_provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/xp_provider.dart';
import 'services/persistence_service.dart';
import 'systems/abilities/ability.dart';
import 'systems/abilities/ability_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'widgets/abilities/ability_unlock_toast.dart';

Future<void> main() async {
  // Must be called before any async work in main() because it initialises the
  // Flutter engine bindings that shared_preferences depends on.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the persistence layer — this opens shared_preferences so it
  // is ready when the providers call their load methods.
  final persistence = PersistenceService();
  await persistence.init();

  // Create the ability service and load its persisted state.
  // The service is shared between MarketProvider and PortfolioProvider.
  final abilityService = AbilityService();
  await abilityService.loadState(persistence);

  // Build providers, then wire the ability service into both.
  final marketProvider = MarketProvider(persistence);
  final portfolioProvider = PortfolioProvider(persistence);
  marketProvider.attachAbilityService(abilityService);
  portfolioProvider.attachAbilityService(abilityService);

  // AbilityProvider wraps the same service instance for widget-tree access.
  final abilityProvider = AbilityProvider(abilityService);

  runApp(
    MultiProvider(
      providers: [
        // MarketProvider owns all stock and event state.
        ChangeNotifierProvider.value(value: marketProvider),
        // PortfolioProvider owns cash, holdings, and transaction history.
        ChangeNotifierProvider.value(value: portfolioProvider),
        // AbilityProvider exposes ability state (equipped, bench, cooldowns).
        ChangeNotifierProvider.value(value: abilityProvider),
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
      // home: const DesignPreviewScreen(),
      home: const _AppRoot(),
    );
  }
}

// ── App root listener ─────────────────────────────────────────────────────────
// Subscribes to AbilityService's unlock stream at the widget-tree root so any
// screen can trigger a toast without needing its own listener.

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  StreamSubscription<Ability>? _unlockSub;

  @override
  void initState() {
    super.initState();
    // Wait one frame so context.read<AbilityProvider>() is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _unlockSub = context.read<AbilityProvider>().unlockStream.listen(
        (ability) {
          if (mounted) AbilityUnlockToast.show(context, ability);
        },
      );
    });
  }

  @override
  void dispose() {
    _unlockSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
