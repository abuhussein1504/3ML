import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;

import '../models/transaction_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Classifier (backend/classifier_server.py)
  static String get _classifierBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // API URLs
  String _eventParserUrl = 'https://38b9-34-82-193-36.ngrok-free.app';
  String _coachChatUrl = 'https://f166-136-118-119-66.ngrok-free.app';

  void setEventParserUrl(String url) =>
      _eventParserUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  void setCoachChatUrl(String url) =>
      _coachChatUrl = url.trim().replaceAll(RegExp(r'/+$'), '');

  String get eventParserUrl => _eventParserUrl;
  String get coachChatUrl => _coachChatUrl;

  bool _isReady(String url) {
    final clean = url.trim();
    return clean.isNotEmpty &&
        (clean.startsWith('http://') || clean.startsWith('https://'));
  }

  bool get isEventParserConfigured => _isReady(_eventParserUrl);
  bool get isCoachChatConfigured => _isReady(_coachChatUrl);

  String _safeUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'PostmanRuntime/7.32.3',
  };

  static const Duration _classifierTimeout = Duration(seconds: 8);
  static const Duration _remoteLlmTimeout = Duration(seconds: 45);

  // CLASSIFIER  (local DistilBERT)
  Future<Map<String, dynamic>> classifyInput(String userInput) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_classifierBaseUrl/classify'),
            headers: _headers,
            body: jsonEncode({'text': userInput}),
          )
          .timeout(_classifierTimeout);

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final rawLabel = (data['label'] as String? ?? '').toLowerCase();
        final label = (rawLabel.contains('transaction') ||
                rawLabel.contains('expense') ||
                rawLabel == 'label_1' ||
                rawLabel == '1' ||
                rawLabel == 'pos' ||
                rawLabel == 'positive')
            ? 'transaction'
            : 'conversation';
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 1.0;
        return {
          'label': label,
          'confidence': confidence,
          'lowConfidence': confidence < 0.90,
        };
      }
    } catch (_) {
    }
    return _localClassify(userInput);
  }

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

  // EVENT PARSER  (Colab ngrok)
  Future<Map<String, dynamic>?> parseTransaction(String userInput) async {
    print("parseTransaction CALLED");

    print("RAW URL = '$_eventParserUrl'");
    print("TRIMMED URL = '${_eventParserUrl.trim()}'");
    print("IS READY = ${_isReady(_eventParserUrl)}");

    final url = _eventParserUrl.trim();

    if (!_isReady(url)) {
      print("❌ URL NOT READY → using local parser");
      return localParseTransaction(userInput);
    }

    try {
      print("Calling: $url/parse");

      final response = await http
          .post(
            Uri.parse('$url/parse'),
            headers: _headers,
            body: jsonEncode({'text': userInput}),
          )
          .timeout(_remoteLlmTimeout);

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data is Map && data['parseable'] == false) {
          return {'not_parseable': true};
        }

        if (data is Map<String, dynamic>) {
          return _normalizeParserResponse(data);
        }

        return _normalizeParserResponse(Map<String, dynamic>.from(data));
      }

      return localParseTransaction(userInput);

    } catch (e, stack) {
      print("❌ PARSE ERROR: $e");
      print(stack);
      return localParseTransaction(userInput);
    }
  }

  // LOCAL PARSER — regex-based offline fallback (second option after remote)
  Map<String, dynamic>? localParseTransaction(String input) {
    final lower = input.trim().toLowerCase();

    String intent = 'expense';
    if (RegExp(
            r'\b(salary|got paid|received|income|earned|paycheck|payment in)\b')
        .hasMatch(lower)) {
      intent = 'income';
    } else if (RegExp(
            r'\b(invest|investment|stocks?|crypto|sip\b|mutual fund|brokerage|portfolio)\b')
        .hasMatch(lower)) {
      intent = 'investment';
    } else if (RegExp(r'\b(saved|saving|deposit|emergency fund)\b')
        .hasMatch(lower)) {
      intent = 'expense';
    }

    final amountMatch = RegExp(
      r'(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)',
    ).firstMatch(lower);
    if (amountMatch == null) return {'not_parseable': true};
    final amountStr = amountMatch.group(1)!.replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return {'not_parseable': true};

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

    String date = 'today';
    if (lower.contains('yesterday')) date = 'yesterday';
    final daysAgoMatch = RegExp(r'(\d+)\s+days?\s+ago').firstMatch(lower);
    if (daysAgoMatch != null) date = '${daysAgoMatch.group(1)} days ago';
    final lastDayMatch = RegExp(
            r'last\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)')
        .firstMatch(lower);
    if (lastDayMatch != null) date = 'last ${lastDayMatch.group(1)}';

    return {
      'intent': intent,
      'category': _guessCategory(lower, intent),
      'item': item,
      'amount': amount,
      'date': date,
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

  Map<String, dynamic> _normalizeParserResponse(Map<String, dynamic> data) {
    String str(String key) {
      final v = data[key];
      if (v == null) return '';
      final t = v.toString().trim();
      if (t.isEmpty || t == 'null') return '';
      return t;
    }

    String pickStr(List<String> keys) {
      for (final k in keys) {
        final s = str(k);
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    dynamic pickVal(List<String> keys) {
      for (final k in keys) {
        if (data.containsKey(k) && data[k] != null) return data[k];
      }
      return null;
    }

    final intent = pickStr(['intent', 'Intent']).toLowerCase();
    final category = pickStr(['category', 'Category']).toLowerCase();
    final itemRaw = pickVal(['item', 'Item']);
    final item = itemRaw == null ? null : itemRaw.toString().trim().isEmpty
        ? null
        : itemRaw.toString().trim();

    final needsClarif = pickVal(['needs_clarification', 'Needs_Clarification']);
    final confidenceRaw = pickVal(['confidence', 'Confidence']);

    final needsStr = TransactionModel.normalizeClarificationLabel(
      needsClarif?.toString() ?? 'NO',
    );

    double? parsedAmount;
    final rawAmount = pickVal(['amount', 'Amount']);
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount != null) {
      parsedAmount = double.tryParse(rawAmount.toString());
    }

    final dateRaw = pickStr(['date', 'Date']);
    final date = dateRaw.isNotEmpty ? dateRaw : 'today';

    final conf = confidenceRaw is num
        ? confidenceRaw.toDouble()
        : double.tryParse(confidenceRaw?.toString() ?? '') ?? 1.0;

    return {
      'intent': intent,
      'category': category,
      'item': item,
      'amount': parsedAmount,
      'date': date,
      'confidence': conf,
      'needs_clarification': needsStr,
    };
  }

  // COACH  (Colab ngrok)
  Future<String?> getCoachingTip({
    required double safeToSpendBefore,
    required double safeToSpendToday,
    required int runwayDays,
    required double currentBalance,
    required double recentAmount,
    required String recentCategory,
    required String recentItem,
    required bool isOverBudget,
    required Map<String, dynamic> weekSummary,
  }) async {
    if (!_isReady(_coachChatUrl)) {
      print("❌ Coach URL not ready");
      return null;
    }

    final url = _safeUrl(_coachChatUrl);

    final coachBody = {
      'safe_to_spend_before': safeToSpendBefore,
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

    try {
      print("COACH CALL → $url/coach");
      print("BODY: ${jsonEncode(coachBody)}");

      final response = await http.post(
        Uri.parse('$url/coach'),
        headers: _headers,
        body: jsonEncode(coachBody),
      ).timeout(_remoteLlmTimeout);

      print("STATUS: ${response.statusCode}");
      print("RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        return _extractStringResponse(
          utf8.decode(response.bodyBytes),
          ['message'],
        );
      }

      print("❌ Coach failed with status: ${response.statusCode}");
      return null;

    } catch (e, stack) {
      print("❌ COACH ERROR: $e");
      print(stack);
      return null;
    }
  }

  // CHAT  (Colab ngrok)
  Future<String?> askChat({
    required String question,
    required String userContext,
  }) async {
    if (!_isReady(_coachChatUrl)) {
      print("❌ Chat URL not ready");
      return null;
    }

    final url = _safeUrl(_coachChatUrl);

    try {
      print("CHAT CALL → $url/chat");

      final body = {
        'user_context': userContext,
        'user_input': question,
      };

      print("BODY: ${jsonEncode(body)}");

      final response = await http.post(
        Uri.parse('$url/chat'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_remoteLlmTimeout);

      print("STATUS: ${response.statusCode}");
      print("RESPONSE: ${response.body}");

      if (response.statusCode == 200) {
        return _extractStringResponse(
          utf8.decode(response.bodyBytes),
          ['answer'],
        );
      }

      print("❌ Chat failed: ${response.statusCode}");
      return null;

    } catch (e, stack) {
      print("❌ CHAT ERROR: $e");
      print(stack);
      return null;
    }
  }

  // Helpers
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

  // Offline fallbacks (used when server is not reachable)
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
      return "You're running tight — only $currency ${safeToSpend.toStringAsFixed(2)}/day left. Skip the extras.";
    }
    if (amountSpent > safeToSpend * 0.5) {
      return "That ${item != null ? '"$item"' : 'purchase'} took a big chunk of today's budget. Be mindful of the rest.";
    }
    return "You're on track! Keep it up and you'll make it to payday comfortably.";
  }

  String localChatFallback(String question) {
    return "The AI assistant isn't reachable right now.\n\n"
        "In the meantime: focus on essentials, track every purchase, and review your weekly summary.";
  }
}

