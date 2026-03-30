// ─────────────────────────────────────────────────────────────────────────────
// buy_sell_bottom_sheet.dart
//
// PURPOSE: Modal bottom sheet for entering a trade. Supports all four
//          transaction types: buy, sell, short, and cover.
//
// UI LAYOUT:
//   • Header: action label ("Buy / Sell / Short / Cover TICKER") + current price
//   • Share stepper: [−] N [+]
//   • Cost/proceeds line
//   • Constraint hint (available cash, shares owned, shares shorted)
//   • Inline error text in red if validation fails
//   • Confirm button
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/achievement_definitions.dart';
import '../models/stock.dart';
import '../models/transaction.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../providers/xp_provider.dart';
import '../theme/app_theme.dart';

// Amber for short-related UI elements.
const _kShortAmber = Color(0xFFE3B341);

class BuySellBottomSheet extends StatefulWidget {
  final Stock stock;
  final TransactionType type;
  final PortfolioProvider portfolio;

  const BuySellBottomSheet({
    super.key,
    required this.stock,
    required this.type,
    required this.portfolio,
  });

  @override
  State<BuySellBottomSheet> createState() => _BuySellBottomSheetState();
}

class _BuySellBottomSheetState extends State<BuySellBottomSheet> {
  int _shares = 1;
  String? _errorMessage;
  late TextEditingController _controller;

  bool get _isBuy => widget.type == TransactionType.buy;
  bool get _isSell => widget.type == TransactionType.sell;
  bool get _isShort => widget.type == TransactionType.short;

  // Maximum shares the user can trade in this direction.
  int get _maxShares {
    final price = widget.stock.currentPrice;
    if (price <= 0) return 0;

    if (_isBuy) {
      return (widget.portfolio.cashBalance / price).floor();
    } else if (_isSell) {
      return widget.portfolio.holdingForTicker(widget.stock.ticker)?.shares ?? 0;
    } else if (_isShort) {
      // Cap at 2× what cash could buy (acts as a rough margin limit).
      return (widget.portfolio.cashBalance / price * 2).floor().clamp(1, 9999);
    } else {
      // Cover: limited to shares currently shorted.
      return widget.portfolio.shortForTicker(widget.stock.ticker)?.shares ?? 0;
    }
  }

  String get _actionLabel {
    if (_isBuy) return 'Buy';
    if (_isSell) return 'Sell';
    if (_isShort) return 'Short';
    return 'Cover';
  }

  String get _totalLabel {
    if (_isBuy) return 'Total cost';
    if (_isSell) return 'You receive';
    if (_isShort) return 'You receive';
    return 'You pay';
  }

