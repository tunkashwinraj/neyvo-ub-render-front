import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/models/billing_model.dart';
import '../../../theme/neyvo_theme.dart';

class CallsLineChart extends StatelessWidget {
  final List<CallUsagePoint> points;

  const CallsLineChart({required this.points, super.key});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No usage data'));
    }

    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].count.toDouble())
    ];

    final maxX = (points.length - 1).toDouble();
    final tickCount = points.length <= 7 ? points.length : 6;
    final interval = points.length <= 1 ? 1.0 : maxX / (tickCount - 1);

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: NeyvoColors.borderSubtle.withOpacity(0.6),
              strokeWidth: 1,
            ),
            getDrawingVerticalLine: (value) => FlLine(
              color: NeyvoColors.borderSubtle.withOpacity(0.6),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 11, color: NeyvoColors.textMuted),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  final idx = value.round();
                  if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                  final date = points[idx].date;
                  final short = date.length >= 10 ? date.substring(0, 10) : date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      short,
                      style: const TextStyle(fontSize: 10, color: NeyvoColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              barWidth: 3,
              color: NeyvoColors.ubLightBlue,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: NeyvoColors.ubLightBlue,
                  strokeWidth: 2,
                  strokeColor: NeyvoColors.bgBase,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

