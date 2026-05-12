class UserProfile {
  final String name;
  final double salary;
  final int payday;       // day of month 1–28
  final double fixedBills;
  final double savingsGoal;
  final String currency;
  final DateTime createdAt;

  UserProfile({
    required this.name,
    required this.salary,
    required this.payday,
    required this.fixedBills,
    required this.savingsGoal,
    this.currency = 'EGP',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get disposableIncome => salary - fixedBills - savingsGoal;

  /// Last payday date (most recent occurrence before or on today)
  DateTime get lastPayday {
    final now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, payday);
    if (candidate.isAfter(now)) {
      // Payday hasn't hit this month yet → use last month
      final prev = DateTime(now.year, now.month - 1, 1);
      final lastDayPrev = DateTime(now.year, now.month, 0).day;
      final day = payday.clamp(1, lastDayPrev);
      candidate = DateTime(prev.year, prev.month, day);
    }
    return candidate;
  }

  /// Next payday date
  DateTime get nextPayday {
    final now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, payday);
    if (!candidate.isAfter(now)) {
      // Payday already passed this month → next month
      final next = DateTime(now.year, now.month + 1, 1);
      final lastDayNext = DateTime(now.year, now.month + 2, 0).day;
      final day = payday.clamp(1, lastDayNext);
      candidate = DateTime(next.year, next.month, day);
    }
    return candidate;
  }

  int get daysUntilPayday {
    final diff = nextPayday.difference(DateTime.now());
    return (diff.inDays + 1).clamp(0, 365);
  }

  int get totalDaysInPeriod {
    final days = nextPayday.difference(lastPayday).inDays;
    return days > 0 ? days : 1; // never 0 — prevents division by zero
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'salary': salary,
    'payday': payday,
    'fixedBills': fixedBills,
    'savingsGoal': savingsGoal,
    'currency': currency,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String,
    salary: (json['salary'] as num).toDouble(),
    payday: json['payday'] as int,
    fixedBills: (json['fixedBills'] as num).toDouble(),
    savingsGoal: (json['savingsGoal'] as num).toDouble(),
    currency: json['currency'] as String? ?? 'EGP',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );

  UserProfile copyWith({
    String? name,
    double? salary,
    int? payday,
    double? fixedBills,
    double? savingsGoal,
    String? currency,
  }) =>
      UserProfile(
        name: name ?? this.name,
        salary: salary ?? this.salary,
        payday: payday ?? this.payday,
        fixedBills: fixedBills ?? this.fixedBills,
        savingsGoal: savingsGoal ?? this.savingsGoal,
        currency: currency ?? this.currency,
        createdAt: createdAt,
      );
}
