import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// DESIGN PREVIEW — Cyberpunk / Data-Forward Stock Dashboard
// Standalone file. All data is hardcoded. Do not import elsewhere.
// ═══════════════════════════════════════════════════════════════

// ─── Color Palette ────────────────────────────────────────────
const Color _bgDeep    = Color(0xFF0a0a0f);
const Color _bgMid     = Color(0xFF0f0f1a);
const Color _bgLight   = Color(0xFF12121f);
const Color _stone     = Color(0xFF12121f);
const Color _stoneBorder = Color(0xFF1e1e3a);
const Color _gold      = Color(0xFF00d4ff);   // cyan — primary accent
const Color _goldBright = Color(0xFF00d4ff);  // cyan — highlights
const Color _upGreen   = Color(0xFF00ff9d);   // profit
const Color _downRed   = Color(0xFFff2d78);   // loss / alert
const Color _textParch = Color(0xFFffffff);   // primary text
const Color _textDim   = Color(0xFF8888aa);   // muted labels
const Color _trackBg   = Color(0xFF070710);   // progress bar track

// ─── Hardcoded Data ───────────────────────────────────────────
class _StockData {
  final String ticker;
  final String name;
  final double price;
  final double change;
  final String icon;

  const _StockData({
    required this.ticker,
    required this.name,
    required this.price,
    required this.change,
    required this.icon,
  });
}

const _StockData _legendary = _StockData(
  ticker: 'NVDA',
  name: 'Dragon GPU Corporation',
  price: 134.50,
  change: 4.2,
  icon: '🐉',
);

const List<_StockData> _stocks = [
  _StockData(ticker: 'AAPL', name: 'Golden Apple Inc', price: 224.10, change: 1.8, icon: '🪙'),
  _StockData(ticker: 'TSLA', name: 'Thundersteed Motors', price: 178.30, change: -3.1, icon: '⚔️'),
  _StockData(ticker: 'MSFT', name: 'Wizard Software Co', price: 415.20, change: 0.9, icon: '📜'),
  _StockData(ticker: 'AMZN', name: 'Grand Exchange Ltd', price: 198.45, change: -1.4, icon: '🪙'),
  _StockData(ticker: 'META', name: 'Scrying Glass Corp', price: 522.80, change: 2.6, icon: '🐉'),
  _StockData(ticker: 'GOOGL', name: 'Oracle Search Guild', price: 171.60, change: -0.7, icon: '📜'),
];

// ─── Screen ───────────────────────────────────────────────────
class DesignPreviewScreen extends StatefulWidget {
  const DesignPreviewScreen({super.key});

  @override
  State<DesignPreviewScreen> createState() => _DesignPreviewScreenState();
}

class _DesignPreviewScreenState extends State<DesignPreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _HudBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (context, child) =>
                          _LegendaryCard(glowOpacity: _glowAnim.value),
                    ),
                    const SizedBox(height: 16),
                    _SectionHeader(label: '📜  Market Inventory'),
                    const SizedBox(height: 8),
                    ..._stocks.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _StockItemCard(stock: s),
                        )),
                    const SizedBox(height: 80), // space for bottom bar
                  ],
                ),
              ),
            ),
            _BottomActionBar(),
          ],
        ),
      ),
    );
  }
}

