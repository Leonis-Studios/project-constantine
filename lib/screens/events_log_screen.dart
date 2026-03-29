// ─────────────────────────────────────────────────────────────────────────────
// events_log_screen.dart
//
// PURPOSE: Reverse-chronological feed of every MarketEvent that has fired
//          since the game started. Includes filter chips so the user can
//          narrow down to positive, negative, global, or sector-specific events.
//
// FILTERS (FilterChip row):
//   • All       — show everything (default)
//   • Positive  — only events with isPositive == true
//   • Negative  — only events with isPositive == false
//   • Global    — only market-wide events
//   One sector chip per unique sector appearing in the events log
//
// STATE: _activeFilter is local widget state (doesn't need to outlive the tab).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/market_event.dart';
import '../providers/market_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/event_card.dart';

class EventsLogScreen extends StatefulWidget {
  const EventsLogScreen({super.key});

  @override
  State<EventsLogScreen> createState() => _EventsLogScreenState();
}

class _EventsLogScreenState extends State<EventsLogScreen> {
  // The currently active filter string.
  // 'all' is the default; other values match filter chip labels.
  String _activeFilter = 'all';

  /// Filters [events] according to the current _activeFilter.
  List<MarketEvent> _filtered(List<MarketEvent> events) {
    switch (_activeFilter) {
      case 'all':
        return events;
      case 'positive':
        return events.where((e) => e.isPositive).toList();
      case 'negative':
        return events.where((e) => !e.isPositive).toList();
      case 'global':
        return events.where((e) => e.isGlobal).toList();
      default:
        // Filter value is a sector name — match affectedSector.
        return events
            .where((e) => e.affectedSector == _activeFilter)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final events = market.events; // already newest-first

    // Collect unique sectors mentioned in the log for dynamic filter chips.
    final sectors = events
        .where((e) => e.affectedSector != null)
        .map((e) => e.affectedSector!)
        .toSet()
        .toList()
      ..sort();

    final filtered = _filtered(events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter chips row ────────────────────────────────────────────────
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              // Standard filter chips.
              for (final filter in ['all', 'positive', 'negative', 'global'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_chipLabel(filter)),
                    selected: _activeFilter == filter,
                    onSelected: (_) =>
                        setState(() => _activeFilter = filter),
                    selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.accent,
                    labelStyle: TextStyle(
                      color: _activeFilter == filter
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              // Sector chips — one per unique sector that has had an event.
              for (final sector in sectors)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(sector),
                    selected: _activeFilter == sector,
                    onSelected: (_) =>
                        setState(() => _activeFilter = sector),
                    selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.accent,
                    labelStyle: TextStyle(
                      color: _activeFilter == sector
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Events list ─────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.feed_outlined,
                          size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        events.isEmpty
                            ? 'No events yet.\nPress "Next Day" to see what happens!'
                            : 'No events match this filter.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      EventCard(event: filtered[index]),
                ),
        ),
      ],
    );
  }

  /// Returns a display label for standard filter keys.
  String _chipLabel(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'positive':
        return 'Positive';
      case 'negative':
        return 'Negative';
      case 'global':
        return 'Global';
      default:
        return filter;
    }
  }
}
