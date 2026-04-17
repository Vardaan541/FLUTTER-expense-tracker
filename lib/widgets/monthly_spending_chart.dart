import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MonthlySpendingChart extends StatelessWidget {
  const MonthlySpendingChart({super.key, required this.monthlyTotals});

  final Map<int, double> monthlyTotals;

  @override
  Widget build(BuildContext context) {
    final double maxY = _maxYValue(monthlyTotals);

    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: List<BarChartGroupData>.generate(12, (int index) {
            final int month = index + 1;
            final double value = monthlyTotals[month] ?? 0;
            return BarChartGroupData(
              x: month,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: value,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            );
          }),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const List<String> labels = <String>[
                    'J',
                    'F',
                    'M',
                    'A',
                    'M',
                    'J',
                    'J',
                    'A',
                    'S',
                    'O',
                    'N',
                    'D',
                  ];
                  final int monthIndex = value.toInt() - 1;
                  if (monthIndex < 0 || monthIndex > 11) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(labels[monthIndex]),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _maxYValue(Map<int, double> totals) {
    final double maxValue = totals.values.fold(0, (double a, double b) {
      return a > b ? a : b;
    });
    if (maxValue <= 0) {
      return 100;
    }
    return maxValue * 1.25;
  }
}
