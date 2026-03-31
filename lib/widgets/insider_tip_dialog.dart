// ─────────────────────────────────────────────────────────────────────────────
// insider_tip_dialog.dart
//
// PURPOSE: A "shady DM" dialog that shows the player an insider tip about a
//          stock. Tips are flavour — ~40% are deliberately misleading.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../models/insider_tip.dart';
import '../theme/app_theme.dart';

class InsiderTipDialog extends StatefulWidget {
  final InsiderTip tip;
  final VoidCallback onDismiss;

  /// Whether this stock is currently in the player's watchlist.
  final bool isWatched;

  /// Callback to toggle watchlist status. If null, button is hidden.
  final VoidCallback? onToggleWatch;

  const InsiderTipDialog({
    super.key,
    required this.tip,
    required this.onDismiss,
    this.isWatched = false,
    this.onToggleWatch,
  });

  @override
  State<InsiderTipDialog> createState() => _InsiderTipDialogState();
}

class _InsiderTipDialogState extends State<InsiderTipDialog> {
  late bool _isWatched;

  @override
  void initState() {
    super.initState();
    _isWatched = widget.isWatched;
  }

  @override
  Widget build(BuildContext context) {
    final tip = widget.tip;
    final directionColor =
        tip.bullish ? AppTheme.positive : AppTheme.negative;
    final directionIcon =
        tip.bullish ? Icons.trending_up : Icons.trending_down;
    final directionLabel = tip.bullish ? 'BULLISH' : 'BEARISH';

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                const Text(
                  '📬',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'INCOMING MESSAGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                // Direction badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: directionColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppTheme.badgeRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(directionIcon, size: 12, color: directionColor),
                      const SizedBox(width: 4),
                      Text(
                        directionLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: directionColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // From line
            Text(
              'From: ${tip.contactName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),

            const Divider(height: 20),

            // ── Ticker ───────────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  tip.ticker,
                  style: AppTheme.ticker.copyWith(
                    color: directionColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip.companyName,
                    style: AppTheme.companyName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Body ─────────────────────────────────────────────────────────
            Text(
              tip.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // ── Disclaimer ───────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 13, color: AppTheme.textMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Unverified intel. Trade at your own risk.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Watchlist + dismiss buttons ───────────────────────────────────
            if (widget.onToggleWatch != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      widget.onToggleWatch!();
                      setState(() => _isWatched = !_isWatched);
                    },
                    icon: Icon(
                      _isWatched ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _isWatched ? AppTheme.accent : AppTheme.textMuted,
                    ),
                    label: Text(
                      _isWatched
                          ? 'Watching ${tip.ticker}'
                          : 'Watch ${tip.ticker}',
                      style: TextStyle(
                        color: _isWatched
                            ? AppTheme.accent
                            : AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      side: BorderSide(
                        color: _isWatched
                            ? AppTheme.accent.withValues(alpha: 0.5)
                            : AppTheme.border.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.badgeRadius),
                      ),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onDismiss,
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