  Color get _confirmColor {
    if (_isBuy) return AppTheme.positive;
    if (_isSell) return AppTheme.negative;
    if (_isShort) return _kShortAmber;
    return AppTheme.accent;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _increment() {
    setState(() {
      _shares += 1;
      _errorMessage = null;
    });
    _controller.text = '$_shares';
  }

  void _decrement() {
    if (_shares > 1) {
      setState(() {
        _shares -= 1;
        _errorMessage = null;
      });
      _controller.text = '$_shares';
    }
  }

  void _confirm(BuildContext context) {
    final market = context.read<MarketProvider>();
    final latestStock =
        market.stockByTicker(widget.stock.ticker) ?? widget.stock;

    // Capture profit info BEFORE executing the trade (position still exists).
    double? profitOnThisTrade;
    if (_isSell) {
      final h = widget.portfolio.holdingForTicker(widget.stock.ticker);
      if (h != null) {
        profitOnThisTrade =
            (latestStock.currentPrice - h.averageCost) * _shares;
      }
    } else if (widget.type == TransactionType.cover) {
      final s = widget.portfolio.shortForTicker(widget.stock.ticker);
      if (s != null) {
        profitOnThisTrade =
            (s.entryPrice - latestStock.currentPrice) * _shares;
      }
    }

    String? error;
    if (_isBuy) {
      error = widget.portfolio.buyStock(latestStock, _shares);
    } else if (_isSell) {
      error = widget.portfolio.sellStock(latestStock, _shares);
    } else if (_isShort) {
      error = widget.portfolio.shortStock(latestStock, _shares);
    } else {
      error = widget.portfolio.coverStock(latestStock, _shares);
    }

    if (error != null) {
      setState(() => _errorMessage = error);
    } else {
      // Award XP and check achievements.
      final xpResult = context.read<XPProvider>().onTrade(
            type: widget.type,
            shares: _shares,
            price: latestStock.currentPrice,
            profitOnThisTrade: profitOnThisTrade,
            stock: latestStock,
            portfolio: widget.portfolio,
            stocks: market.stocks,
            currentDay: market.currentDay,
          );

      Navigator.pop(context);

      // Trade success snackbar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_successMessage  +${xpResult.xpGained} XP'),
          backgroundColor: _confirmColor,
          duration: const Duration(seconds: 2),
        ),
      );

      // Achievement snackbars.
      for (final id in xpResult.newAchievements) {
        final def = kAchievements.firstWhere(
          (a) => a.id == id,
          orElse: () => const AchievementDef(
              id: '', name: '', emoji: '', description: '', xpReward: 0),
        );
        if (def.id.isEmpty) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${def.emoji} Achievement unlocked: ${def.name}'),
            backgroundColor: AppTheme.surface,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String get _successMessage {
    final s = _shares == 1 ? '' : 's';
    if (_isBuy) return 'Bought $_shares share$s of ${widget.stock.ticker}.';
    if (_isSell) return 'Sold $_shares share$s of ${widget.stock.ticker}.';
    if (_isShort) return 'Shorted $_shares share$s of ${widget.stock.ticker}.';
    return 'Covered $_shares share$s of ${widget.stock.ticker}.';
  }

  @override
  Widget build(BuildContext context) {
    final latestStock =
        context.watch<MarketProvider>().stockByTicker(widget.stock.ticker) ??
            widget.stock;

    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final double totalAmount = _shares * latestStock.currentPrice;
    final int maxShares = _maxShares;

    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_actionLabel ${widget.stock.ticker}',
                style: AppTheme.headline,
              ),
              Text(
                currencyFormat.format(latestStock.currentPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          Text(widget.stock.companyName, style: AppTheme.companyName),

          const SizedBox(height: 24),

          // ── Share stepper ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove,
                onPressed: _shares > 1 ? _decrement : null,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    isDense: true,
                    suffixText: 'sh',
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed < 1) return;
                    final clamped = parsed.clamp(1, maxShares);
                    setState(() {
                      _shares = clamped;
                      _errorMessage = null;
                    });
                    if (parsed > maxShares) {
                      _controller
                        ..text = '$maxShares'
                        ..selection = TextSelection.collapsed(
                            offset: '$maxShares'.length);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              _StepButton(
                icon: Icons.add,
                onPressed: _shares < maxShares ? _increment : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Total ────────────────────────────────────────────────────────────
          Center(
            child: Text(
              '$_totalLabel: ${currencyFormat.format(totalAmount)}',
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Constraint hint ──────────────────────────────────────────────────
          Center(
            child: Text(
              _constraintHint(currencyFormat, maxShares),
              style: AppTheme.caption,
            ),
          ),

          // ── Inline error ─────────────────────────────────────────────────────
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppTheme.negative,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Confirm button ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: maxShares > 0 ? () => _confirm(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _confirmColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: _confirmColor.withValues(alpha: 0.3),
              ),
              child: Text(
                maxShares == 0
                    ? _disabledLabel
                    : '$_actionLabel $_shares share${_shares == 1 ? '' : 's'}',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _constraintHint(NumberFormat fmt, int maxShares) {
    if (_isBuy) {
      return 'Available cash: ${fmt.format(widget.portfolio.cashBalance)}'
          ' (max $maxShares share${maxShares == 1 ? '' : 's'})';
    } else if (_isSell) {
      return 'You own $maxShares share${maxShares == 1 ? '' : 's'}';
    } else if (_isShort) {
      return 'Available cash: ${fmt.format(widget.portfolio.cashBalance)}'
          ' (max $maxShares share${maxShares == 1 ? '' : 's'} at 2× leverage)';
    } else {
      return 'Short position: $maxShares share${maxShares == 1 ? '' : 's'} '
          'at entry ${fmt.format(widget.portfolio.shortForTicker(widget.stock.ticker)?.entryPrice ?? 0)}';
    }
  }

  String get _disabledLabel {
    if (_isBuy) return 'Not enough cash';
    if (_isSell) return 'No shares to sell';
    if (_isShort) return 'Not enough cash';
    return 'No short position';
  }
}

// ── Step Button ───────────────────────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onPressed != null ? AppTheme.surface : AppTheme.border,
          shape: BoxShape.circle,
          border: Border.all(
            color: onPressed != null ? AppTheme.accent : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          color: onPressed != null ? AppTheme.accent : AppTheme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
