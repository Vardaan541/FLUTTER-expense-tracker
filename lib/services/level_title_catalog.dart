class LevelTitle {
  const LevelTitle({required this.label, required this.emoji});

  final String label;
  final String emoji;
}

class LevelTitleCatalog {
  LevelTitleCatalog._();

  static const int maxNamedLevel = 1000;
  static final List<LevelTitle> _titles = _buildTitles();

  static LevelTitle forLevel(int level) {
    if (level <= 0) {
      return _titles.first;
    }
    if (level > maxNamedLevel) {
      return _titles.last;
    }
    return _titles[level - 1];
  }

  static List<LevelTitle> _buildTitles() {
    const List<String> tiers = <String>[
      'Rookie',
      'Skilled',
      'Elite',
      'Master',
      'Mythic',
      'Legendary',
      'Ascended',
      'Transcendent',
      'Eternal',
      'Cosmic',
    ];
    const List<String> domains = <String>[
      'Coin',
      'Ledger',
      'Budget',
      'Pace',
      'Discipline',
      'Streak',
      'Momentum',
      'Wealth',
      'Savings',
      'Runway',
    ];
    const List<String> roles = <String>[
      'Scout',
      'Ranger',
      'Keeper',
      'Sentinel',
      'Guardian',
      'Captain',
      'Commander',
      'Warden',
      'Sovereign',
      'Oracle',
    ];
    const List<String> emojis = <String>[
      '🌱',
      '🪙',
      '📘',
      '⚔️',
      '🛡️',
      '🔥',
      '💎',
      '👑',
      '🚀',
      '🌌',
    ];

    final List<LevelTitle> titles = <LevelTitle>[];
    for (int i = 0; i < maxNamedLevel; i++) {
      final String tier = tiers[i ~/ 100];
      final String domain = domains[(i ~/ 10) % 10];
      final String role = roles[i % 10];
      final String emoji = emojis[i ~/ 100];
      titles.add(LevelTitle(label: '$tier $domain $role', emoji: emoji));
    }
    return titles;
  }
}
