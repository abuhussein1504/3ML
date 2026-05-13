/// Money carried from days you spent less than your daily pace (plus manual edits).
/// It is excluded from the pace split so it is not averaged again; add it to today’s pace for spending room.
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
