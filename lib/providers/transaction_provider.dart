import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction_entry.dart';
import '../services/firestore_service.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._firestoreService);

  final FirestoreService _firestoreService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<TransactionEntry>>? _transactionSubscription;
  String? _boundUid;

  List<TransactionEntry> _transactions = <TransactionEntry>[];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<TransactionEntry> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get uid => _boundUid;

  void bindToUser(String uid) {
    if (_boundUid == uid && _transactionSubscription != null) {
      return;
    }

    _transactionSubscription?.cancel();
    _boundUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _transactionSubscription = _firestoreService
        .watchTransactions(uid)
        .listen(
          (List<TransactionEntry> entries) {
            _transactions = entries;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _errorMessage = _friendlyErrorMessage(
              error,
              fallback: 'Failed to load transactions.',
            );
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<bool> addTransaction({
    required double amount,
    required String category,
    required String note,
    required DateTime date,
    required TransactionType type,
  }) async {
    final String? currentUid = _boundUid;
    if (currentUid == null) {
      _errorMessage = 'Please log in again and retry.';
      notifyListeners();
      return false;
    }

    final TransactionEntry entry = TransactionEntry(
      id: _uuid.v4(),
      amount: amount,
      category: category,
      note: note,
      date: date,
      type: type,
    );

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.addTransaction(currentUid, entry);
      // Optimistic update so the list reflects immediately even before
      // stream round-trip completes.
      _transactions = <TransactionEntry>[entry, ..._transactions]
        ..sort((TransactionEntry a, TransactionEntry b) {
          return b.date.compareTo(a.date);
        });
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to save transaction.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    final String? currentUid = _boundUid;
    if (currentUid == null) {
      _errorMessage = 'Please log in again and retry.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteTransaction(currentUid, transactionId);
      _transactions = _transactions
          .where((TransactionEntry entry) => entry.id != transactionId)
          .toList();
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to delete transaction.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  double get totalIncome => _transactions
      .where((TransactionEntry e) => e.type == TransactionType.income)
      .fold(0, (double sum, TransactionEntry e) => sum + e.amount);

  double get totalExpense => _transactions
      .where((TransactionEntry e) => e.type == TransactionType.expense)
      .fold(0, (double sum, TransactionEntry e) => sum + e.amount);

  double get balance => totalIncome - totalExpense;

  List<TransactionEntry> get recentTransactions {
    final List<TransactionEntry> sorted =
        List<TransactionEntry>.from(_transactions)
          ..sort((TransactionEntry a, TransactionEntry b) {
            return b.date.compareTo(a.date);
          });
    return sorted.take(10).toList();
  }

  Map<int, double> monthlyExpenseTotalsForCurrentYear() {
    final int currentYear = DateTime.now().year;
    final Map<int, double> monthlyTotals = <int, double>{
      for (int month = 1; month <= 12; month++) month: 0,
    };

    for (final TransactionEntry entry in _transactions) {
      if (entry.type == TransactionType.expense &&
          entry.date.year == currentYear) {
        monthlyTotals[entry.date.month] =
            (monthlyTotals[entry.date.month] ?? 0) + entry.amount;
      }
    }

    return monthlyTotals;
  }

  Map<String, double> currentMonthExpenseByCategory() {
    final DateTime now = DateTime.now();
    final Map<String, double> categoryTotals = <String, double>{};

    for (final TransactionEntry entry in _transactions) {
      if (entry.type == TransactionType.expense &&
          entry.date.year == now.year &&
          entry.date.month == now.month) {
        categoryTotals[entry.category] =
            (categoryTotals[entry.category] ?? 0) + entry.amount;
      }
    }

    return categoryTotals;
  }

  double currentMonthExpenseTotal() {
    final DateTime now = DateTime.now();
    return _transactions
        .where((TransactionEntry e) {
          return e.type == TransactionType.expense &&
              e.date.year == now.year &&
              e.date.month == now.month;
        })
        .fold(0, (double sum, TransactionEntry e) => sum + e.amount);
  }

  double expenseTotalForDay(DateTime day) {
    return _transactions
        .where((TransactionEntry e) {
          return e.type == TransactionType.expense &&
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day;
        })
        .fold(0, (double sum, TransactionEntry e) => sum + e.amount);
  }

  void clear() {
    _transactionSubscription?.cancel();
    _transactionSubscription = null;
    _boundUid = null;
    _transactions = <TransactionEntry>[];
    _errorMessage = null;
    _isLoading = false;
    _isSubmitting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }

  String _friendlyErrorMessage(Object error, {required String fallback}) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied')) {
      return 'Permission denied. Update Firestore Rules to allow authenticated user access to their own data.';
    }
    if (raw.contains('unavailable')) {
      return 'Network unavailable. Check internet and retry.';
    }
    return fallback;
  }
}
