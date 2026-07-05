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

  DateTime get lastPayday {
    final now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, payday);
    if (candidate.isAfter(now)) {
      final prev = DateTime(now.year, now.month - 1, 1);
      final lastDayPrev = DateTime(now.year, now.month, 0).day;
      final day = payday.clamp(1, lastDayPrev);
      candidate = DateTime(prev.year, prev.month, day);
    }
    return candidate;
  }

  DateTime get nextPayday {
    final now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, payday);
    if (!candidate.isAfter(now)) {
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
    name: (json['name'] as String?)?.trim() ?? '',
    salary: (json['salary'] as num?)?.toDouble() ?? 0.0,
    payday: (json['payday'] as num?)?.toInt() ?? 1,
    fixedBills: (json['fixedBills'] as num?)?.toDouble() ?? 0.0,
    savingsGoal: (json['savingsGoal'] as num?)?.toDouble() ?? 0.0,
    currency: json['currency'] as String? ?? 'EGP',
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
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