// ─── HUD Bar ──────────────────────────────────────────────────
class _HudBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _stone,
        border: const Border(
          bottom: BorderSide(color: _stoneBorder, width: 1),
          top: BorderSide(color: _stoneBorder, width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: _gold.withValues(alpha: 0.15), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Player name
            Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adventurer_42',
                      style: TextStyle(
                        color: _textParch,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Merchant Guild',
                      style: TextStyle(
                        color: _textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            // Gold total
            Column(
              children: [
                Text(
                  '🪙 Gold: 142,500',
                  style: TextStyle(
                    color: _goldBright,
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: _gold.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                ),
                Text(
                  'Portfolio Value',
                  style: TextStyle(
                    color: _textDim,
                    fontSize: 9,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _bgDeep,
                border: Border.all(color: _gold.withValues(alpha: 0.6), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Lv. 12\nMerchant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _gold,
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Legendary Card ───────────────────────────────────────────
class _LegendaryCard extends StatelessWidget {
  final double glowOpacity;
  const _LegendaryCard({required this.glowOpacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bgMid,
        border: Border.all(color: _goldBright, width: 1),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: _goldBright.withValues(alpha: glowOpacity * 0.55),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: _gold.withValues(alpha: glowOpacity * 0.25),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _gold.withValues(alpha: 0.2), width: 1),
          borderRadius: BorderRadius.circular(5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _goldBright.withValues(alpha: 0.08),
                    border: Border.all(color: _goldBright.withValues(alpha: 0.7), width: 1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '✦  LEGENDARY DROP  ✦',
                    style: TextStyle(
                      color: _goldBright,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '🐉',
                  style: TextStyle(
                    fontSize: 28,
                    shadows: [Shadow(color: _goldBright.withValues(alpha: 0.8), blurRadius: 14)],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _legendary.ticker,
                      style: TextStyle(
                        color: _goldBright,
                        fontFamily: 'monospace',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: _gold.withValues(alpha: 0.7), blurRadius: 10)],
                      ),
                    ),
                    Text(
                      _legendary.name,
                      style: TextStyle(
                        color: _textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_legendary.price.toStringAsFixed(2)} gp',
                      style: TextStyle(
                        color: _textParch,
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatBar(change: _legendary.change, width: 100),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Examine: A powerful GPU rune of immense graphical magic.\nRarity: Legendary  •  Category: Technology',
              style: TextStyle(
                color: _textDim,
                fontSize: 11,
                fontWeight: FontWeight.w300,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(
              color: _textDim,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: _Divider()),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, color: _stoneBorder),
        const SizedBox(height: 2),
        Container(height: 1, color: _stoneBorder.withValues(alpha: 0.4)),
      ],
    );
  }
}

// ─── Stock Item Card ──────────────────────────────────────────
class _StockItemCard extends StatelessWidget {
  final _StockData stock;
  const _StockItemCard({required this.stock});

  @override
  Widget build(BuildContext context) {
    final bool isUp = stock.change >= 0;
    final Color accentColor = isUp ? _upGreen : _downRed;

    return Container(
      decoration: BoxDecoration(
        color: _bgLight,
        border: Border.all(color: _stoneBorder, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: accentColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Icon + ticker
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text(
                    stock.ticker,
                    style: TextStyle(
                      color: _textParch,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Name + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.name,
                    style: TextStyle(
                      color: _textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${stock.price.toStringAsFixed(2)} gp',
                    style: TextStyle(
                      color: _textParch,
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Stat bar
            _StatBar(change: stock.change, width: 88),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Bar (glowing data bar style) ────────────────────────
class _StatBar extends StatelessWidget {
  final double change;
  final double width;
  const _StatBar({required this.change, required this.width});

  @override
  Widget build(BuildContext context) {
    final bool isUp = change >= 0;
    final Color barColor = isUp ? _upGreen : _downRed;
    final double fill = (change.abs() / 10).clamp(0.05, 1.0);
    final String label =
        '${isUp ? '▲' : '▼'} ${isUp ? '+' : ''}${change.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isUp ? _upGreen : _downRed,
            fontFamily: 'monospace',
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: width,
          height: 8,
          decoration: BoxDecoration(
            color: _trackBg,
            border: Border.all(color: _stoneBorder, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fill,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(1),
                boxShadow: [
                  BoxShadow(
                    color: barColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Action Bar ────────────────────────────────────────
class _BottomActionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _stone,
        border: Border(
          top: BorderSide(color: _stoneBorder, width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _gold.withValues(alpha: 0.15), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _ActionButton(label: '⚔️ Buy', color: _upGreen),
            const SizedBox(width: 8),
            _ActionButton(label: '🪙 Sell', color: _downRed),
            const SizedBox(width: 8),
            _ActionButton(label: '📜 Examine', color: _stoneBorder),
            const SizedBox(width: 8),
            _ActionButton(label: '👁 Watch', color: _stoneBorder),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  const _ActionButton({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$label selected',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              backgroundColor: _stone,
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color == _stoneBorder ? _textDim : color,
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
