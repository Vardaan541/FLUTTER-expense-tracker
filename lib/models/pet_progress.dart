class PetProgress {
  PetProgress({
    required this.currentXp,
    required this.petCoins,
    required this.streakDays,
    required this.bestStreak,
    required this.disciplineCombo,
    required this.currentStage,
    required this.selectedSkin,
    required this.unlockedSkins,
    required this.badges,
    required this.lastSyncDayKey,
    required this.lastSpendEventDayKey,
  });

  final int currentXp;
  final int petCoins;
  final int streakDays;
  final int bestStreak;
  final int disciplineCombo;
  final String currentStage;
  final String selectedSkin;
  final List<String> unlockedSkins;
  final List<String> badges;
  final String? lastSyncDayKey;
  final String? lastSpendEventDayKey;

  factory PetProgress.empty() {
    return PetProgress(
      currentXp: 0,
      petCoins: 0,
      streakDays: 0,
      bestStreak: 0,
      disciplineCombo: 0,
      currentStage: 'egg',
      selectedSkin: 'turtle',
      unlockedSkins: const <String>['turtle'],
      badges: const <String>[],
      lastSyncDayKey: null,
      lastSpendEventDayKey: null,
    );
  }

  PetProgress copyWith({
    int? currentXp,
    int? petCoins,
    int? streakDays,
    int? bestStreak,
    int? disciplineCombo,
    String? currentStage,
    String? selectedSkin,
    List<String>? unlockedSkins,
    List<String>? badges,
    String? lastSyncDayKey,
    String? lastSpendEventDayKey,
  }) {
    return PetProgress(
      currentXp: currentXp ?? this.currentXp,
      petCoins: petCoins ?? this.petCoins,
      streakDays: streakDays ?? this.streakDays,
      bestStreak: bestStreak ?? this.bestStreak,
      disciplineCombo: disciplineCombo ?? this.disciplineCombo,
      currentStage: currentStage ?? this.currentStage,
      selectedSkin: selectedSkin ?? this.selectedSkin,
      unlockedSkins: unlockedSkins ?? this.unlockedSkins,
      badges: badges ?? this.badges,
      lastSyncDayKey: lastSyncDayKey ?? this.lastSyncDayKey,
      lastSpendEventDayKey: lastSpendEventDayKey ?? this.lastSpendEventDayKey,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'currentXp': currentXp,
      'petCoins': petCoins,
      'streakDays': streakDays,
      'bestStreak': bestStreak,
      'disciplineCombo': disciplineCombo,
      'currentStage': currentStage,
      'selectedSkin': selectedSkin,
      'unlockedSkins': unlockedSkins,
      'badges': badges,
      'lastSyncDayKey': lastSyncDayKey,
      'lastSpendEventDayKey': lastSpendEventDayKey,
    };
  }

  factory PetProgress.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return PetProgress.empty();
    }

    return PetProgress(
      currentXp: (data['currentXp'] as num?)?.toInt() ?? 0,
      petCoins: (data['petCoins'] as num?)?.toInt() ?? 0,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      bestStreak: (data['bestStreak'] as num?)?.toInt() ?? 0,
      disciplineCombo: (data['disciplineCombo'] as num?)?.toInt() ?? 0,
      currentStage: (data['currentStage'] as String?) ?? 'egg',
      selectedSkin: (data['selectedSkin'] as String?) ?? 'turtle',
      unlockedSkins: (data['unlockedSkins'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toSet()
          .toList(),
      badges: (data['badges'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toSet()
          .toList(),
      lastSyncDayKey: data['lastSyncDayKey'] as String?,
      lastSpendEventDayKey: data['lastSpendEventDayKey'] as String?,
    );
  }
}
