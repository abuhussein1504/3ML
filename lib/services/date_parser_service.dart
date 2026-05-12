import 'package:intl/intl.dart';

class DateParserService {
  /// Convert a natural language date_expression from Model A into a [DateTime].
  /// Falls back to [DateTime.now()] if parsing fails.
  static DateTime parse(String? expression) {
    if (expression == null || expression.isEmpty) return DateTime.now();

    final now = DateTime.now();
    final lower = expression.toLowerCase().trim();

    // ── Simple keywords ────────────────────────────────
    switch (lower) {
      case 'today':
        return _dateOnly(now);
      case 'yesterday':
        return _dateOnly(now.subtract(const Duration(days: 1)));
      case 'tomorrow':
        return _dateOnly(now.add(const Duration(days: 1)));
      case 'last week':
        return _dateOnly(now.subtract(const Duration(days: 7)));
      case 'this week':
        return _dateOnly(now.subtract(Duration(days: now.weekday - 1)));
      case 'last month':
        return DateTime(now.year, now.month - 1, now.day);
    }

    // ── "X days ago" / "X day ago" ────────────────────
    final daysAgo = RegExp(r'^(\d+)\s+days?\s+ago$').firstMatch(lower);
    if (daysAgo != null) {
      final n = int.tryParse(daysAgo.group(1)!) ?? 0;
      return _dateOnly(now.subtract(Duration(days: n)));
    }

    // ── "X weeks ago" ─────────────────────────────────
    final weeksAgo = RegExp(r'^(\d+)\s+weeks?\s+ago$').firstMatch(lower);
    if (weeksAgo != null) {
      final n = int.tryParse(weeksAgo.group(1)!) ?? 0;
      return _dateOnly(now.subtract(Duration(days: n * 7)));
    }

    // ── "last <weekday>" ──────────────────────────────
    final lastDay = RegExp(r'^last\s+(\w+)$').firstMatch(lower);
    if (lastDay != null) {
      final d = _weekdayIndex(lastDay.group(1)!);
      if (d != null) {
        int offset = (now.weekday - d) % 7;
        if (offset == 0) offset = 7;
        return _dateOnly(now.subtract(Duration(days: offset)));
      }
    }

    // ── "this <weekday>" ──────────────────────────────
    final thisDay = RegExp(r'^this\s+(\w+)$').firstMatch(lower);
    if (thisDay != null) {
      final d = _weekdayIndex(thisDay.group(1)!);
      if (d != null) {
        int offset = (now.weekday - d) % 7;
        return _dateOnly(now.subtract(Duration(days: offset)));
      }
    }

    // ── "on <weekday>" ────────────────────────────────
    final onDay = RegExp(r'^on\s+(\w+)$').firstMatch(lower);
    if (onDay != null) {
      final d = _weekdayIndex(onDay.group(1)!);
      if (d != null) {
        int offset = (now.weekday - d) % 7;
        return _dateOnly(now.subtract(Duration(days: offset)));
      }
    }

    // ── Numeric formats: "DD/MM/YYYY", "MM/DD/YYYY", "YYYY-MM-DD" ──
    final numericDate = RegExp(
      r'^(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?$',
    ).firstMatch(lower);
    if (numericDate != null) {
      final a = int.tryParse(numericDate.group(1)!) ?? 1;
      final b = int.tryParse(numericDate.group(2)!) ?? 1;
      final yearStr = numericDate.group(3);
      int year = yearStr != null
          ? (yearStr.length == 2 ? 2000 + int.parse(yearStr) : int.parse(yearStr))
          : now.year;
      // Assume DD/MM when day ≤ 31 and month ≤ 12
      if (a <= 31 && b <= 12) return DateTime(year, b, a);
      if (b <= 31 && a <= 12) return DateTime(year, a, b);
    }

    // ── ISO 8601: "2026-04-10" ────────────────────────
    try {
      return DateTime.parse(expression);
    } catch (_) {}

    // ── "April 10", "10 April", "Apr 10" ─────────────
    final monthName = _parseMonthNamed(lower, now.year);
    if (monthName != null) return monthName;

    // Fallback
    return _dateOnly(now);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static int? _weekdayIndex(String name) {
    const map = {
      'monday': 1, 'mon': 1,
      'tuesday': 2, 'tue': 2, 'tues': 2,
      'wednesday': 3, 'wed': 3,
      'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4,
      'friday': 5, 'fri': 5,
      'saturday': 6, 'sat': 6,
      'sunday': 7, 'sun': 7,
    };
    return map[name];
  }

  static final _monthMap = {
    'january': 1, 'jan': 1, 'february': 2, 'feb': 2,
    'march': 3, 'mar': 3, 'april': 4, 'apr': 4,
    'may': 5, 'june': 6, 'jun': 6, 'july': 7, 'jul': 7,
    'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
    'october': 10, 'oct': 10, 'november': 11, 'nov': 11,
    'december': 12, 'dec': 12,
  };

  static DateTime? _parseMonthNamed(String lower, int currentYear) {
    // "april 10" or "10 april"
    for (final entry in _monthMap.entries) {
      final monthWord = entry.key;
      final monthNum = entry.value;

      // "monthName day"
      final r1 = RegExp(r'^' + monthWord + r'\s+(\d{1,2})(?:\s+(\d{4}))?$')
          .firstMatch(lower);
      if (r1 != null) {
        final day = int.tryParse(r1.group(1)!) ?? 1;
        final year = r1.group(2) != null ? int.parse(r1.group(2)!) : currentYear;
        return DateTime(year, monthNum, day);
      }

      // "day monthName"
      final r2 = RegExp(r'^(\d{1,2})\s+' + monthWord + r'(?:\s+(\d{4}))?$')
          .firstMatch(lower);
      if (r2 != null) {
        final day = int.tryParse(r2.group(1)!) ?? 1;
        final year = r2.group(2) != null ? int.parse(r2.group(2)!) : currentYear;
        return DateTime(year, monthNum, day);
      }
    }
    return null;
  }

  /// Format a DateTime as a human-friendly string
  static String format(DateTime dt, {bool includeYear = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow';

    final diff = today.difference(date).inDays;
    if (diff > 0 && diff < 7) return DateFormat('EEEE').format(dt); // e.g. Monday

    if (includeYear || dt.year != now.year) {
      return DateFormat('d MMM yyyy').format(dt);
    }
    return DateFormat('d MMM').format(dt);
  }
}
