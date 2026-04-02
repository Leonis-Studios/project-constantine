// ─────────────────────────────────────────────────────────────────────────────
// ability_card.dart  (lib/widgets/abilities/)
//
// PURPOSE: Display-only card for a single Ability. Shows the name, slot chip,
//          description, tradeoff, unlock condition, and optional EQUIPPED /
//          ACTIVE badges. Contains no equip or swap controls.
//
// USAGE:
//   AbilityCard(
//     ability: ability,
//     isEquipped: abilities.equippedFor(ability.slot)?.id == ability.id,
//     isActive: abilities.isActiveModifier(ability),
//   )
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../systems/abilities/ability.dart';
import '../../theme/app_theme.dart';

class AbilityCard extends StatelessWidget {
  const AbilityCard({
    super.key,
    required this.ability,
    required this.isEquipped,
    required this.isActive,
  });

  final Ability ability;

  /// Whether this ability is currently slotted in its slot.
  final bool isEquipped;

  /// Whether this ability is equipped AND actively applying a modifier this
  /// session (i.e. has onTradeModifier or onHoldModifier set).
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Border accent: active → primary glow, equipped → muted outline, else border.
    final borderColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.7)
        : isEquipped
            ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
            : AppTheme.border.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: name + badges ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + slot chip stacked on the left
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ability.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _SlotChip(slot: ability.slot),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badges stacked on the right, ACTIVE on top
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isActive) const _ActiveBadge(),
                  if (isActive && isEquipped) const SizedBox(height: 4),
                  if (isEquipped) const _EquippedBadge(),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Description ───────────────────────────────────────────────────
          Text(
            ability.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 10),

          // ── Tradeoff ──────────────────────────────────────────────────────
          _TradeoffRow(constraint: ability.constraint),

          const SizedBox(height: 10),

          // ── Divider ───────────────────────────────────────────────────────
          Divider(
            color: AppTheme.border.withValues(alpha: 0.4),
            height: 1,
          ),

          const SizedBox(height: 10),

          // ── Unlock condition ──────────────────────────────────────────────
          _EarnedByRow(condition: ability.unlockCondition),
        ],
      ),
    );
  }
}

// ── Slot chip ─────────────────────────────────────────────────────────────────

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot});

  final AbilitySlot slot;

  @override
  Widget build(BuildContext context) {
    final color = _slotColor(slot);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _slotLabel(slot).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── ACTIVE badge ──────────────────────────────────────────────────────────────

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        'ACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.primary,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── EQUIPPED badge ────────────────────────────────────────────────────────────

class _EquippedBadge extends StatelessWidget {
  const _EquippedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        'EQUIPPED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

// ── Tradeoff row ──────────────────────────────────────────────────────────────

class _TradeoffRow extends StatelessWidget {
  const _TradeoffRow({required this.constraint});

  final String constraint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Warning color: use the theme error (AppTheme.negative) at reduced opacity
    // so it reads as a caution note rather than an error state.
    final warnColor = theme.colorScheme.error.withValues(alpha: 0.75);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Tradeoff: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: warnColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        // Value — italic and same warning color at slightly lower opacity
        Expanded(
          child: Text(
            constraint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: warnColor.withValues(alpha: 0.85),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Earned-by row ─────────────────────────────────────────────────────────────

class _EarnedByRow extends StatelessWidget {
  const _EarnedByRow({required this.condition});

  final String condition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.4);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Earned by: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            condition,
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedColor,
              height: 1.4,
            ),
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
      return 'Timing';
    case AbilitySlot.risk:
      return 'Risk';
    case AbilitySlot.info:
      return 'Info';
  }
}

Color _slotColor(AbilitySlot slot) {
  switch (slot) {
    case AbilitySlot.timing:
      return AppTheme.accent;       // cyan — time/precision
    case AbilitySlot.risk:
      return AppTheme.negative;     // red/pink — danger/exposure
    case AbilitySlot.info:
      return AppTheme.positive;     // green — knowledge/gain
  }
}
