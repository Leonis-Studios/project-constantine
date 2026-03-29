// ─────────────────────────────────────────────────────────────────────────────
// event_card.dart
//
// PURPOSE: Displays a single MarketEvent as a card with a coloured left border.
//          Green border for positive events, red for negative, blue for global.
//
// USED IN:
//   • EventsLogScreen — main events feed
//   • StockDetailScreen — "Recent News" section at the bottom
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/market_event.dart';
import '../theme/app_theme.dart';

class EventCard extends StatelessWidget {
  final MarketEvent event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    // Determine the accent colour: global events use blue, otherwise green/red.
    final Color accentColor = event.isGlobal
        ? AppTheme.accent
        : event.isPositive
            ? AppTheme.positive
            : AppTheme.negative;

    // Format the impact as "+8.5%" or "-12.0%".
    final String impactStr =
        '${event.impactPercent >= 0 ? '+' : ''}${event.impactPercent.toStringAsFixed(1)}%';

    // Format the timestamp.
    final String timeStr =
        DateFormat('MMM d • h:mm a').format(event.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Coloured left border strip ───────────────────────────────
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.cardRadius),
                  bottomLeft: Radius.circular(AppTheme.cardRadius),
                ),
              ),
            ),

            // ── Event content ─────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row: day badge + impact badge ─────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // "Day 7" label.
                        Text(
                          'Day ${event.dayNumber}',
                          style: AppTheme.caption,
                        ),
                        // Impact percentage badge.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.isPositive
                                ? AppTheme.positiveFaint
                                : AppTheme.negativeFaint,
                            borderRadius: BorderRadius.circular(
                                AppTheme.badgeRadius),
                          ),
                          child: Text(
                            impactStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: event.isPositive
                                  ? AppTheme.positive
                                  : AppTheme.negative,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // ── Headline ──────────────────────────────────────────
                    Text(
                      event.headline,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ── Description ───────────────────────────────────────
                    Text(
                      event.description,
                      style: AppTheme.companyName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // ── Footer: scope tag + timestamp ─────────────────────
                    Row(
                      children: [
                        // Show a chip indicating scope: ticker, sector, or GLOBAL.
                        _ScopeChip(event: event, color: accentColor),
                        const Spacer(),
                        Text(timeStr, style: AppTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scope chip ────────────────────────────────────────────────────────────────
//
// Small tag showing what the event affected: a ticker, a sector name, or GLOBAL.

class _ScopeChip extends StatelessWidget {
  final MarketEvent event;
  final Color color;

  const _ScopeChip({required this.event, required this.color});

  @override
  Widget build(BuildContext context) {
    final String label;
    if (event.isGlobal) {
      label = 'GLOBAL';
    } else if (event.affectedTicker != null) {
      label = event.affectedTicker!;
    } else if (event.affectedSector != null) {
      label = event.affectedSector!;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.badgeRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
