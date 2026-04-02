// ─────────────────────────────────────────────────────────────────────────────
// ability_panel.dart  (lib/widgets/abilities/)
//
// PURPOSE: Self-contained panel that shows the player's 3 ability slots and
//          all unlocked, unequipped abilities. Drop it into any screen with
//          no constructor arguments or local setup required.
//
// STATE: Read entirely from AbilityProvider and PortfolioProvider via
//        context.watch — no local state management needed.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ability_provider.dart';
import '../../providers/portfolio_provider.dart';
import '../../systems/abilities/ability.dart';
import '../../systems/abilities/ability_service.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

/// Displays the player's 3 ability slots and their unlocked ability bench.
///
/// Self-contained: reads all state from [AbilityProvider] and
/// [PortfolioProvider]. No arguments needed.
class AbilityPanel extends StatelessWidget {
  const AbilityPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch both providers so the panel rebuilds on any relevant change.
    final abilities = context.watch<AbilityProvider>();
    final cash = context.watch<PortfolioProvider>().cashBalance;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Equipped slot sections ─────────────────────────────────────────
          for (final slot in AbilitySlot.values) ...[
            _SlotSection(slot: slot, abilities: abilities, cash: cash),
            const SizedBox(height: 16),
          ],

          // ── Bench: unlocked, unequipped abilities ──────────────────────────
          _BenchSection(abilities: abilities, cash: cash),
        ],
      ),
    );
  }
}

// ── Slot section ──────────────────────────────────────────────────────────────

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slot,
    required this.abilities,
    required this.cash,
  });

  final AbilitySlot slot;
  final AbilityProvider abilities;
  final double cash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equipped = abilities.equippedFor(slot);
    final cooldown = abilities.swapCooldownFor(slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: slot label + swap-cost chip when slot is occupied
        Row(
          children: [
            Text(
              _slotLabel(slot).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (equipped != null) ...[
              const SizedBox(width: 8),
              _SwapCostChip(cooldown: cooldown),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Equipped card or empty placeholder
        equipped != null
            ? _EquippedCard(
                ability: equipped,
                abilities: abilities,
                cooldown: cooldown,
              )
            : const _EmptySlotCard(),
      ],
    );
  }
}

// ── Equipped ability card ─────────────────────────────────────────────────────

class _EquippedCard extends StatelessWidget {
  const _EquippedCard({
    required this.ability,
    required this.abilities,
    required this.cooldown,
  });

  final Ability ability;
  final AbilityProvider abilities;
  final Duration? cooldown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = abilities.isActiveModifier(ability);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.6)
              : theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row + active badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  ability.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                _ActiveBadge(),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            ability.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),

          // Constraint (tradeoff)
          Text(
            ability.constraint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontStyle: FontStyle.italic,
            ),
          ),

          // Swap cooldown warning
          if (cooldown != null) ...[
            const SizedBox(height: 8),
            _CooldownRow(cooldown: cooldown!),
          ],
        ],
      ),
    );
  }
}

// ── Empty slot placeholder ────────────────────────────────────────────────────

class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          // Dashed effect via strokeAlign and a subtle background
        ),
        color: theme.colorScheme.surface.withValues(alpha: 0.4),
      ),
      child: Text(
        'Empty — equip an ability from below',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ── Bench section ─────────────────────────────────────────────────────────────

class _BenchSection extends StatelessWidget {
  const _BenchSection({required this.abilities, required this.cash});

  final AbilityProvider abilities;
  final double cash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Collect bench abilities per slot, skip slots with an empty bench.
    final groups = <AbilitySlot, List<Ability>>{};
    for (final slot in AbilitySlot.values) {
      final bench = abilities.benchFor(slot);
      if (bench.isNotEmpty) groups[slot] = bench;
    }

    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No unequipped abilities available.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(
          'AVAILABLE ABILITIES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final entry in groups.entries) ...[
          // Sub-group label per slot
          Text(
            _slotLabel(entry.key),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final ability in entry.value) ...[
            _BenchAbilityCard(
              ability: ability,
              abilities: abilities,
              cash: cash,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Bench ability card ────────────────────────────────────────────────────────

class _BenchAbilityCard extends StatelessWidget {
  const _BenchAbilityCard({
    required this.ability,
    required this.abilities,
    required this.cash,
  });

  final Ability ability;
  final AbilityProvider abilities;
  final double cash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotOccupied = abilities.equippedFor(ability.slot) != null;
    final cooldown = abilities.swapCooldownFor(ability.slot);
    final canAffordSwap = cash >= kSwapCostCurrency;
    final buttonBlocked = slotOccupied && (cooldown != null || !canAffordSwap);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ability.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ability.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ability.constraint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Equip / swap button
          _EquipButton(
            ability: ability,
            abilities: abilities,
            cash: cash,
            slotOccupied: slotOccupied,
            cooldown: cooldown,
            blocked: buttonBlocked,
          ),
        ],
      ),
    );
  }
}

// ── Equip button ──────────────────────────────────────────────────────────────

class _EquipButton extends StatelessWidget {
  const _EquipButton({
    required this.ability,
    required this.abilities,
    required this.cash,
    required this.slotOccupied,
    required this.cooldown,
    required this.blocked,
  });

  final Ability ability;
  final AbilityProvider abilities;
  final double cash;
  final bool slotOccupied;
  final Duration? cooldown;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = slotOccupied
        ? 'Swap\n\$${kSwapCostCurrency.toStringAsFixed(0)}'
        : 'Equip';

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: blocked
            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
            : theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(56, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: blocked
                ? theme.colorScheme.outline.withValues(alpha: 0.2)
                : theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
      onPressed: blocked
          ? null
          : () => _onTap(context),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    final err = abilities.equipAbility(
      ability.id,
      cashBalance: cash,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        'ACTIVE',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _SwapCostChip extends StatelessWidget {
  const _SwapCostChip({required this.cooldown});

  final Duration? cooldown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = cooldown != null
        ? 'Cooldown ${_formatDuration(cooldown!)}'
        : 'Swap: \$${kSwapCostCurrency.toStringAsFixed(0)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 10,
        ),
      ),
    );
  }
}

class _CooldownRow extends StatelessWidget {
  const _CooldownRow({required this.cooldown});

  final Duration cooldown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.lock_clock_outlined,
          size: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        Text(
          'Swap locked for ${_formatDuration(cooldown)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _slotLabel(AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.timing:
      return 'Timing Slot';
    case AbilitySlot.risk:
      return 'Risk Slot';
    case AbilitySlot.info:
      return 'Info Slot';
  }
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}
