import '../models/user_profile.dart';
import '../models/transaction_model.dart';

// Period budget math: pool, remaining, safe-to-spend (daily pace), category splits.
// Buffer is subtracted only inside the STS divisor — it is never added to that number.

class BudgetResult {
  final double disposableIncome;
  final double totalSpent;
  final double totalIncome;
  final double totalSaved;
  /// Cash still in the pay-period pool (disposable + income − expenses). Buffer does **not** reduce this.
  final double remaining;
  /// Daily pace from **(remaining − buffer) ÷ days left** — buffer is sidelined, never added here.
  final double safeToSpend;
  final double safetyBuffer;
  final double expectedDailyRate;
  final double percentSpent;
  final int daysRemaining;
  final int totalDays;
  final bool isHealthy;
  final Map<String, double> byCategory;

  const BudgetResult({
    required this.disposableIncome,
    required this.totalSpent,
    required this.totalIncome,
    required this.totalSaved,
    required this.remaining,
    required this.safeToSpend,
    required this.safetyBuffer,
    required this.expectedDailyRate,
    required this.percentSpent,
    required this.daysRemaining,
    required this.totalDays,
    required this.isHealthy,
    required this.byCategory,
  });
}

class BudgetService {
  /// [bufferAmount] is money parked in the buffer pocket (e.g. unspent daily slices moved there).
  /// It is **subtracted** from [remaining] only for safe-to-spend pacing so buffer never inflates STS.
  static BudgetResult calculate(
    UserProfile profile,
    List<TransactionModel> allTransactions, {
    double bufferAmount = 0.0,
  }) {
    final lastPayday = profile.lastPayday;
    final nextPayday = profile.nextPayday;
    final totalDays = profile.totalDaysInPeriod;
    final daysRemaining = profile.daysUntilPayday.clamp(1, totalDays);

    // Filter transactions for current period
    final periodTx = allTransactions.where((t) {
      return t.date.isAfter(lastPayday.subtract(const Duration(days: 1))) &&
          t.date.isBefore(nextPayday.add(const Duration(days: 1)));
    }).toList();

    double totalSpent = 0;
    double totalIncome = 0;
    double totalSaved = 0;
    final byCategory = <String, double>{};

    for (final tx in periodTx) {
      if (tx.amount == null) continue;
      if (tx.isExpense) {
        totalSpent += tx.amount!;
        byCategory[tx.categoryName] =
            (byCategory[tx.categoryName] ?? 0) + tx.amount!;
      } else if (tx.isIncome) {
        totalIncome += tx.amount!;
      } else if (tx.isSavings) {
        totalSaved += tx.amount!;
      }
    }

    final disposable = profile.disposableIncome.clamp(0.0, double.maxFinite);
    final incomeAdjustedPool = disposable + totalIncome;
    final remaining = incomeAdjustedPool - totalSpent;
    final buf = bufferAmount.clamp(0.0, double.maxFinite);
    // Money already moved into the buffer must not raise tomorrow’s “slice” of STS.
    final pacingPool = (remaining - buf);
    final safeToSpend =
        daysRemaining > 0 ? pacingPool / daysRemaining : 0.0;
    final expectedDailyRate =
        totalDays > 0 ? incomeAdjustedPool / totalDays : 0.0;
    final safetyBuffer = safeToSpend - expectedDailyRate;
    final percentSpent = incomeAdjustedPool > 0
        ? (totalSpent / incomeAdjustedPool * 100).clamp(0, 999) as double
        : 0.0;

    return BudgetResult(
      disposableIncome: disposable,
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      totalSaved: totalSaved,
      remaining: remaining,
      safeToSpend: safeToSpend,
      safetyBuffer: safetyBuffer,
      expectedDailyRate: expectedDailyRate,
      percentSpent: percentSpent,
      daysRemaining: daysRemaining,
      totalDays: totalDays,
      isHealthy: safeToSpend >= 0,
      byCategory: byCategory,
    );
  }

  /// Generate "Tap to Justify" explanation text (pass current buffer so the formula matches the card).
  static List<JustificationLine> justify(
    UserProfile profile,
    BudgetResult result, {
    double bufferAmount = 0.0,
  }) =>
      [
        JustificationLine('💰 Salary / Disposable',
            '+${_fmt(profile.disposableIncome, profile.currency)}',
            bold: true),
        if (result.totalIncome > 0)
          JustificationLine('💵 Extra Income (in your budget pool)',
              '+${_fmt(result.totalIncome, profile.currency)}'),
        const JustificationLine('━━━━━━━━━━━━━━━━', ''),
        JustificationLine('🛒 Spent This Period',
            '-${_fmt(result.totalSpent, profile.currency)}'),
        JustificationLine('💵 Remaining Budget',
            '= ${_fmt(result.remaining, profile.currency)}',
            bold: true),
        if (bufferAmount > 0)
          JustificationLine(
            '🏦 In buffer (not counted toward daily pace)',
            '−${_fmt(bufferAmount, profile.currency)}',
          ),
        const JustificationLine('━━━━━━━━━━━━━━━━', ''),
        JustificationLine('📅 Days Remaining',
            '${result.daysRemaining} of ${result.totalDays}'),
        JustificationLine(
            '📊 Safe-to-Spend',
            bufferAmount > 0
                ? '(${_fmt(result.remaining, profile.currency)} − buffer) ÷ ${result.daysRemaining} days'
                : '${_fmt(result.remaining, profile.currency)} ÷ ${result.daysRemaining} days',
            sub: true),
        JustificationLine('✅ Your Safe-to-Spend Today',
            _fmt(result.safeToSpend, profile.currency),
            bold: true),
      ];

  static String _fmt(double v, String currency) =>
      '$currency ${v.abs().toStringAsFixed(2)}';
}

class JustificationLine {
  final String label;
  final String value;
  final bool bold;
  final bool sub;
  const JustificationLine(this.label, this.value,
      {this.bold = false, this.sub = false});
}
