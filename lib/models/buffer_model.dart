class BufferModel {
  final double amount;
  final DateTime lastUpdated;

  const BufferModel({
    required this.amount,
    required this.lastUpdated,
  });

  BufferModel copyWith({double? amount, DateTime? lastUpdated}) => BufferModel(
        amount: amount ?? this.amount,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory BufferModel.fromJson(Map<String, dynamic> json) => BufferModel(
        amount: (json['amount'] as num).toDouble(),
        lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      );

  factory BufferModel.empty() =>
      BufferModel(amount: 0.0, lastUpdated: DateTime.now());
}

