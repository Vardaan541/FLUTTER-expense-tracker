class BudgetConfig {
  BudgetConfig({required this.monthlyLimit, required this.categoryLimits});

  final double monthlyLimit;
  final Map<String, double> categoryLimits;

  factory BudgetConfig.empty() {
    return BudgetConfig(monthlyLimit: 0, categoryLimits: <String, double>{});
  }

  BudgetConfig copyWith({
    double? monthlyLimit,
    Map<String, double>? categoryLimits,
  }) {
    return BudgetConfig(
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      categoryLimits: categoryLimits ?? this.categoryLimits,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'monthlyLimit': monthlyLimit,
      'categoryLimits': categoryLimits,
    };
  }

  factory BudgetConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return BudgetConfig.empty();
    }

    final Map<String, dynamic> rawLimits =
        (data['categoryLimits'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return BudgetConfig(
      monthlyLimit: (data['monthlyLimit'] as num?)?.toDouble() ?? 0,
      categoryLimits: rawLimits.map(
        (String key, dynamic value) =>
            MapEntry<String, double>(key, (value as num?)?.toDouble() ?? 0),
      ),
    );
  }
}
