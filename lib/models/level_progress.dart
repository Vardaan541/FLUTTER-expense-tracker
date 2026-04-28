class LevelProgress {
  LevelProgress({
    required this.levelPoints,
    required this.disciplineCombo,
    required this.streakDays,
    required this.bestStreak,
    required this.lastSyncDayKey,
    required this.lastSpendEventDayKey,
  });

  final int levelPoints;
  final int disciplineCombo;
  final int streakDays;
  final int bestStreak;
  final String? lastSyncDayKey;
  final String? lastSpendEventDayKey;

  factory LevelProgress.empty() {
    return LevelProgress(
      levelPoints: 0,
      disciplineCombo: 0,
      streakDays: 0,
      bestStreak: 0,
      lastSyncDayKey: null,
      lastSpendEventDayKey: null,
    );
  }

  LevelProgress copyWith({
    int? levelPoints,
    int? disciplineCombo,
    int? streakDays,
    int? bestStreak,
    String? lastSyncDayKey,
    String? lastSpendEventDayKey,
  }) {
    return LevelProgress(
      levelPoints: levelPoints ?? this.levelPoints,
      disciplineCombo: disciplineCombo ?? this.disciplineCombo,
      streakDays: streakDays ?? this.streakDays,
      bestStreak: bestStreak ?? this.bestStreak,
      lastSyncDayKey: lastSyncDayKey ?? this.lastSyncDayKey,
      lastSpendEventDayKey: lastSpendEventDayKey ?? this.lastSpendEventDayKey,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'levelPoints': levelPoints,
      'disciplineCombo': disciplineCombo,
      'streakDays': streakDays,
      'bestStreak': bestStreak,
      'lastSyncDayKey': lastSyncDayKey,
      'lastSpendEventDayKey': lastSpendEventDayKey,
    };
  }

  factory LevelProgress.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return LevelProgress.empty();
    }
    return LevelProgress(
      levelPoints: (data['levelPoints'] as num?)?.toInt() ?? 0,
      disciplineCombo: (data['disciplineCombo'] as num?)?.toInt() ?? 0,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      bestStreak: (data['bestStreak'] as num?)?.toInt() ?? 0,
      lastSyncDayKey: data['lastSyncDayKey'] as String?,
      lastSpendEventDayKey: data['lastSpendEventDayKey'] as String?,
    );
  }
}
