import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/level_progress.dart';
import '../services/firestore_service.dart';
import '../services/level_title_catalog.dart';

class LevelGameFeedback {
  const LevelGameFeedback({
    required this.title,
    required this.message,
    required this.emoji,
    required this.pointsDelta,
    required this.combo,
    required this.level,
    required this.levelDelta,
    required this.pointsToNextLevel,
    required this.levelTitle,
  });

  final String title;
  final String message;
  final String emoji;
  final int pointsDelta;
  final int combo;
  final int level;
  final int levelDelta;
  final int pointsToNextLevel;
  final LevelTitle levelTitle;
}

class LevelProvider extends ChangeNotifier {
  LevelProvider(this._firestoreService);

  final FirestoreService _firestoreService;
  static const int _pointsPerLevel = 100;

  StreamSubscription<LevelProgress>? _levelSubscription;
  String? _boundUid;

  LevelProgress _level = LevelProgress.empty();
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  LevelProgress get levelProgress => _level;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  int get currentLevel => _levelForPoints(_level.levelPoints);
  LevelTitle get currentLevelTitle => LevelTitleCatalog.forLevel(currentLevel);

  void bindToUser(String uid) {
    if (_boundUid == uid && _levelSubscription != null) {
      return;
    }

    _levelSubscription?.cancel();
    _boundUid = uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _levelSubscription = _firestoreService.watchLevelProgress(uid).listen(
      (LevelProgress levelProgress) {
        _level = levelProgress;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = _friendlyErrorMessage(
          error,
          fallback: 'Failed to load level progress.',
        );
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<LevelGameFeedback?> applyExpenseEvent({
    required double amount,
    required String category,
  }) async {
    final String? currentUid = _boundUid;
    if (currentUid == null) {
      return null;
    }

    final DateTime now = DateTime.now();
    final String todayKey = _dayKey(now);
    const double spendThreshold = 200;
    final bool disciplinedSpend = amount <= spendThreshold;
    final int nextCombo = disciplinedSpend ? _level.disciplineCombo + 1 : 0;
    final ({int streakDays, int bestStreak}) streakState = _resolveStreakState(
      lastTrackedDayKey: _level.lastSyncDayKey,
      todayKey: todayKey,
      currentStreak: _level.streakDays,
      bestStreak: _level.bestStreak,
      successForToday: disciplinedSpend,
    );

    int pointsDelta = 0;
    String title = 'Level Log Updated';
    String message = 'Progress recalculated for this expense.';
    String emoji = '📘';

    if (disciplinedSpend) {
      pointsDelta = 8 + nextCombo.clamp(0, 6) * 2;
      title = 'Discipline Win x$nextCombo';
      message =
          'Great control on $category (${amount.toStringAsFixed(0)}). +$pointsDelta points for keeping spend at or below ₹200.';
      emoji = '🎯';
    } else {
      final int overshoot = (amount - spendThreshold).toInt();
      pointsDelta = -(6 + (overshoot / 100).floor().clamp(0, 10));
      title = 'Overspend Hit';
      message =
          'Spent above ₹200 on $category (${amount.toStringAsFixed(0)}). ${pointsDelta.abs()} points deducted. Next low spend can recover momentum.';
      emoji = '🔥';
    }

    final int previousPoints = _level.levelPoints;
    final int updatedPoints = (_level.levelPoints + pointsDelta).clamp(0, 200000);
    final int previousLevel = _levelForPoints(previousPoints);
    final int currentLevel = _levelForPoints(updatedPoints);
    final int levelDelta = currentLevel - previousLevel;

    final LevelProgress updated = _level.copyWith(
      levelPoints: updatedPoints,
      disciplineCombo: nextCombo,
      streakDays: streakState.streakDays,
      bestStreak: streakState.bestStreak,
      lastSyncDayKey: todayKey,
      lastSpendEventDayKey: todayKey,
    );

    _isSubmitting = true;
    notifyListeners();
    try {
      await _firestoreService.saveLevelProgress(currentUid, updated);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = _friendlyErrorMessage(
        error,
        fallback: 'Failed to save level progress.',
      );
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }

    return LevelGameFeedback(
      title: title,
      message: message,
      emoji: emoji,
      pointsDelta: pointsDelta,
      combo: nextCombo,
      level: currentLevel,
      levelDelta: levelDelta,
      pointsToNextLevel: _pointsToNextLevel(updatedPoints),
      levelTitle: LevelTitleCatalog.forLevel(currentLevel),
    );
  }

  int _levelForPoints(int points) => (points ~/ _pointsPerLevel) + 1;

  int _pointsToNextLevel(int points) {
    final int progressInLevel = points % _pointsPerLevel;
    return _pointsPerLevel - progressInLevel;
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
    _levelSubscription?.cancel();
    _levelSubscription = null;
    _boundUid = null;
    _level = LevelProgress.empty();
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _levelSubscription?.cancel();
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
