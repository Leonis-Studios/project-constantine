// ─────────────────────────────────────────────────────────────────────────────
// ability_equip_button.dart  (lib/widgets/abilities/)
//
// PURPOSE: Equip / swap button for a single Ability. Handles three states:
//   1. Already equipped      → disabled "Equipped" button
//   2. Slot empty            → "Equip" button (free, no dialog)
//   3. Slot occupied by other → "Swap (500)" button with canSwap pre-check,
//                               SnackBar on block, confirmation dialog on allow
//
// REACTIVITY: Wraps its content in a ValueListenableBuilder over
//   AbilityService.stateVersion so the button rebuilds automatically whenever
//   equip/swap state changes — no Provider.watch or StatefulWidget needed.
//
// CASH DEDUCTION: On confirmed swap, calls PortfolioProvider.spendCash() from
//   context (the service records the swap; the provider deducts the coins).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ability_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../systems/abilities/ability.dart';
import '../../systems/abilities/ability_service.dart';

class AbilityEquipButton extends StatelessWidget {
  const AbilityEquipButton({
    super.key,
    required this.ability,
    required this.abilityService,
  });

  final Ability ability;
  final AbilityService abilityService;

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever equip/swap state changes inside AbilityService.
    return ValueListenableBuilder<int>(
      valueListenable: abilityService.stateVersion,
      builder: (context, _, __) {
        final equipped = abilityService.equippedAbility(ability.slot);
        final isEquipped = equipped?.id == ability.id;
        final slotOccupied = equipped != null && !isEquipped;

        if (isEquipped) {
          return const _EquippedButton();
        }
        if (slotOccupied) {
          return _SwapButton(
            ability: ability,
            abilityService: abilityService,
          );
        }
        return _EquipButton(
          ability: ability,
          abilityService: abilityService,
        );
      },
    );
  }
}

// ── Equipped (disabled) ───────────────────────────────────────────────────────

class _EquippedButton extends StatelessWidget {
  const _EquippedButton();

  @override
  Widget build(BuildContext context) {
    return const OutlinedButton(
      onPressed: null, // disabled
      child: Text('Equipped'),
    );
  }
}

// ── Free equip ────────────────────────────────────────────────────────────────

class _EquipButton extends StatelessWidget {
  const _EquipButton({
    required this.ability,
    required this.abilityService,
  });

  final Ability ability;
  final AbilityService abilityService;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _onEquip(context),
      child: const Text('Equip'),
    );
  }

  void _onEquip(BuildContext context) {
    // Free equip — no cash needed (cashBalance only matters for swaps).
    final err = abilityService.equipAbility(
      ability.id,
      cashBalance: double.infinity,
    );
    if (err != null) {
      _showSnackBar(context, err);
      return;
    }
    // Propagate change to AbilityProvider watchers (e.g. AbilityPanel).
    context.read<AbilityProvider>().refresh();
  }
}

// ── Swap (costs 500 coins) ────────────────────────────────────────────────────

class _SwapButton extends StatelessWidget {
  const _SwapButton({
    required this.ability,
    required this.abilityService,
  });

  final Ability ability;
  final AbilityService abilityService;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () => _onSwapTapped(context),
      child: Text('Swap (\$${kSwapCostCurrency.toStringAsFixed(0)})'),
    );
  }

  void _onSwapTapped(BuildContext context) {
    final cash = context.read<PortfolioProvider>().cashBalance;
    final result = abilityService.canSwap(ability.id, cashBalance: cash);

    if (!result.allowed) {
      _showSnackBar(context, result.reason ?? 'Cannot swap right now.');
      return;
    }

    _showConfirmDialog(context, cash);
  }

  Future<void> _showConfirmDialog(BuildContext context, double cash) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Swap Ability'),
        content: Text(
          'Swap costs \$${kSwapCostCurrency.toStringAsFixed(0)} coins and '
          'locks this slot for ${kSwapCooldownHours}h. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    _performSwap(context, cash);
  }

  void _performSwap(BuildContext context, double cash) {
    final err = abilityService.swapAbility(ability.id, cashBalance: cash);
    if (err != null) {
      // Rare: state changed between canSwap and confirm (e.g. another swap).
      _showSnackBar(context, err);
      return;
    }

    // Deduct the swap cost from the portfolio's cash balance.
    context.read<PortfolioProvider>().spendCash(kSwapCostCurrency);

    // Propagate change to AbilityProvider watchers (e.g. AbilityPanel).
    context.read<AbilityProvider>().refresh();
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
