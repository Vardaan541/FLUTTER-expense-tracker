import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction_entry.dart';
import '../providers/transaction_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state_card.dart';

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
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Text(
                      transactionProvider.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      _FilterChip(
                        label: 'All',
                        selected: _filter == TransactionFilter.all,
                        onTap: () {
                          setState(() {
                            _filter = TransactionFilter.all;
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Income',
                        selected: _filter == TransactionFilter.income,
                        onTap: () {
                          setState(() {
                            _filter = TransactionFilter.income;
                          });
                        },
                      ),
                      _FilterChip(
                        label: 'Expense',
                        selected: _filter == TransactionFilter.expense,
                        onTap: () {
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
                      ? const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
                          child: EmptyStateCard(
                            title: 'No transactions yet',
                            subtitle:
                                'Your transaction history will show here after you add an entry.',
                            icon: Icons.receipt_long_rounded,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: entries.length,
                          itemBuilder: (BuildContext context, int index) {
                            final TransactionEntry entry = entries[index];
                            final bool isIncome =
                                entry.type == TransactionType.income;
                            final Color amountColor = isIncome
                                ? Colors.green
                                : Colors.red;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    CircleAvatar(
                                      radius: 20,
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
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            entry.category,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.note.isEmpty
                                                ? 'No note'
                                                : entry.note,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dateFormat.format(entry.date),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: <Widget>[
                                        Text(
                                          '${isIncome ? '+' : '-'}${currency.format(entry.amount)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: amountColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        IconButton(
                                          onPressed: () async {
                                            final TransactionProvider
                                            provider = context
                                                .read<TransactionProvider>();
                                            final bool success = await provider
                                                .deleteTransaction(entry.id);
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
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                          ),
                                          tooltip: 'Delete',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                  ],
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: selected
          ? Icon(Icons.check_rounded, size: 16, color: scheme.primary)
          : null,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.78),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      selectedColor: scheme.primary.withValues(alpha: 0.15),
    );
  }
}
