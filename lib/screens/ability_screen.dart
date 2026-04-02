// TODO: Register this route in app router when ready

// ─────────────────────────────────────────────────────────────────────────────
// ability_screen.dart  (lib/screens/)
//
// PURPOSE: Full-page ability management screen. Players can view their three
//          equipped slots, equip bench abilities, and see their coin balance.
//
// CONSTRUCTOR:
//   AbilityScreen({required abilityService})
//   The AbilityService instance is required because AbilityEquipButton needs a
//   direct reference. Pass the same shared instance used in main().
//
// REACTIVITY:
//   context.watch<AbilityProvider>() and context.watch<PortfolioProvider>()
//   in build() — StatelessWidget, no local state.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ability_provider.dart';
import '../providers/portfolio_provider.dart';
import '../systems/abilities/ability.dart';
import '../systems/abilities/ability_registry.dart';
import '../systems/abilities/ability_service.dart';
import '../widgets/abilities/ability_card.dart';
import '../widgets/abilities/ability_equip_button.dart';

// ── Public screen ─────────────────────────────────────────────────────────────

class AbilityScreen extends StatelessWidget {
  const AbilityScreen({super.key, required this.abilityService});

  final AbilityService abilityService;

  @override
  Widget build(BuildContext context) {
    final abilities = context.watch<AbilityProvider>();
    final cash = context.watch<PortfolioProvider>().cashBalance;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Abilities'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _CoinChip(cash: cash),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Equipped slots ──────────────────────────────────────────────
            const _SectionLabel('EQUIPPED SLOTS'),
            const SizedBox(height: 8),

            for (final slot in AbilitySlot.values) ...[
              _SlotSection(
                slot: slot,
                abilities: abilities,
                abilityService: abilityService,
              ),
              const SizedBox(height: 16),
            ],

            // ── Bench divider ───────────────────────────────────────────────
            const _LabeledDivider('Unlocked — Available to Equip'),
            const SizedBox(height: 12),

            // ── Bench section ───────────────────────────────────────────────
            _BenchSection(
              abilities: abilities,
              abilityService: abilityService,
              theme: theme,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Slot section ──────────────────────────────────────────────────────────────

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slot,
    required this.abilities,
    required this.abilityService,
  });

  final AbilitySlot slot;
  final AbilityProvider abilities;
  final AbilityService abilityService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equipped = abilities.equippedFor(slot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Slot label (e.g. "TIMING")
        Text(
          _slotLabel(slot).toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),

        if (equipped != null) ...[
          AbilityCard(
            ability: equipped,
            isEquipped: true,
            isActive: abilities.isActiveModifier(equipped),
          ),
          const SizedBox(height: 6),
          AbilityEquipButton(
            ability: equipped,
            abilityService: abilityService,
          ),
        ] else
          _EmptySlotCard(slotName: _slotLabel(slot)),
      ],
    );
  }
}

// ── Bench section ─────────────────────────────────────────────────────────────

class _BenchSection extends StatelessWidget {
  const _BenchSection({
    required this.abilities,
    required this.abilityService,
    required this.theme,
  });

  final AbilityProvider abilities;
  final AbilityService abilityService;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Collect all unlocked-but-unequipped abilities across every slot.
    final bench = [
      for (final slot in AbilitySlot.values) ...abilities.benchFor(slot),
    ];

    // Determine whether the player has unlocked anything at all.
    final hasAnyUnlocked = bench.isNotEmpty ||
        AbilitySlot.values.any((s) => abilities.equippedFor(s) != null);

    if (!hasAnyUnlocked) {
      return _EmptyState(theme: theme);
    }

    if (bench.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'All unlocked abilities are equipped.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ability in bench) ...[
          AbilityCard(
            ability: ability,
            isEquipped: false,
            isActive: false,
          ),
          const SizedBox(height: 6),
          AbilityEquipButton(
            ability: ability,
            abilityService: abilityService,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Complete challenges to unlock abilities',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // One unlock hint per slot — pulled from the first ability in each slot.
            for (final slot in AbilitySlot.values) ...[
              _UnlockHint(slot: slot, theme: theme),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnlockHint extends StatelessWidget {
  const _UnlockHint({required this.slot, required this.theme});

  final AbilitySlot slot;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Find the first ability registered for this slot.
    final ability = AbilityRegistry.all.where((a) => a.slot == slot).firstOrNull;
    if (ability == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        '• ${ability.unlockCondition}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Empty slot placeholder ────────────────────────────────────────────────────

class _EmptySlotCard extends StatelessWidget {
  const _EmptySlotCard({required this.slotName});

  final String slotName;

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
        ),
        color: theme.colorScheme.surface.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slotName,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No ability equipped',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Coin balance chip ─────────────────────────────────────────────────────────

class _CoinChip extends StatelessWidget {
  const _CoinChip({required this.cash});

  final double cash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        '\$${cash.toStringAsFixed(0)}',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Labeled divider ───────────────────────────────────────────────────────────

class _LabeledDivider extends StatelessWidget {
  const _LabeledDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _slotLabel(AbilitySlot slot) => switch (slot) {
      AbilitySlot.timing => 'Timing',
      AbilitySlot.risk => 'Risk',
      AbilitySlot.info => 'Info',
    };
