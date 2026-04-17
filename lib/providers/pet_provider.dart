import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pet_progress.dart';
import '../services/firestore_service.dart';

class SpendGameFeedback {
  const SpendGameFeedback({
    required this.title,
    required this.message,
    required this.emoji,
    required this.coinsDelta,
    required this.combo,
  });

  final String title;
  final String message;
  final String emoji;
  final int coinsDelta;
  final int combo;
}

class PetProvider extends ChangeNotifier {
  PetProvider(this._firestoreService);

  final FirestoreService _firestoreService;

  StreamSubscription<PetProgress>? _petSubscription;
  String? _boundUid;
  String _lastSyncSignature = '';

  PetProgress _pet = PetProgress.empty();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  PetProgress get pet => _pet;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  void bindToUser(String uid) {
    if (_boundUid == uid && _petSubscription != null) {
      return;
    }

    _petSubscription?.cancel();
    _boundUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _petSubscription = _firestoreService.watchPetProgress(uid).listen(
      (PetProgress pet) {
        _pet = pet;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = _friendlyErrorMessage(
          error,
          fallback: 'Failed to load pet progress.',
        );
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> syncProjection({
    required double projectedMonthSpend,
    required double budgetLimit,
    required int score,
    required String stageKey,
  }) async {
    final String? currentUid = _boundUid;
    if (currentUid == null || budgetLimit <= 0) {
      return;
    }

    final String todayKey = _dayKey(DateTime.now());
    final String signature =
        '${projectedMonthSpend.toStringAsFixed(0)}|${budgetLimit.toStringAsFixed(0)}|$score|$stageKey|$todayKey|${_pet.lastSyncDayKey}|${_pet.streakDays}|${_pet.badges.length}|${_pet.unlockedSkins.length}';
    if (_lastSyncSignature == signature || _isSubmitting) {
      return;
    }
    _lastSyncSignature = signature;

    final bool isProjectedHealthy = projectedMonthSpend <= budgetLimit;
    final ({int streakDays, int bestStreak}) streakState = _resolveStreakState(
      lastTrackedDayKey: _pet.lastSyncDayKey,
      todayKey: todayKey,
      currentStreak: _pet.streakDays,
      bestStreak: _pet.bestStreak,
      successForToday: isProjectedHealthy,
    );
    final int streakDays = streakState.streakDays;
    final int bestStreak = streakState.bestStreak;

    final int streakBonus = (streakDays * 2).clamp(0, 20);
    final int currentXp = (score + streakBonus).clamp(0, 100);

    final Set<String> unlockedSkins = <String>{..._pet.unlockedSkins, 'turtle'};
    if (score >= 40) {
      unlockedSkins.add('hatchling');
    }
    if (score >= 65) {
      unlockedSkins.add('fox');
    }
    if (score >= 85) {
      unlockedSkins.add('dragon');
    }

    final Set<String> badges = <String>{..._pet.badges};
    badges.add('first_budget_pet');
    if (score >= 65) {
      badges.add('projection_guardian');
    }
    if (score >= 85) {
      badges.add('dragon_mode');
    }
    if (streakDays >= 3) {
      badges.add('streak_3');
    }
    if (streakDays >= 7) {
      badges.add('streak_7');
    }

    final String selectedSkin = _highestSkin(unlockedSkins);
    final PetProgress updated = _pet.copyWith(
      currentXp: currentXp,
      streakDays: streakDays,
      bestStreak: bestStreak,
      currentStage: stageKey,
      selectedSkin: selectedSkin,
      unlockedSkins: unlockedSkins.toList(),
      badges: badges.toList(),
      lastSyncDayKey: todayKey,
    );

    _isSubmitting = true;
    notifyListeners();
    try {
      await _firestoreService.savePetProgress(currentUid, updated);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to save pet progress.',
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<SpendGameFeedback?> applyExpenseEvent({
    required double amount,
    required double daySpentAfterTransaction,
    required double monthlyBudgetLimit,
    required String category,
  }) async {
    final String? currentUid = _boundUid;
    if (currentUid == null) {
      return null;
    }

    final DateTime now = DateTime.now();
    final String todayKey = _dayKey(now);
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final double dailyBudget = monthlyBudgetLimit > 0
        ? monthlyBudgetLimit / daysInMonth
        : 0;

    final bool hasBudget = dailyBudget > 0;
    final bool disciplinedSpend =
        hasBudget && daySpentAfterTransaction <= dailyBudget;
    final bool cautionSpend =
        hasBudget && daySpentAfterTransaction <= (dailyBudget * 1.25);

    final int nextCombo = disciplinedSpend ? _pet.disciplineCombo + 1 : 0;
    final ({int streakDays, int bestStreak}) streakState = _resolveStreakState(
      lastTrackedDayKey: _pet.lastSyncDayKey,
      todayKey: todayKey,
      currentStreak: _pet.streakDays,
      bestStreak: _pet.bestStreak,
      successForToday: disciplinedSpend,
    );
    int coinsDelta = 0;
    String title = 'Pet Log Updated';
    String message = 'Your pet tracked this expense.';
    String emoji = '🐢';

    if (!hasBudget) {
      coinsDelta = 1;
      title = 'Scout Quest';
      message = 'Expense logged. Set a budget to unlock combo multipliers.';
      emoji = '🧭';
    } else if (disciplinedSpend) {
      coinsDelta = 5 + nextCombo.clamp(0, 6) * 2;
      title = 'Perfect Spend Combo x$nextCombo';
      message =
          'Nice control on $category (${amount.toStringAsFixed(0)})! +$coinsDelta treat coins for spending within your daily lane.';
      emoji = '🎯';
    } else if (cautionSpend) {
      coinsDelta = 3;
      title = 'Caution Zone';
      message =
          'You are near your daily limit. Small choices now protect your combo.';
      emoji = '⚠️';
    } else {
      coinsDelta = 1;
      title = 'Overheat Alert';
      message =
          'Heavy spend detected. Regain momentum with a low-spend transaction next.';
      emoji = '🔥';
    }

    final Set<String> badges = <String>{..._pet.badges};
    if (nextCombo >= 3) {
      badges.add('combo_3');
    }
    if (nextCombo >= 5) {
      badges.add('combo_5');
    }
    if (_pet.petCoins + coinsDelta >= 100) {
      badges.add('coin_collector_100');
    }
    if (streakState.streakDays >= 3) {
      badges.add('streak_3');
    }
    if (streakState.streakDays >= 7) {
      badges.add('streak_7');
    }

    final PetProgress updated = _pet.copyWith(
      petCoins: _pet.petCoins + coinsDelta,
      disciplineCombo: nextCombo,
      streakDays: streakState.streakDays,
      bestStreak: streakState.bestStreak,
      badges: badges.toList(),
      lastSyncDayKey: todayKey,
      lastSpendEventDayKey: todayKey,
    );

    _isSubmitting = true;
    notifyListeners();
    try {
      await _firestoreService.savePetProgress(currentUid, updated);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to save spend game progress.',
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }

    return SpendGameFeedback(
      title: title,
      message: message,
      emoji: emoji,
      coinsDelta: coinsDelta,
      combo: nextCombo,
    );
  }

  String _highestSkin(Set<String> unlockedSkins) {
    if (unlockedSkins.contains('dragon')) {
      return 'dragon';
    }
    if (unlockedSkins.contains('fox')) {
      return 'fox';
    }
    if (unlockedSkins.contains('hatchling')) {
      return 'hatchling';
    }
    return 'turtle';
  }

  String _dayKey(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  ({int streakDays, int bestStreak}) _resolveStreakState({
    required String? lastTrackedDayKey,
    required String todayKey,
    required int currentStreak,
    required int bestStreak,
    required bool successForToday,
  }) {
    if (lastTrackedDayKey == todayKey) {
      final int streakDays = successForToday ? currentStreak : 0;
      return (
        streakDays: streakDays,
        bestStreak: streakDays > bestStreak ? streakDays : bestStreak,
      );
    }

    if (!successForToday) {
      return (streakDays: 0, bestStreak: bestStreak);
    }

    if (lastTrackedDayKey == null) {
      return (streakDays: 1, bestStreak: bestStreak > 1 ? bestStreak : 1);
    }

    final DateTime? lastDay = _parseDayKey(lastTrackedDayKey);
    final DateTime? today = _parseDayKey(todayKey);
    if (lastDay == null || today == null) {
      return (streakDays: 1, bestStreak: bestStreak > 1 ? bestStreak : 1);
    }

    final int gapDays = today.difference(lastDay).inDays;
    final int streakDays = gapDays == 1 ? currentStreak + 1 : 1;
    return (
      streakDays: streakDays,
      bestStreak: streakDays > bestStreak ? streakDays : bestStreak,
    );
  }

  DateTime? _parseDayKey(String dayKey) {
    final List<String> parts = dayKey.split('-');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  void clear() {
    _petSubscription?.cancel();
    _petSubscription = null;
    _boundUid = null;
    _pet = PetProgress.empty();
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    _lastSyncSignature = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _petSubscription?.cancel();
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
