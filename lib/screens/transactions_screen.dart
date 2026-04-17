import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_entry.dart';
import '../providers/transaction_provider.dart';

enum TransactionFilter { all, income, expense }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TransactionFilter _filter = TransactionFilter.all;

  List<TransactionEntry> _filteredTransactions(List<TransactionEntry> entries) {
    switch (_filter) {
      case TransactionFilter.income:
        return entries
            .where((TransactionEntry e) => e.type == TransactionType.income)
            .toList();
      case TransactionFilter.expense:
        return entries
            .where((TransactionEntry e) => e.type == TransactionType.expense)
            .toList();
      case TransactionFilter.all:
        return entries;
    }
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currency = NumberFormat.currency(symbol: '₹');
    final DateFormat dateFormat = DateFormat('dd MMM yyyy');

    return Consumer<TransactionProvider>(
      builder:
          (
            BuildContext context,
            TransactionProvider transactionProvider,
            Widget? child,
          ) {
            final List<TransactionEntry> entries = _filteredTransactions(
              transactionProvider.transactions,
            );

            if (transactionProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (transactionProvider.errorMessage != null &&
                transactionProvider.transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    transactionProvider.errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Column(
              children: <Widget>[
                if (transactionProvider.isSubmitting)
                  const LinearProgressIndicator(minHeight: 2),
                if (transactionProvider.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Text(
                      transactionProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == TransactionFilter.all,
                        onSelected: (_) {
                          setState(() {
                            _filter = TransactionFilter.all;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _filter == TransactionFilter.income,
                        onSelected: (_) {
                          setState(() {
                            _filter = TransactionFilter.income;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Expense'),
                        selected: _filter == TransactionFilter.expense,
                        onSelected: (_) {
                          setState(() {
                            _filter = TransactionFilter.expense;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            'No transactions yet. Add your first one from Add tab.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          itemCount: entries.length,
                          itemBuilder: (BuildContext context, int index) {
                            final TransactionEntry entry = entries[index];
                            final bool isIncome =
                                entry.type == TransactionType.income;
                            final Color amountColor = isIncome
                                ? Colors.green
                                : Colors.red;

                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: amountColor.withValues(
                                    alpha: 0.14,
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: amountColor,
                                  ),
                                ),
                                title: Text(entry.category),
                                subtitle: Text(
                                  '${entry.note.isEmpty ? 'No note' : entry.note}\n${dateFormat.format(entry.date)}',
                                ),
                                isThreeLine: true,
                                trailing: SizedBox(
                                  width: 92,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text(
                                        '${isIncome ? '+' : '-'}${currency.format(entry.amount)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: amountColor,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final TransactionProvider provider =
                                              context
                                                  .read<TransactionProvider>();
                                          final bool success =
                                              await provider.deleteTransaction(
                                                entry.id,
                                              );
                                          if (!context.mounted || success) {
                                            return;
                                          }
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                provider.errorMessage ??
                                                    'Failed to delete transaction.',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                        ),
                                        tooltip: 'Delete',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
    );
  }
}
