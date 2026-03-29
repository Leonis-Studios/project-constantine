// ─────────────────────────────────────────────────────────────────────────────
// sparkline_chart.dart
//
// PURPOSE: Thin wrapper around fl_chart's LineChart. Renders price history as
//          a smooth line in either compact (no axes) or detailed (with axes)
//          mode.
//
// MODES:
//   showAxes: false — used inside StockTile for inline compact sparklines.
//             No labels, no grid, no tooltips. Just the line.
//   showAxes: true  — used on StockDetailScreen. Shows Y-axis price labels
//             and enables tap-to-show-value tooltips.
//
// COLOUR: Green line if isPositive (today ≥ yesterday), red if negative.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SparklineChart extends StatelessWidget {
  /// Ordered list of prices oldest-first (from Stock.priceHistory).
  final List<double> prices;

  /// True = draw in green, false = draw in red.
  final bool isPositive;

  /// Height of the chart widget in logical pixels.
  final double height;

  /// When true, renders Y-axis labels and enables touch tooltips.
  /// When false, renders a clean line only (for list tiles).
  final bool showAxes;

  const SparklineChart({
    super.key,
    required this.prices,
    required this.isPositive,
    this.height = 60,
    this.showAxes = false,
  });

  @override
  Widget build(BuildContext context) {
    // Need at least 2 points to draw a line.
    if (prices.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Not enough data', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ),
      );
    }

    final Color lineColor =
        isPositive ? AppTheme.positive : AppTheme.negative;

    // Convert the price list into fl_chart FlSpot points.
    // X = index (day number), Y = price.
    final List<FlSpot> spots = prices.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    // Calculate the Y-axis range with a small padding so the line doesn't
    // touch the edges of the chart.
    final double minY = prices.reduce((a, b) => a < b ? a : b);
    final double maxY = prices.reduce((a, b) => a > b ? a : b);
    final double yPadding = (maxY - minY) == 0
        ? 1.0 // flat line: add 1 unit of padding so it's visible
        : (maxY - minY) * 0.1;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          // ── Data ───────────────────────────────────────────────────────────
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true, // smooth bezier curve
              curveSmoothness: 0.3,
              color: lineColor,
              barWidth: showAxes ? 2.0 : 1.5,
              dotData: const FlDotData(show: false), // hide individual dots
              belowBarData: BarAreaData(
                show: true,
                // Gradient fill below the line — subtle, not distracting.
                gradient: LinearGradient(
                  colors: [
                    lineColor.withValues(alpha: 0.25),
                    lineColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],

          // ── Axis bounds ────────────────────────────────────────────────────
          minY: minY - yPadding,
          maxY: maxY + yPadding,

          // ── Touch behaviour ────────────────────────────────────────────────
          lineTouchData: showAxes
              ? LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    // Show the price value when the user touches the chart.
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '\$${spot.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                )
              // No touch interaction in compact (sparkline) mode.
              : const LineTouchData(enabled: false),

          // ── Grid and borders ───────────────────────────────────────────────
          gridData: showAxes
              ? FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppTheme.border,
                    strokeWidth: 0.5,
                  ),
                )
              // No grid in compact mode — keep it clean.
              : const FlGridData(show: false),

          borderData: FlBorderData(show: false), // no chart border box

          // ── Axis labels ─────────────────────────────────────────────────────
          titlesData: showAxes
              ? FlTitlesData(
                  // Y-axis on the right side with price labels.
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '\$${value.toStringAsFixed(0)}',
                          style: AppTheme.caption,
                        );
                      },
                    ),
                  ),
                  // Hide the other three axes.
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                )
              // No labels in compact mode.
              : const FlTitlesData(show: false),
        ),
      ),
    );
  }
}
