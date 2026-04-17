import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_entry.dart';
import '../providers/budget_provider.dart';
import '../providers/pet_provider.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = TransactionEntry.expenseCategories.first;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _activeCategories {
    return _selectedType == TransactionType.expense
        ? TransactionEntry.expenseCategories
        : TransactionEntry.incomeCategories;
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount greater than 0')),
      );
      return;
    }

    final TransactionProvider transactionProvider =
        context.read<TransactionProvider>();
    final TransactionType selectedType = _selectedType;
    final String selectedCategory = _selectedCategory;
    final DateTime selectedDate = _selectedDate;
    final bool success = await transactionProvider.addTransaction(
      amount: amount,
      category: selectedCategory,
      note: _noteController.text.trim(),
      date: selectedDate,
      type: selectedType,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            transactionProvider.errorMessage ?? 'Failed to add transaction.',
          ),
        ),
      );
      return;
    }

    SpendGameFeedback? spendFeedback;
    if (selectedType == TransactionType.expense) {
      final double daySpentAfterTransaction = transactionProvider
          .expenseTotalForDay(selectedDate);
      final double monthlyBudgetLimit = context
          .read<BudgetProvider>()
          .budget
          .monthlyLimit;
      spendFeedback = await context.read<PetProvider>().applyExpenseEvent(
        amount: amount,
        daySpentAfterTransaction: daySpentAfterTransaction,
        monthlyBudgetLimit: monthlyBudgetLimit,
        category: selectedCategory,
      );
    }

    if (!mounted) {
      return;
    }

    _formKey.currentState?.reset();
    _amountController.clear();
    _noteController.clear();
    setState(() {
      _selectedType = TransactionType.expense;
      _selectedCategory = TransactionEntry.expenseCategories.first;
      _selectedDate = DateTime.now();
    });

    if (spendFeedback != null) {
      await _showSpendBattleOverlay(spendFeedback);
      if (!mounted) {
        return;
      }
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction added successfully')));
  }

  Future<void> _showSpendBattleOverlay(SpendGameFeedback feedback) async {
    if (!mounted) {
      return;
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color accent = _battleAccent(feedback.title, colorScheme);
    final Future<void> dialogFuture = showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Spend Battle',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: accent.withValues(alpha: 0.65),
                  width: 1.6,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 950),
                    tween: Tween<double>(begin: 0.85, end: 1.15),
                    curve: Curves.easeInOut,
                    builder:
                        (BuildContext context, double value, Widget? child) {
                          return Transform.scale(
                            scale: value,
                            child: Text(
                              feedback.emoji,
                              style: const TextStyle(fontSize: 46),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spend Battle',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      letterSpacing: 1.1,
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    feedback.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    feedback.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _BattleChip(
                        icon: Icons.monetization_on_rounded,
                        label: '+${feedback.coinsDelta} coins',
                      ),
                      const SizedBox(width: 8),
                      _BattleChip(
                        icon: Icons.bolt_rounded,
                        label: 'Combo ${feedback.combo}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.9,
                  end: 1,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                child: child,
              ),
            );
          },
    );

    await Future<void>.delayed(const Duration(seconds: 4));
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
  }

  Color _battleAccent(String title, ColorScheme colorScheme) {
    if (title.contains('Perfect')) {
      return Colors.green;
    }
    if (title.contains('Overheat')) {
      return Colors.red;
    }
    if (title.contains('Caution')) {
      return Colors.orange;
    }
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder:
          (
            BuildContext context,
            TransactionProvider transactionProvider,
            Widget? child,
          ) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (transactionProvider.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          transactionProvider.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
            SegmentedButton<TransactionType>(
              segments: const <ButtonSegment<TransactionType>>[
                ButtonSegment<TransactionType>(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment<TransactionType>(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: <TransactionType>{_selectedType},
              onSelectionChanged: (Set<TransactionType> selected) {
                setState(() {
                  _selectedType = selected.first;
                  _selectedCategory = _activeCategories.first;
                });
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'e.g. 499.99',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Amount is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              items: _activeCategories.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedCategory = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: transactionProvider.isSubmitting
                    ? null
                    : _saveTransaction,
                icon: transactionProvider.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  transactionProvider.isSubmitting
                      ? 'Saving...'
                      : 'Save Transaction',
                ),
              ),
            ),
                  ],
                ),
              ),
            );
          },
    );
  }
}

class _BattleChip extends StatelessWidget {
  const _BattleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
