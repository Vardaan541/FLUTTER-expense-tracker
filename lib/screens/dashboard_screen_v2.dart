import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/level_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/monthly_spending_chart.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<TransactionProvider, BudgetProvider, LevelProvider>(
      builder: (
        BuildContext context,
        TransactionProvider transactionProvider,
        BudgetProvider budgetProvider,
        LevelProvider levelProvider,
        Widget? child,
      ) {
        if (transactionProvider.isLoading ||
            budgetProvider.isLoading ||
            levelProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final double monthSpent = transactionProvider.currentMonthExpenseTotal();
        final Map<String, double> categorySpent = transactionProvider
            .currentMonthExpenseByCategory();
        final DateTime now = DateTime.now();
        final int dayOfMonth = now.day;
        final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final double currentDailyBurn = dayOfMonth == 0 ? 0 : monthSpent / dayOfMonth;
        final double rolling7DayBurn = _rollingDailyBurn(
          transactionProvider: transactionProvider,
          endingDate: now,
          windowDays: 7,
        );
        final double budgetLimit = budgetProvider.budget.monthlyLimit;
        final bool hasBudget = budgetLimit > 0;
        final double safeDailyBurn = hasBudget ? budgetLimit / daysInMonth : 0;
        final double spendingAtSafePacePercent = safeDailyBurn == 0
            ? 0
            : (currentDailyBurn / safeDailyBurn) * 100;
        final double projectedMonthSpend = currentDailyBurn * daysInMonth;
        final NumberFormat currency = NumberFormat.currency(symbol: '₹');
        final int level = levelProvider.currentLevel;
        final String levelTitle = levelProvider.currentLevelTitle.label;
        final String emoji = levelProvider.currentLevelTitle.emoji;
        final int points = levelProvider.levelProgress.levelPoints;
        final int pointsInLevel = points % 100;
        final int pointsToNext = 100 - pointsInLevel;
        final double levelProgress = pointsInLevel / 100;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$emoji Level $level',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(levelTitle),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: levelProgress, minHeight: 8),
                  const SizedBox(height: 6),
                  Text('$pointsInLevel/100 points • $pointsToNext to next level'),
                  const SizedBox(height: 8),
                  Text('1000 unique level titles available'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Daily Burn Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Run-rate model: projected spend = current daily burn x days in month',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _MetricPill(
                        label: 'Current Burn',
                        value: currency.format(currentDailyBurn),
                      ),
                      _MetricPill(
                        label: '7-Day Burn',
                        value: currency.format(rolling7DayBurn),
                      ),
                      _MetricPill(
                        label: 'Safe Burn',
                        value: hasBudget
                            ? currency.format(safeDailyBurn)
                            : 'Set budget',
                      ),
                      _MetricPill(
                        label: 'Spending at % of safe pace',
                        value: hasBudget
                            ? '${spendingAtSafePacePercent.toStringAsFixed(1)}%'
                            : 'NA',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: hasBudget
                        ? (spendingAtSafePacePercent / 200).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 9,
                    color: spendingAtSafePacePercent <= 100
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasBudget
                        ? 'Projected month spend: ${currency.format(projectedMonthSpend)} | Budget: ${currency.format(budgetLimit)}'
                        : 'Set monthly budget to activate safe-burn comparison.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: SummaryCard(
                    title: 'Spent This Month',
                    value: monthSpent,
                    icon: Icons.payments_outlined,
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Total Balance Remaining',
                    value: transactionProvider.balance,
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CategoryAnalyticsCard(
              categorySpent: categorySpent,
              totalSpent: monthSpent,
            ),
            const SizedBox(height: 12),
            MonthlySpendingChart(
              monthlyTotals: transactionProvider.monthlyExpenseTotalsForCurrentYear(),
            ),
          ],
        );
      },
    );
  }

  double _rollingDailyBurn({
    required TransactionProvider transactionProvider,
    required DateTime endingDate,
    required int windowDays,
  }) {
    double total = 0;
    for (int i = 0; i < windowDays; i++) {
      final DateTime day = endingDate.subtract(Duration(days: i));
      total += transactionProvider.expenseTotalForDay(day);
    }
    return total / windowDays;
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CategoryAnalyticsCard extends StatelessWidget {
  const _CategoryAnalyticsCard({
    required this.categorySpent,
    required this.totalSpent,
  });

  final Map<String, double> categorySpent;
  final double totalSpent;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currency = NumberFormat.currency(symbol: '₹');
    final List<MapEntry<String, double>> sorted = categorySpent.entries
        .where((MapEntry<String, double> entry) => entry.value > 0)
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) {
        return b.value.compareTo(a.value);
      });

    final List<Color> palette = <Color>[
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Category Spend Distribution',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Share per category for current month',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Text('No category expense data available yet.')
          else ...<Widget>[
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 44,
                  sections: List<PieChartSectionData>.generate(sorted.length, (
                    int index,
                  ) {
                    final MapEntry<String, double> entry = sorted[index];
                    final double share = totalSpent <= 0
                        ? 0
                        : (entry.value / totalSpent).clamp(0.0, 1.0);
                    return PieChartSectionData(
                      value: entry.value,
                      color: palette[index % palette.length],
                      title: '${(share * 100).toStringAsFixed(0)}%',
                      radius: 56,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...List<Widget>.generate(sorted.length, (int index) {
              final MapEntry<String, double> entry = sorted[index];
              final double share = totalSpent <= 0
                  ? 0
                  : (entry.value / totalSpent).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette[index % palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(entry.key)),
                    Text(
                      '${currency.format(entry.value)} (${(share * 100).toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
