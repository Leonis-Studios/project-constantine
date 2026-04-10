// ─────────────────────────────────────────────────────────────────────────────
// ability_unlock_toast.dart  (lib/widgets/abilities/)
//
// PURPOSE: Overlay banner that slides in from the top whenever a new ability is
//          unlocked. Auto-dismisses after 4 seconds or immediately on tap.
//
// USAGE:
//   AbilityUnlockToast.show(context, ability);
//
// The static show() method inserts an OverlayEntry into the nearest Overlay
// (rootOverlay: true so it sits above any Navigator pages). The entry removes
// itself on dismiss — callers need no cleanup.
//
// KNOWN ISSUE — BLANK BANNER FIX:
//   OverlayEntry widgets sit in the root overlay, which is above the
//   MaterialApp's Theme/MediaQuery/Directionality scope in the widget tree.
//   When the builder context lacks these inherited widgets, Text widgets
//   render with no font metrics / no text direction and the card appears as a
//   solid coloured block with no visible text.
//   Fix: the builder explicitly wraps content in Directionality, MediaQuery,
//   and Theme (all captured at call time from the caller's context) so text
//   styles and layout resolve correctly regardless of where the overlay sits
//   in the tree. If this regresses, check that all three captures in show()
//   still happen BEFORE the OverlayEntry builder closure is created.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../systems/abilities/ability.dart';
import '../../theme/app_theme.dart';

// ── Public API ────────────────────────────────────────────────────────────────

class AbilityUnlockToast {
  /// Show an unlock banner for [ability] using [context]'s Overlay.
  /// Safe to call from any widget that is under MaterialApp.
  static void show(BuildContext context, Ability ability) {
    final overlay = Overlay.of(context, rootOverlay: true);
    // Capture the caller's Theme and MediaQuery so the overlay entry has
    // access to font metrics and text styles even though it sits above the
    // MaterialApp's Theme in the widget tree.
    final themeData = Theme.of(context);
    final mediaQueryData = MediaQuery.of(context);
    final textDirection = Directionality.of(context);
    late OverlayEntry entry;
    bool removed = false;
    entry = OverlayEntry(
      builder: (_) => Directionality(
        textDirection: textDirection,
        child: MediaQuery(
          data: mediaQueryData,
          child: Theme(
            data: themeData,
            child: _ToastOverlay(
              ability: ability,
              onDismiss: () {
                if (!removed) {
                  removed = true;
                  entry.remove();
                }
              },
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

// ── Animated overlay ──────────────────────────────────────────────────────────

class _ToastOverlay extends StatefulWidget {
  const _ToastOverlay({
    required this.ability,
    required this.onDismiss,
  });

  final Ability ability;
  final VoidCallback onDismiss;

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    Future.delayed(const Duration(seconds: 4), _dismiss);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: _ToastCard(ability: widget.ability),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Toast card ────────────────────────────────────────────────────────────────

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.ability});

  final Ability ability;

  @override
  Widget build(BuildContext context) {
    final slotColor = _slotColor(ability.slot);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          top: const BorderSide(color: AppTheme.border),
          right: const BorderSide(color: AppTheme.border),
          bottom: const BorderSide(color: AppTheme.border),
          left: BorderSide(color: slotColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.lock_open_rounded, size: 16, color: slotColor),
              const SizedBox(width: 8),
              const Text(
                'ABILITY UNLOCKED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.close,
                size: 14,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Ability name ─────────────────────────────────────────────────
          Text(
            ability.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // ── Slot chip + description ───────────────────────────────────────
          Row(
            children: [
              _SlotChip(slot: ability.slot),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  ability.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _slotColor(AbilitySlot slot) => switch (slot) {
      AbilitySlot.timing => AppTheme.accent,
      AbilitySlot.risk => AppTheme.negative,
      AbilitySlot.info => AppTheme.positive,
    };

String _slotLabel(AbilitySlot slot) => switch (slot) {
      AbilitySlot.timing => 'Timing',
      AbilitySlot.risk => 'Risk',
      AbilitySlot.info => 'Info',
    };
