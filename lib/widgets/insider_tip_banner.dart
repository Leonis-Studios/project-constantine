// ─────────────────────────────────────────────────────────────────────────────
// insider_tip_banner.dart
//
// PURPOSE: A non-blocking bottom-right overlay banner that notifies the player
//          that an insider contact has messaged them. The player can:
//            • Tap "View →" to see the full InsiderTipDialog
//            • Tap "Ignore" to dismiss without reading
//            • Do nothing — the banner auto-dismisses after 10 seconds
//
// This replaces the old blocking showDialog approach so gameplay is not
// interrupted when a tip arrives.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/insider_tip.dart';
import '../theme/app_theme.dart';

class InsiderTipBanner extends StatefulWidget {
  final InsiderTip tip;
  final VoidCallback onView;
  final VoidCallback onIgnore;

  const InsiderTipBanner({
    super.key,
    required this.tip,
    required this.onView,
    required this.onIgnore,
  });

  // ── Static helper ────────────────────────────────────────────────────────────
  //
  // Inserts the banner into the Overlay and returns the OverlayEntry so the
  // caller can remove it on demand (e.g., when "View" or "Ignore" is tapped).

  static OverlayEntry show(
    BuildContext context,
    InsiderTip tip, {
    required VoidCallback onView,
    required VoidCallback onIgnore,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => InsiderTipBanner(
        tip: tip,
        onView: onView,
        onIgnore: onIgnore,
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  @override
  State<InsiderTipBanner> createState() => _InsiderTipBannerState();
}

class _InsiderTipBannerState extends State<InsiderTipBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    // Auto-dismiss after 10 seconds.
    _autoTimer = Timer(const Duration(seconds: 10), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Slide out then call the ignore callback.
  Future<void> _dismiss() async {
    _autoTimer?.cancel();
    await _controller.reverse();
    widget.onIgnore();
  }

  @override
  Widget build(BuildContext context) {
    final directionColor =
        widget.tip.bullish ? AppTheme.positive : AppTheme.negative;
    final directionLabel = widget.tip.bullish ? 'BULLISH' : 'BEARISH';

    return Positioned(
      bottom: 80, // above the bottom nav bar
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(color: AppTheme.border, width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row ──────────────────────────────────────────
                    Row(
                      children: [
                        const Text('📬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${widget.tip.contactName} messaged you',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // ── Ticker + direction badge ─────────────────────────────
                    Row(
                      children: [
                        Text(
                          'Re: ${widget.tip.ticker}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: directionColor,
                            fontFamily: 'monospace',
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: directionColor.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppTheme.badgeRadius),
                          ),
                          child: Text(
                            directionLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: directionColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── Action buttons ───────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _dismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Ignore',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            _autoTimer?.cancel();
                            widget.onView();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View →',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
