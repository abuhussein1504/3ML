import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';

/// 3ML API Service — three models, two servers:
///
///  • Classifier  — local DistilBERT  → POST http://localhost:8000/classify
///      Body:     {"text":"..."}
///      Response: {"label":"transaction"|"conversation","confidence":0.97}
///
///  • EventParser — Colab ngrok FastAPI → POST {eventParserUrl}/parse
///      Body:     {"text":"..."}
///      Response: structured JSON dict  OR  {"parseable": false}
///
///  • CoachChat   — Colab ngrok FastAPI → POST {coachChatUrl}/coach
///                                      → POST {coachChatUrl}/chat
///      Coach body:  {"user_input": {...}}
///      Chat body:   {"user_context": { ... financial snapshot ... }, "user_input":"..."}
///
/// System prompts live on the server side — Flutter does NOT send them.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Classifier: FastAPI on your PC (see backend/classifier_server.py) ───────
  /// - Android **emulator** → `10.0.2.2` reaches the host PC.
  /// - Physical phone on same Wi‑Fi → replace with your PC's LAN IP (e.g. `http://192.168.1.5:8000`).
  /// - iOS simulator / desktop → loopback.
  static String get _classifierBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // ── Remote Colab / ngrok — set full `https://….ngrok-free.app` URLs here ───
  String _eventParserUrl = 'https://6d52-36-125-172-55.ngrok-free.app';
  String _coachChatUrl = 'https://6d52-34-125-172-55.ngrok-free.app';

  void setEventParserUrl(String url) =>
      _eventParserUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  void setCoachChatUrl(String url) =>
      _coachChatUrl = url.trim().replaceAll(RegExp(r'/+$'), '');

  String get eventParserUrl => _eventParserUrl;
  String get coachChatUrl => _coachChatUrl;

  /// True only when a real http(s) URL has been configured.
  bool _isReady(String url) =>
      url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://'));

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    // ngrok requires this header to bypass the browser-warning page
    'ngrok-skip-browser-warning': 'true',
  };

  /// Short timeouts so offline / dead servers fail fast and local fallbacks run quickly.
  static const Duration _classifierTimeout = Duration(seconds: 2);
  static const Duration _remoteShortTimeout = Duration(seconds: 5);

  // ───────────────────────────────────────────────────────────────────────────
  // CLASSIFIER  (local DistilBERT — always localhost)
  // POST http://localhost:8000/classify  {"text":"..."}
  // ───────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> classifyInput(String userInput) async {
    try {
      final response = await http
          .post(
            Uri.parse('${_classifierBaseUrl}/classify'),
            headers: _headers,
            body: jsonEncode({'text': userInput}),
          )
          .timeout(_classifierTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final label = (data['label'] as String? ?? '').toLowerCase();
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 1.0;
        return {
          'label': label == 'transaction' ? 'transaction' : 'conversation',
          'confidence': confidence,
          'lowConfidence': confidence < 0.90,
        };
      }
    } catch (_) {
      // local server not running — fall through to heuristic
    }
    return _localClassify(userInput);
  }

  /// Heuristic fallback when the local classifier server is not running.
  Map<String, dynamic> _localClassify(String input) {
    final lower = input.trim().toLowerCase();

    final questionPatterns = [
      'what',
      'how',
      'why',
      'when',
      'where',
      'who',
      'which',
      'can you',
      'could you',
      'tell me',
      'explain',
      'help me',
      'should i',
      'is it',
      'do i',
      'is there',
      'advice',
      'tip',
      'suggest',
      'recommendation',
      'best way',
      'good way',
      'emergency fund',
      'invest',
      'save money',
      'budget tips',
      'credit',
      'loan',
      'debt',
      'interest rate',
    ];

    for (final q in questionPatterns) {
      if (lower.startsWith(q) || lower.contains('? ') || lower.endsWith('?')) {
        return {
          'label': 'conversation',
          'confidence': 1.0,
          'lowConfidence': false
        };
      }
    }

    final hasNumber = RegExp(r'\d').hasMatch(lower);
    final txWords = [
      'spent',
      'paid',
      'bought',
      'got paid',
      'salary',
      'income',
      'saved',
      'coffee',
      'lunch',
      'dinner',
      'uber',
      'taxi',
      'rent',
      'bill',
      'electricity',
      'groceries',
      'shopping',
    ];

    if (hasNumber) {
      return {
        'label': 'transaction',
        'confidence': 1.0,
        'lowConfidence': false
      };
    }
    for (final w in txWords) {
      if (lower.contains(w)) {
        return {
          'label': 'transaction',
          'confidence': 1.0,
          'lowConfidence': false
        };
      }
    }

    return {'label': 'conversation', 'confidence': 1.0, 'lowConfidence': false};
  }

  // ───────────────────────────────────────────────────────────────────────────
  // EVENT PARSER  (Colab ngrok)
  // POST {eventParserUrl}/parse  {"text":"..."}
  // ───────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> parseTransaction(String userInput) async {
    if (!_isReady(_eventParserUrl)) return localParseTransaction(userInput);

    try {
      final response = await http
          .post(
            Uri.parse('$_eventParserUrl/parse'),
            headers: _headers,
            body: jsonEncode({'text': userInput}),
          )
          .timeout(_remoteShortTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Server exhausted retries and returned {"parseable": false}
        if (data is Map && data['parseable'] == false) {
          return {'not_parseable': true};
        }
        return _normalizeParserResponse(data);
      }

      if (response.statusCode == 422 || response.statusCode == 400) {
        return {'not_parseable': true};
      }

      // Any other error — fall back to local parser
      return localParseTransaction(userInput);
    } catch (_) {
      return localParseTransaction(userInput);
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LOCAL PARSER — regex-based offline fallback
  // ───────────────────────────────────────────────────────────────────────────

  Map<String, dynamic>? localParseTransaction(String input) {
    final lower = input.trim().toLowerCase();

    // Detect intent
    String intent = 'expense';
    if (RegExp(
            r'\b(salary|got paid|received|income|earned|paycheck|payment in)\b')
        .hasMatch(lower)) {
      intent = 'income';
    } else if (RegExp(
            r'\b(saved|saving|deposit|emergency fund|investment|invest)\b')
        .hasMatch(lower)) {
      intent = 'investment';
    }

    // Amount: avoid matching only the first 3 digits of values like 5000 (old bug).
    final amountMatch = RegExp(
      r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)',
    ).firstMatch(lower);
    if (amountMatch == null) return {'not_parseable': true};
    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return {'not_parseable': true};

    // Extract item
    String cleaned = lower
        .replaceAll(RegExp(RegExp.escape(amountMatch.group(0)!)), ' ')
        .replaceAll(
            RegExp(
                r'\b(spent|paid|bought|got|for|on|a|an|the|yesterday|today|last|this|week|month|ago|morning|evening|night)\b'),
            ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    final item = cleaned.isNotEmpty
        ? cleaned[0].toUpperCase() + cleaned.substring(1)
        : null;

    // Detect date expression
    String dateExpr = 'today';
    if (lower.contains('yesterday')) dateExpr = 'yesterday';
    final daysAgoMatch = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(lower);
    if (daysAgoMatch != null) dateExpr = '${daysAgoMatch.group(1)} days ago';
    final lastDayMatch = RegExp(
            r'last\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(lower);
    if (lastDayMatch != null) dateExpr = 'last ${lastDayMatch.group(1)}';

    return {
      'intent': intent,
      'category': _guessCategory(lower, intent),
      'item': item,
      'amount': amount,
      'date_expression': dateExpr,
      'needs_clarification': 'NO',
      'confidence': 0.75,
    };
  }

  String _guessCategory(String lower, String intent) {
    if (intent == 'income') return 'income';
    if (intent == 'investment') return 'investment';

    const cats = <String, List<String>>{
      'food & drink': [
        'coffee',
        'lunch',
        'dinner',
        'breakfast',
        'food',
        'meal',
        'restaurant',
        'cafe',
        'snack',
        'groceries',
        'grocery',
        'eat',
        'drink',
        'water',
        'juice',
        'tea',
        'shawarma',
        'pizza',
        'burger',
        'kfc',
        'mcdonalds',
        'uber eats',
        'delivery',
      ],
      'transport': [
        'uber',
        'taxi',
        'bus',
        'metro',
        'train',
        'fuel',
        'petrol',
        'gas',
        'parking',
        'careem',
        'bolt',
        'ride',
        'transport',
      ],
      'shopping': [
        'amazon',
        'clothes',
        'shirt',
        'shoes',
        'shopping',
        'store',
        'mall',
        'market',
        'buy',
        'bought',
        'online',
      ],
      'healthcare': [
        'pharmacy',
        'medicine',
        'doctor',
        'hospital',
        'clinic',
        'gym',
        'health',
        'dental',
        'dentist',
        'medical',
      ],
      'entertainment': [
        'cinema',
        'movie',
        'netflix',
        'spotify',
        'game',
        'gaming',
        'concert',
        'ticket',
        'subscription',
      ],
      'utilities & housing': [
        'electricity',
        'water bill',
        'internet',
        'wifi',
        'phone bill',
        'mobile bill',
        'utility',
        'rent',
        'apartment',
        'maintenance',
        'repair',
        'home',
      ],
      'family & education': [
        'book',
        'course',
        'school',
        'university',
        'tuition',
        'study',
        'training',
      ],
    };

    for (final entry in cats.entries) {
      for (final kw in entry.value) {
        if (lower.contains(kw)) return entry.key;
      }
    }
    return 'other';
  }

  /// Normalise Event Parser JSON to consistent internal keys.
  Map<String, dynamic> _normalizeParserResponse(dynamic raw) {
    final Map<String, dynamic> data = raw is Map<String, dynamic> ? raw : {};

    String str(String key) => (data[key] ?? '').toString();
    dynamic val(String key) => data[key];

    final intent = str('intent').toLowerCase();
    final category = str('category').toLowerCase();
    final needsClarif = data['needs_clarification'];
    final confidence = val('confidence');

    // Parser contract: "NO" | "item" | "amount" | "item, amount" (we store Title Case).
    final needsStr = TransactionModel.normalizeClarificationLabel(
      needsClarif?.toString() ?? 'NO',
    );

    double? parsedAmount;
    final rawAmount = val('amount');
    if (rawAmount != null) parsedAmount = (rawAmount as num).toDouble();

    return {
      'intent': intent,
      'category': category,
      'item': val('item') as String?,
      'amount': parsedAmount,
      'date_expression': str('date').isNotEmpty ? str('date') : 'today',
      'needs_clarification': needsStr,
      'confidence': confidence != null ? (confidence as num).toDouble() : 1.0,
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // COACH  (Colab ngrok)
  // POST {coachChatUrl}/coach  {"user_input": {...}}
  // ───────────────────────────────────────────────────────────────────────────

  Future<String?> getCoachingTip({
    required double safeToSpendToday,
    required int runwayDays,
    required double currentBalance,
    required double recentAmount,
    required String recentCategory,
    required String recentItem,
    required bool isOverBudget,
    required Map<String, dynamic> weekSummary,
  }) async {
    if (!_isReady(_coachChatUrl)) return null;

    try {
      final userInputMap = {
        'safe_to_spend_today': safeToSpendToday,
        'runway_days': runwayDays,
        'current_balance': currentBalance,
        'is_over_budget': isOverBudget,
        'recent_expense': {
          'amount': recentAmount,
          'category': recentCategory,
          'item': recentItem,
        },
        'week_summary': weekSummary,
      };

      final response = await http
          .post(
            Uri.parse('$_coachChatUrl/coach'),
            headers: _headers,
            body: jsonEncode({'user_input': userInputMap}),
          )
          .timeout(_remoteShortTimeout);

      if (response.statusCode == 200) {
        return _extractStringResponse(
            response.body, ['message', 'advice', 'response']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // CHAT  (Colab ngrok)
  // POST {coachChatUrl}/chat  {"user_context":"...","user_input":"..."}
  // ───────────────────────────────────────────────────────────────────────────

  Future<String?> askChat({
    required String question,
    required Map<String, dynamic> userContext,
  }) async {
    if (!_isReady(_coachChatUrl)) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$_coachChatUrl/chat'),
            headers: _headers,
            body: jsonEncode({
              'user_context': userContext,
              'user_input': question,
            }),
          )
          .timeout(_remoteShortTimeout);

      if (response.statusCode == 200) {
        return _extractStringResponse(
            response.body, ['answer', 'message', 'response']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Pull a string from a JSON response body.
  /// Tries each key in order; falls back to raw trimmed body.
  String? _extractStringResponse(String body, List<String> keys) {
    final trimmed = body.trim();
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        for (final k in keys) {
          final v = decoded[k];
          if (v == null) continue;
          if (v is String) return v.trim();
          if (v is num || v is bool) return v.toString();
        }
      }
      if (decoded is String) return decoded.trim();
    } catch (_) {}
    return trimmed.isNotEmpty ? trimmed : null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Offline fallbacks (used when Colab server is not reachable)
  // ───────────────────────────────────────────────────────────────────────────

  String localCoachingTip({
    required double safeToSpend,
    required double amountSpent,
    required String currency,
    required String? item,
  }) {
    if (safeToSpend < 0) {
      return "⚠️ You're over your budget for this period. Try to hold back on spending for the next few days.";
    }
    if (safeToSpend < 20) {
      return "🔶 You're running tight — only $currency ${safeToSpend.toStringAsFixed(2)}/day left. Skip the extras.";
    }
    if (amountSpent > safeToSpend * 0.5) {
      return "💡 That ${item != null ? '"$item"' : 'purchase'} took a big chunk of today's budget. Be mindful of the rest.";
    }
    return "✅ You're on track! Keep it up and you'll make it to payday comfortably.";
  }

  String localChatFallback(String question) {
    return "🤔 The AI assistant isn't reachable right now. Make sure your Colab server is running.\n\n"
        "In the meantime: focus on essentials, track every purchase, and review your weekly summary.";
  }
}
