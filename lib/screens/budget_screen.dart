import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/budget_config.dart';
import '../models/transaction_entry.dart';
import '../providers/budget_provider.dart';
import '../providers/transaction_provider.dart';

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
              padding: const EdgeInsets.all(16),
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
                Text(
                  'Monthly Budget Overview',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress <= 0 ? 0 : (progress > 1 ? 1 : progress),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                  color: exceeded ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 8),
                Text(
                  'Spent this month: ${currency.format(monthSpent)}'
                  '${budget.monthlyLimit > 0 ? ' / ${currency.format(budget.monthlyLimit)}' : ''}',
                ),
                if (exceeded)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Alert: Monthly budget exceeded',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _monthlyLimitController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly Total Budget',
                    hintText: 'e.g. 25000',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Category Limits',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final String category
                    in TransactionEntry.expenseCategories) ...<Widget>[
                  TextFormField(
                    controller: _categoryControllers[category],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: '$category Limit',
                      hintText: 'Optional',
                      border: const OutlineInputBorder(),
                      suffixIcon: overLimitByCategory[category] == true
                          ? const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red,
                            )
                          : null,
                    ),
                  ),
                  if ((monthByCategory[category] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        'Spent in $category: ${currency.format(monthByCategory[category] ?? 0)}',
                        style: TextStyle(
                          color: overLimitByCategory[category] == true
                              ? Colors.red
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
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
                      : const Icon(Icons.save),
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
