// ─────────────────────────────────────────────────────────────────────────────
// ability_provider.dart  (lib/providers/)
//
// PURPOSE: Thin ChangeNotifier wrapper over AbilityService, purpose-built for
//          the widget layer. Exposes only what the UI needs — no business logic
//          lives here.
//
// WIRING:
//   Constructed in main() with the shared AbilityService instance, then
//   registered via ChangeNotifierProvider.value so every widget can watch it.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

import '../systems/abilities/ability.dart';
import '../systems/abilities/ability_registry.dart';
import '../systems/abilities/ability_service.dart';

class AbilityProvider extends ChangeNotifier {
  AbilityProvider(this._service);

  final AbilityService _service;

  // ── Refresh ───────────────────────────────────────────────────────────────
  // Call this from MarketProvider / PortfolioProvider after any operation that
  // may change ability state (equips, unlocks, cooldown expiry).

  void refresh() => notifyListeners();

  // ── Equipped state ────────────────────────────────────────────────────────

  /// The ability currently equipped in [slot], or null if the slot is empty.
  Ability? equippedFor(AbilitySlot slot) => _service.equippedAbility(slot);

  // ── Bench (unlocked, unequipped) ──────────────────────────────────────────

  /// All unlocked abilities for [slot] that are not currently equipped.
  /// These are shown in the scrollable "available" list below the slot sections.
  List<Ability> benchFor(AbilitySlot slot) {
    final equippedId = _service.equippedAbility(slot)?.id;
    return AbilityRegistry.all
        .where((a) => a.slot == slot && a.isUnlocked && a.id != equippedId)
        .toList();
  }

  // ── Active modifier badge ─────────────────────────────────────────────────

  /// True if [ability] is equipped in its slot AND has at least one trade or
  /// hold modifier function — meaning it is actively affecting outcomes.
  /// Always false for locked or bench abilities.
  bool isActiveModifier(Ability ability) {
    final equipped = _service.equippedAbility(ability.slot);
    if (equipped?.id != ability.id) return false;
    return ability.onTradeModifier != null || ability.onHoldModifier != null;
  }

  // ── Cooldown ──────────────────────────────────────────────────────────────

  /// Remaining swap cooldown for [slot], or null if no cooldown is active.
  Duration? swapCooldownFor(AbilitySlot slot) =>
      _service.swapCooldownRemaining(slot);

  /// Forwards the service's unlock stream so root widgets can listen without
  /// a direct reference to AbilityService.
  Stream<Ability> get unlockStream => _service.unlockStream;

  // ── Equip / swap ──────────────────────────────────────────────────────────

  /// Equips [abilityId] in its slot. Free if slot is empty; delegates to
  /// [swapAbility] if a different ability is already equipped.
  /// Returns an error string on failure, null on success.
  String? equipAbility(String abilityId, {required double cashBalance}) {
    final err = _service.equipAbility(abilityId, cashBalance: cashBalance);
    if (err == null) notifyListeners();
    return err;
  }

  /// Swaps the equipped ability for [abilityId]. Costs $500 and enforces a
  /// 1-hour real-time cooldown per slot.
  /// Returns an error string on failure, null on success.
  String? swapAbility(String abilityId, {required double cashBalance}) {
    final err = _service.swapAbility(abilityId, cashBalance: cashBalance);
    if (err == null) notifyListeners();
    return err;
  }
}
