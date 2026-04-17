import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/budget_config.dart';
import '../services/firestore_service.dart';

class BudgetProvider extends ChangeNotifier {
  BudgetProvider(this._firestoreService);

  final FirestoreService _firestoreService;

  StreamSubscription<BudgetConfig>? _budgetSubscription;
  String? _boundUid;

  BudgetConfig _budget = BudgetConfig.empty();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  BudgetConfig get budget => _budget;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void bindToUser(String uid) {
    if (_boundUid == uid && _budgetSubscription != null) {
      return;
    }

    _budgetSubscription?.cancel();
    _boundUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _budgetSubscription = _firestoreService
        .watchBudget(uid)
        .listen(
          (BudgetConfig budget) {
            _budget = budget;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error) {
            _errorMessage = _friendlyErrorMessage(
              error,
              fallback: 'Failed to load budget settings.',
            );
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<bool> saveBudget(BudgetConfig budget) async {
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
      await _firestoreService.saveBudget(currentUid, budget);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to save budget settings.',
      );
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  bool isMonthlyBudgetExceeded(double spentThisMonth) {
    if (_budget.monthlyLimit <= 0) {
      return false;
    }
    return spentThisMonth > _budget.monthlyLimit;
  }

  double monthlyUsagePercent(double spentThisMonth) {
    if (_budget.monthlyLimit <= 0) {
      return 0;
    }
    return (spentThisMonth / _budget.monthlyLimit).clamp(0, 2);
  }

  Map<String, bool> categoryOverLimit(Map<String, double> categorySpent) {
    final Map<String, bool> result = <String, bool>{};

    for (final MapEntry<String, double> entry in categorySpent.entries) {
      final double limit = _budget.categoryLimits[entry.key] ?? 0;
      result[entry.key] = limit > 0 && entry.value > limit;
    }

    return result;
  }

  void clear() {
    _budgetSubscription?.cancel();
    _budgetSubscription = null;
    _boundUid = null;
    _budget = BudgetConfig.empty();
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _budgetSubscription?.cancel();
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
