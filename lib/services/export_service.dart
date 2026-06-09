import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../models/user_profile.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  Future<void> exportTransactionsCsv(
    List<TransactionModel> transactions,
    UserProfile profile,
  ) async {
    final buffer = StringBuffer();

    buffer.writeln(
      'ID,Raw Input,Transaction Type,Intent,Item,Amount,Date,'
      'Date Expression,Category,Confidence Score,Created At',
    );

    for (final tx in transactions) {
      buffer.writeln([
        _safe(tx.id),
        _safe(tx.rawInput),
        _safe(tx.transactionType),
        _safe(tx.intent ?? ''),
        _safe(tx.item ?? ''),
        tx.amount?.toStringAsFixed(2) ?? '',
        tx.date.toIso8601String().split('T').first,
        _safe(tx.dateExpression ?? ''),
        _safe(tx.categoryName),
        tx.confidenceScore.toStringAsFixed(2),
        tx.createdAt.toIso8601String(),
      ].join(','));
    }

    await _shareText(
      buffer.toString(),
      '3ml_transactions_${_dateStamp()}.csv',
      'text/csv',
    );
  }

  Future<void> exportRecoveryData(
    List<TransactionModel> transactions,
    UserProfile profile,
  ) async {
    final data = {
      'version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'profile': profile.toJson(),
      'transactions': transactions.map((tx) => {
        ...tx.toMap(),
        'before_parser': tx.rawInput,
        'after_parser': tx.rawModelOutput,
      }).toList(),
    };

    await _shareText(
      const JsonEncoder.withIndent('  ').convert(data),
      '3ml_backup_${_dateStamp()}.json',
      'application/json',
    );
  }

  Future<RecoveryData?> parseRecoveryFile(String content) async {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final profileJson = json['profile'] as Map<String, dynamic>?;
      final txList = json['transactions'] as List<dynamic>?;

      if (profileJson == null) return null;

      final profile = UserProfile.fromJson(profileJson);
      final transactions = txList
          ?.map((m) => TransactionModel.fromMap(m as Map<String, dynamic>))
          .toList() ?? [];

      return RecoveryData(profile: profile, transactions: transactions);
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareText(String content, String filename, String mimeType) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)], subject: filename),
    );
  }

  String _safe(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _dateStamp() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class RecoveryData {
  final UserProfile profile;
  final List<TransactionModel> transactions;
  const RecoveryData({required this.profile, required this.transactions});
}
