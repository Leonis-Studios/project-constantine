// ─────────────────────────────────────────────────────────────────────────────
// buy_sell_bottom_sheet.dart
//
// PURPOSE: Modal bottom sheet for entering a trade. Shown when the user presses
//          Buy or Sell on StockDetailScreen.
//
// UI LAYOUT:
//   • Header: "Buy NXCO" or "Sell NXCO" title + current price
//   • Share stepper: [−] 3 [+] (integer, min 1)
//   • Cost/proceeds line: "Total cost: $427.50"
//   • Constraint hint: "You have $9,572.50 available" (buy)
//                      "You own 10 shares" (sell)
//   • Inline error text in red if validation fails
//   • Confirm button
//
// VALIDATION: The portfolio provider validates the trade and returns an error
//             string if it cannot proceed. We display that string inline.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock.dart';
import '../models/transaction.dart';
import '../providers/market_provider.dart';
import '../providers/portfolio_provider.dart';
import '../theme/app_theme.dart';

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
  // Number of shares the user wants to trade. Starts at 1.
  int _shares = 1;

  // Error message returned by the portfolio provider, shown in red below the
  // stepper. Null = no error currently displayed.
  String? _errorMessage;

  bool get _isBuy => widget.type == TransactionType.buy;

  // Maximum shares the user can trade in this direction.
  int get _maxShares {
    if (_isBuy) {
      // Max buyable = how many whole shares $cashBalance can afford.
      final price = widget.stock.currentPrice;
      if (price <= 0) return 0;
      return (widget.portfolio.cashBalance / price).floor();
    } else {
      // Max sellable = shares currently held.
      final holding =
          widget.portfolio.holdingForTicker(widget.stock.ticker);
      return holding?.shares ?? 0;
    }
  }

  void _increment() {
    setState(() {
      _shares += 1;
      _errorMessage = null;
    });
  }

  void _decrement() {
    if (_shares > 1) {
      setState(() {
        _shares -= 1;
        _errorMessage = null;
      });
    }
  }

  void _confirm(BuildContext context) {
    // Read the latest stock price (it may have changed since the sheet opened).
    final latestStock =
        context.read<MarketProvider>().stockByTicker(widget.stock.ticker) ??
            widget.stock;

    final String? error = _isBuy
        ? widget.portfolio.buyStock(latestStock, _shares)
        : widget.portfolio.sellStock(latestStock, _shares);

    if (error != null) {
      // Show the error inline — don't close the sheet.
      setState(() => _errorMessage = error);
    } else {
      // Trade succeeded — close the sheet and show a snackbar.
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isBuy
                ? 'Bought $_shares share${_shares == 1 ? '' : 's'} of ${widget.stock.ticker}.'
                : 'Sold $_shares share${_shares == 1 ? '' : 's'} of ${widget.stock.ticker}.',
          ),
          backgroundColor:
              _isBuy ? AppTheme.positive : AppTheme.negative,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the market provider so the live price updates if the user leaves
    // the sheet open for a long time.
    final latestStock =
        context.watch<MarketProvider>().stockByTicker(widget.stock.ticker) ??
            widget.stock;

    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final double totalAmount = _shares * latestStock.currentPrice;
    final int maxShares = _maxShares;

    // Pad the sheet above the keyboard so the confirm button stays visible.
    final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_isBuy ? 'Buy' : 'Sell'} ${widget.stock.ticker}',
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

          // ── Share stepper ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decrement button.
              _StepButton(
                icon: Icons.remove,
                onPressed: _shares > 1 ? _decrement : null,
              ),
              const SizedBox(width: 24),
              // Share count display.
              Text(
                '$_shares share${_shares == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 24),
              // Increment button.
              _StepButton(
                icon: Icons.add,
                onPressed: _shares < maxShares ? _increment : null,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Total cost / proceeds ─────────────────────────────────────────
          Center(
            child: Text(
              '${_isBuy ? 'Total cost' : 'You receive'}: ${currencyFormat.format(totalAmount)}',
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ── Constraint hint ───────────────────────────────────────────────
          Center(
            child: Text(
              _isBuy
                  ? 'Available cash: ${currencyFormat.format(widget.portfolio.cashBalance)}'
                      ' (max $maxShares share${maxShares == 1 ? '' : 's'})'
                  : 'You own $_maxShares share${_maxShares == 1 ? '' : 's'}',
              style: AppTheme.caption,
            ),
          ),

          // ── Inline error message ──────────────────────────────────────────
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

          // ── Confirm button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: maxShares > 0
                  ? () => _confirm(context)
                  : null, // disabled if nothing to trade
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isBuy ? AppTheme.positive : AppTheme.negative,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                maxShares == 0
                    ? (_isBuy ? 'Not enough cash' : 'No shares to sell')
                    : '${_isBuy ? 'Buy' : 'Sell'} $_shares share${_shares == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step Button ───────────────────────────────────────────────────────────────
//
// The + and − buttons in the share stepper. Grey when disabled (at the limit).

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
