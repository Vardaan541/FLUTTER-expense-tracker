import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/budget_config.dart';
import '../models/transaction_entry.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/app_card.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final TextEditingController _monthlyLimitController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers =
      <String, TextEditingController>{};

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    for (final String category in TransactionEntry.expenseCategories) {
      _categoryControllers[category] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _monthlyLimitController.dispose();
    for (final TextEditingController controller
        in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _prefill(BudgetConfig budget) {
    if (_isInitialized) {
      return;
    }

    _monthlyLimitController.text = budget.monthlyLimit > 0
        ? budget.monthlyLimit.toString()
        : '';

    for (final String category in TransactionEntry.expenseCategories) {
      final double limit = budget.categoryLimits[category] ?? 0;
      _categoryControllers[category]!.text = limit > 0 ? limit.toString() : '';
    }

    _isInitialized = true;
  }

  Future<void> _saveBudget(BudgetProvider budgetProvider) async {
    final Map<String, double> categoryLimits = <String, double>{};

    for (final MapEntry<String, TextEditingController> entry
        in _categoryControllers.entries) {
      final double value = double.tryParse(entry.value.text.trim()) ?? 0;
      if (value > 0) {
        categoryLimits[entry.key] = value;
      }
    }

    final double monthlyLimit =
        double.tryParse(_monthlyLimitController.text.trim()) ?? 0;

    final BudgetConfig config = BudgetConfig(
      monthlyLimit: monthlyLimit,
      categoryLimits: categoryLimits,
    );

    final bool success = await budgetProvider.saveBudget(config);
    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            budgetProvider.errorMessage ?? 'Failed to save budget settings',
          ),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Budget settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currency = NumberFormat.currency(symbol: '₹');

    return Consumer2<BudgetProvider, TransactionProvider>(
      builder:
          (
            BuildContext context,
            BudgetProvider budgetProvider,
            TransactionProvider transactionProvider,
            Widget? child,
          ) {
            final BudgetConfig budget = budgetProvider.budget;
            _prefill(budget);

            final double monthSpent = transactionProvider
                .currentMonthExpenseTotal();
            final bool exceeded = budgetProvider.isMonthlyBudgetExceeded(
              monthSpent,
            );
            final double progress = budgetProvider.monthlyUsagePercent(
              monthSpent,
            );

            final Map<String, double> monthByCategory = transactionProvider
                .currentMonthExpenseByCategory();
            final Map<String, bool> overLimitByCategory = budgetProvider
                .categoryOverLimit(monthByCategory);

            if (budgetProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: <Widget>[
                if (budgetProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      budgetProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Monthly Budget Overview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 10,
                        color: exceeded ? Colors.red : Colors.green,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Spent: ${currency.format(monthSpent)}${budget.monthlyLimit > 0 ? ' / ${currency.format(budget.monthlyLimit)}' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exceeded
                            ? 'Budget exceeded. Reduce non-essential spending.'
                            : 'You are on track this month.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: exceeded ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Set Limits',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _monthlyLimitController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monthly Total Budget',
                          hintText: 'e.g. 25000',
                          prefixIcon: Icon(Icons.savings_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Category Plans',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      for (final String category
                          in TransactionEntry.expenseCategories) ...<Widget>[
                        _CategoryBudgetTile(
                          category: category,
                          controller: _categoryControllers[category]!,
                          spent: monthByCategory[category] ?? 0,
                          spentText: currency.format(
                            monthByCategory[category] ?? 0,
                          ),
                          isOverLimit: overLimitByCategory[category] == true,
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: budgetProvider.isSubmitting
                      ? null
                      : () => _saveBudget(budgetProvider),
                  icon: budgetProvider.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    budgetProvider.isSubmitting
                        ? 'Saving...'
                        : 'Save Budget Settings',
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _CategoryBudgetTile extends StatelessWidget {
  const _CategoryBudgetTile({
    required this.category,
    required this.controller,
    required this.spent,
    required this.spentText,
    required this.isOverLimit,
  });

  final String category;
  final TextEditingController controller;
  final double spent;
  final String spentText;
  final bool isOverLimit;

  @override
  Widget build(BuildContext context) {
    final double limit = double.tryParse(controller.text.trim()) ?? 0;
    final double usage = limit <= 0 ? 0 : (spent / limit).clamp(0.0, 1.0);
    final Color progressColor = isOverLimit ? Colors.red : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: category,
            hintText: 'Optional',
            prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
            suffixIcon: isOverLimit
                ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                : null,
          ),
        ),
        if (spent > 0) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: usage,
            minHeight: 8,
            color: progressColor,
          ),
          const SizedBox(height: 4),
          Text(
            'Spent in $category: $spentText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isOverLimit
                  ? Colors.red
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
