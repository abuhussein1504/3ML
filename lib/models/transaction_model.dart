import '../data/items_db.dart';

class TransactionModel {
  final String id;
  final String rawInput;

  // From Model A
  /// Income | Expense | Unknown (legacy DB rows may still say Savings & Investment;
  /// [fromMap] maps those to Expense).
  final String transactionType;
  final String?
      intent; // expense | income | financial services | investment | unknown
  final String? item;
  final double? amount;
  final DateTime date;
  final String? dateExpression;

  /// Event parser / API: NO | item | amount | item & amount
  final String needsClarification;
  final double confidenceScore;

  // Categorization
  final String categoryName;

  // Metadata
  final DateTime createdAt;
  final Map<String, dynamic>? rawModelOutput;

  TransactionModel({
    required this.id,
    required this.rawInput,
    required this.transactionType,
    this.intent,
    this.item,
    this.amount,
    required this.date,
    this.dateExpression,
    this.needsClarification = 'NO',
    this.confidenceScore = 1.0,
    this.categoryName = 'other',
    DateTime? createdAt,
    this.rawModelOutput,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isExpense => transactionType == 'Expense';
  bool get isIncome => transactionType == 'Income';
  bool get isSavings => transactionType == 'Savings & Investment';
  bool get isUnknown => transactionType == 'Unknown';

  /// True when the parser still needs a field from the user.
  bool get hasClarificationNeeded {
    final n = needsClarification.trim().toUpperCase();
    return n.isNotEmpty && n != 'NO' && n != 'FALSE';
  }

  /// Legacy INTEGER column (1 = any clarification).
  int get needsClarificationAsInt => hasClarificationNeeded ? 1 : 0;

  TransactionModel copyWith({
    String? categoryName,
    double? amount,
    DateTime? date,
    String? intent,
    String? item,
    String? needsClarification,
  }) =>
      TransactionModel(
        id: id,
        rawInput: rawInput,
        transactionType: transactionType,
        intent: intent ?? this.intent,
        item: item ?? this.item,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        dateExpression: dateExpression,
        needsClarification: needsClarification ?? this.needsClarification,
        confidenceScore: confidenceScore,
        categoryName: categoryName ?? this.categoryName,
        createdAt: createdAt,
        rawModelOutput: rawModelOutput,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'rawInput': rawInput,
        'transactionType': transactionType,
        'intent': intent,
        'item': item,
        'amount': amount,
        'date': date.toIso8601String(),
        'dateExpression': dateExpression,
        'needsClarification': needsClarificationAsInt,
        'needsClarificationDetail': needsClarification,
        'confidenceScore': confidenceScore,
        'categoryName': categoryName,
        'createdAt': createdAt.toIso8601String(),
        'rawModelOutput':
            rawModelOutput != null ? _encodeMap(rawModelOutput!) : null,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as String,
        rawInput: map['rawInput'] as String,
        transactionType: _normalizeStoredTransactionType(
            map['transactionType'] as String? ?? 'Unknown'),
        intent: map['intent'] as String?,
        item: map['item'] as String?,
        amount:
            map['amount'] != null ? (map['amount'] as num).toDouble() : null,
        date: DateTime.parse(map['date'] as String),
        dateExpression: map['dateExpression'] as String?,
        needsClarification: _parseNeedsClarificationFromDb(map),
        confidenceScore: (map['confidenceScore'] as num? ?? 1.0).toDouble(),
        categoryName: map['categoryName'] as String? ?? 'other',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
        rawModelOutput: _decodeRaw(map['rawModelOutput'] as String?),
      );

  /// Prefer v2 TEXT column; fall back to legacy int; then raw model blob.
  static String _parseNeedsClarificationFromDb(Map<String, dynamic> map) {
    final detail = map['needsClarificationDetail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return normalizeClarificationLabel(detail);
    }
    final raw = map['needsClarification'];
    if (raw is String) return normalizeClarificationLabel(raw);
    if (raw is int) return raw == 1 ? 'item' : 'NO';
    if (raw is bool) return raw ? 'item' : 'NO';
    return 'NO';
  }

  /// Normalises parser / UI variants to API values: NO | item | amount | item & amount
  static String normalizeClarificationLabel(String raw) =>
      _normalizeClarificationLabel(raw);

  static String _normalizeClarificationLabel(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.toUpperCase() == 'NO' || s == '0') return 'NO';
    final t = s.toLowerCase();
    if (t.contains('item') && t.contains('amount')) return 'item & amount';
    if (t == 'item') return 'item';
    if (t == 'amount') return 'amount';
    return 'NO';
  }

  /// Build from Model A JSON (already normalised in [ApiService]).
  factory TransactionModel.fromModelA({
    required String id,
    required String rawInput,
    required Map<String, dynamic> json,
    required DateTime resolvedDate,
    required String resolvedCategory,
  }) {
    final intent = (json['intent'] as String? ?? '').trim();
    final intentLower = intent.toLowerCase();
    final rawCat = (json['category'] as String? ?? '').trim();
    final modelCategory = canonicalParserCategory(
        rawCat.isEmpty ? resolvedCategory : rawCat);

    final transactionType =
        _transactionTypeFromIntent(intentLower, modelCategory);

    final rawClarif = json['needs_clarification'];
    final needs = rawClarif is String
        ? normalizeClarificationLabel(rawClarif)
        : (rawClarif is bool
            ? (rawClarif ? 'item' : 'NO')
            : normalizeClarificationLabel(rawClarif?.toString() ?? 'NO'));

    double? amt;
    final rawAmt = json['amount'];
    if (rawAmt != null) amt = (rawAmt as num).toDouble();

    return TransactionModel(
      id: id,
      rawInput: rawInput,
      transactionType: transactionType,
      intent: intent.isNotEmpty ? intentLower : null,
      item: json['item'] as String?,
      amount: amt,
      date: resolvedDate,
      dateExpression: (json['date'] ?? json['date_expression']) as String? ??
          'today',
      needsClarification: needs,
      confidenceScore: (json['confidence'] as num? ?? 1.0).toDouble(),
      categoryName: modelCategory,
      rawModelOutput: Map<String, dynamic>.from(json),
    );
  }

  /// Legacy rows used [kLegacySavingsInvestmentType]; load as expense so
  /// budgeting matches other spending (monthly savings goal stays in profile).
  static const String kLegacySavingsInvestmentType = 'Savings & Investment';

  static String _normalizeStoredTransactionType(String raw) {
    if (raw == kLegacySavingsInvestmentType) return 'Expense';
    return raw;
  }

  static String _transactionTypeFromIntent(String intent, String category) {
    switch (intent) {
      case 'income':
        return 'Income';
      case 'financial services':
      case 'investment':
        // Counts like other expenses; category stays `investment` when applicable.
        return 'Expense';
      case 'unknown':
        return 'Unknown';
      case 'expense':
        return 'Expense';
      default:
        return _transactionTypeFromCategory(category);
    }
  }

  static String _transactionTypeFromCategory(String? category) {
    if (category == null || category.isEmpty) return 'Unknown';
    final c = category.toLowerCase();
    if (c == 'income') return 'Income';
    if (c == 'investment' || c == 'savings & investment') {
      return 'Expense';
    }
    if (c == 'unknown') return 'Unknown';
    return 'Expense';
  }

  static Map<String, dynamic>? _decodeRaw(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final out = <String, dynamic>{};
    for (final part in raw.split('||')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      out[part.substring(0, i)] = part.substring(i + 1);
    }
    return out.isEmpty ? null : out;
  }

  static String _encodeMap(Map<String, dynamic> m) =>
      m.entries.map((e) => '${e.key}=${e.value}').join('||');
}
