// App provider for 3ML App — central state: profile, transactions, budget math, chat, buffer, theme.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';
import '../models/transaction_model.dart';
import '../models/buffer_model.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../services/date_parser_service.dart';

enum ChatMessageType { user, system, tip, error, chatbot }

class ChatMessage {
  final String id;
  final String text;
  final ChatMessageType type;
  final DateTime timestamp;
  final TransactionModel? transaction;

  /// True when the classifier was uncertain (confidence < 0.90).
  final bool lowConfidence;

  ChatMessage({
    String? id,
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.transaction,
    this.lowConfidence = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Persisted to disk so closing the app does not wipe the conversation.
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type.index,
        'timestamp': timestamp.toIso8601String(),
        'lowConfidence': lowConfidence,
        if (transaction != null) 'transaction': transaction!.toMap(),
      };

  static ChatMessage fromJson(Map<String, dynamic> m) {
    final ti = (m['type'] as num?)?.toInt() ?? 0;
    final safeType = ti >= 0 && ti < ChatMessageType.values.length
        ? ChatMessageType.values[ti]
        : ChatMessageType.system;
    TransactionModel? tx;
    final rawTx = m['transaction'];
    if (rawTx is Map) {
      try {
        tx = TransactionModel.fromMap(Map<String, dynamic>.from(rawTx));
      } catch (_) {}
    }
    return ChatMessage(
      id: m['id'] as String?,
      text: m['text'] as String? ?? '',
      type: safeType,
      timestamp: m['timestamp'] != null
          ? DateTime.tryParse(m['timestamp'] as String)
          : null,
      transaction: tx,
      lowConfidence: m['lowConfidence'] as bool? ?? false,
    );
  }
}

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService();
  final _api = ApiService();
  final _catSvc = CategoryService();
  final _uuid = const Uuid();

  // ── State ──────────────────────────────────────────────────
  bool _isInitialized = false;
  bool _isOnboarded = false;
  UserProfile? _profile;
  List<TransactionModel> _transactions = [];
  List<ChatMessage> _chatMessages = [];
  BudgetResult? _budget;
  BufferModel _buffer = BufferModel.empty();
  bool _isProcessing = false;
  bool _showSuggestions = true;
  List<Map<String, dynamic>> _suggestions = [];
  ThemeMode _themeMode = ThemeMode.dark;
  /// After install, user picks light/dark on the combined welcome screen ([needsThemeChoice]).
  bool _themeFirstChoiceDone = false;

  /// Last coach-mode tip shown after an expense; chat mode sends this to `/chat` for continuity.
  String? _lastCoachMessage;

  static const _kChatMessagesJson = 'chat_messages_v1';
  static const _kBufferNextCreditDay = 'buffer_next_credit_day_iso';

  // ── Getters ────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get isOnboarded => _isOnboarded;
  bool get needsThemeChoice =>
      _isInitialized && !_isOnboarded && !_themeFirstChoiceDone;
  UserProfile? get profile => _profile;
  List<TransactionModel> get transactions => _transactions;
  List<ChatMessage> get chatMessages => _chatMessages;
  BudgetResult? get budget => _budget;
  BufferModel get buffer => _buffer;
  bool get isProcessing => _isProcessing;
  bool get showSuggestions => _showSuggestions;
  List<Map<String, dynamic>> get suggestions => _suggestions;
  CategoryService get categoryService => _catSvc;
  ApiService get apiService => _api;
  ThemeMode get themeMode => _themeMode;

  List<TransactionModel> get recentTransactions =>
      _transactions.where((t) => !t.isUnknown).take(10).toList();

  // ── Initialization ─────────────────────────────────────────
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      final catJson = prefs.getString('category_metadata');
      final bufferJson = prefs.getString('buffer_amount');
      _showSuggestions = prefs.getBool('show_suggestions') ?? true;
      _themeFirstChoiceDone = prefs.getBool('theme_first_choice_done') ?? false;
      final themePref = prefs.getString('theme_mode') ?? 'dark';
      _themeMode = themePref == 'light' ? ThemeMode.light : ThemeMode.dark;

      if (catJson != null) {
        try {
          _catSvc.loadFromJson(jsonDecode(catJson));
        } catch (_) {}
      }

      if (bufferJson != null) {
        try {
          _buffer = BufferModel.fromJson(jsonDecode(bufferJson));
        } catch (_) {}
      }

      if (profileJson != null) {
        try {
          _profile = UserProfile.fromJson(jsonDecode(profileJson));
          _isOnboarded = true;
          _themeFirstChoiceDone = true;
          await prefs.setBool('theme_first_choice_done', true);
          await _loadTransactions();
          await _applyBufferCreditsForCompletedCalendarDays(prefs);
          _recalcBudget();
        } catch (e) {
          debugPrint('Error loading profile/transactions: $e');
          _profile = null;
          _isOnboarded = false;
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }

    if (_isOnboarded) {
      await _loadChatMessagesFromDisk();
      if (_chatMessages.isEmpty) _addWelcomeChatMessage();
      await _persistChatMessages();
      await _loadSuggestions();
    }
  }

  /// Persists theme from the welcome screen (see [needsThemeChoice]).
  Future<void> completeThemeSelection(ThemeMode mode) async {
    _themeMode = mode;
    _themeFirstChoiceDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode', mode == ThemeMode.light ? 'light' : 'dark');
    await prefs.setBool('theme_first_choice_done', true);
    notifyListeners();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  void _addWelcomeChatMessage() {
    final name = _profile?.name ?? 'there';
    _chatMessages.add(ChatMessage(
      text: "Hey $name 👋 I'm your budget assistant!\n\n"
          "Tell me what you spent, earned, or saved — in plain English:\n"
          "• \"coffee 35\" or \"spent 35 on coffee\"\n"
          "• \"salary 12000\" or \"got paid 12000\"\n"
          "• \"saved 500 to emergency fund\"\n\n"
          "Or ask me anything about budgeting — I'm here to help! 💬\n"
          "The more natural the better. Let's keep your money in check!",
      type: ChatMessageType.system,
    ));
  }

  // ── Onboarding ─────────────────────────────────────────────
  Future<void> completeOnboarding(UserProfile profile) async {
    _profile = profile;
    _isOnboarded = true;
    _themeFirstChoiceDone = true;
    await _saveProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_first_choice_done', true);
    await _loadTransactions();
    await _applyBufferCreditsForCompletedCalendarDays(prefs);
    _recalcBudget();
    if (_chatMessages.isEmpty) _addWelcomeChatMessage();
    await _persistChatMessages();
    await _loadSuggestions();
    notifyListeners();
  }

  Future<void> restoreFromBackup(
      UserProfile profile, List<TransactionModel> txs) async {
    _profile = profile;
    _isOnboarded = true;
    _themeFirstChoiceDone = true;
    await _saveProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_first_choice_done', true);
    for (final tx in txs) {
      await _db.insertTransaction(tx);
    }
    await _loadTransactions();
    await _applyBufferCreditsForCompletedCalendarDays(prefs);
    _recalcBudget();
    await _loadChatMessagesFromDisk();
    if (_chatMessages.isEmpty) _addWelcomeChatMessage();
    await _persistChatMessages();
    await _loadSuggestions();
    notifyListeners();
  }

  // ── Profile ────────────────────────────────────────────────
  Future<void> updateProfile(UserProfile profile) async {
    _profile = profile;
    await _saveProfile();
    _recalcBudget();
    notifyListeners();
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(_profile!.toJson()));
  }

  // ── Transactions ───────────────────────────────────────────
  Future<void> _loadTransactions() async {
    try {
      _transactions = await _db.getAllTransactions();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      _transactions = [];
    }
    _recalcBudget();
  }

  void _recalcBudget() {
    if (_profile != null) {
      _budget = BudgetService.calculate(
        _profile!,
        _transactions,
        bufferAmount: _buffer.amount,
      );
    }
    unawaited(_persistTodayStsSnapshot());
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _db.updateTransaction(tx);
    final idx = _transactions.indexWhere((t) => t.id == tx.id);
    if (idx != -1) _transactions[idx] = tx;
    _recalcBudget();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    // Remove in-memory first so [Dismissible] is removed from the tree immediately
    // (see Flutter docs for onDismissed).
    _transactions.removeWhere((t) => t.id == id);
    _recalcBudget();
    notifyListeners();
    await _db.deleteTransaction(id);
  }

  Future<void> moveTxCategory(String txId, String newCategory) async {
    final tx = _transactions.firstWhere((t) => t.id == txId);
    await updateTransaction(tx.copyWith(categoryName: newCategory));
  }

  // ── Buffer Amount ──────────────────────────────────────────
  Future<void> updateBuffer(double newAmount) async {
    _buffer = _buffer.copyWith(
      amount: newAmount.clamp(0.0, double.infinity),
      lastUpdated: DateTime.now(),
    );
    await _saveBuffer();
    notifyListeners();
  }

  Future<void> _saveBuffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buffer_amount', jsonEncode(_buffer.toJson()));
  }

  /// ISO `yyyy-MM-dd` for prefs keys (snapshots + rollover cursor).
  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Sum expenses whose [TransactionModel.date] falls on the local calendar [day].
  double _sumExpensesOnCalendarDay(DateTime day) {
    final start = _dateOnly(day);
    final end = start.add(const Duration(days: 1));
    return _transactions
        .where((t) =>
            t.isExpense &&
            !t.date.isBefore(start) &&
            t.date.isBefore(end))
        .fold<double>(0.0, (s, t) => s + (t.amount ?? 0.0));
  }

  /// For a completed calendar day: unspent slice of safe-to-spend (see stored snapshot) → buffer.
  double _unspentForCalendarDay(DateTime day, SharedPreferences prefs) {
    if (_profile == null) return 0.0;
    final iso = _isoDate(day);
    final snap = double.tryParse(prefs.getString('sts_snap_$iso') ?? '');
    final double sts;
    if (snap != null) {
      sts = snap;
    } else {
      final b = BudgetService.calculate(
        _profile!,
        _transactions,
        bufferAmount: _buffer.amount,
      );
      sts = b.expectedDailyRate;
    }
    final spent = _sumExpensesOnCalendarDay(day);
    return math.max(0.0, sts - spent);
  }

  /// Credits buffer for every **fully finished** local day since last run (user was under daily pace).
  Future<void> _applyBufferCreditsForCompletedCalendarDays(
      SharedPreferences prefs) async {
    if (_profile == null) return;
    final today = _dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final nextStr = prefs.getString(_kBufferNextCreditDay);
    if (nextStr == null) {
      await prefs.setString(_kBufferNextCreditDay, _isoDate(today));
      return;
    }
    var d = _dateOnly(DateTime.parse(nextStr));
    var updated = false;
    while (!d.isAfter(yesterday)) {
      final add = _unspentForCalendarDay(d, prefs);
      if (add > 0) {
        _buffer = _buffer.copyWith(
          amount: _buffer.amount + add,
          lastUpdated: DateTime.now(),
        );
        updated = true;
      }
      d = d.add(const Duration(days: 1));
    }
    await prefs.setString(_kBufferNextCreditDay, _isoDate(d));
    if (updated) await _saveBuffer();
  }

  /// Tracks the best (highest) safe-to-spend shown today so EOD credit uses a fair daily allowance.
  Future<void> _persistTodayStsSnapshot() async {
    if (_profile == null || _budget == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'sts_snap_${_isoDate(DateTime.now())}';
      final prev = double.tryParse(prefs.getString(key) ?? '');
      final cur = _budget!.safeToSpend;
      final best = prev != null ? math.max(prev, cur) : cur;
      await prefs.setString(key, best.toString());
    } catch (e) {
      debugPrint('STS snapshot: $e');
    }
  }

  Future<void> _loadChatMessagesFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kChatMessagesJson);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      final out = <ChatMessage>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          out.add(ChatMessage.fromJson(e));
        } else if (e is Map) {
          out.add(ChatMessage.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      _chatMessages = out;
    } catch (e) {
      debugPrint('Load chat: $e');
    }
  }

  Future<void> _persistChatMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kChatMessagesJson,
          jsonEncode(_chatMessages.map((m) => m.toJson()).toList()));
    } catch (e) {
      debugPrint('Persist chat: $e');
    }
  }

  // ── Week Summary Helper ────────────────────────────────────
  Map<String, dynamic> _buildWeekSummary(DateTime txDate) {
    if (_profile == null) {
      return {
        'total_spent_of_week': 0.0,
        'budget_of_week': 0.0,
        'top_category_of_week': '',
        'days_under_budget': 7,
        'days_over_budget': 0,
      };
    }

    final weekStart = _dateOnly(txDate).subtract(const Duration(days: 6));
    final weekEnd = _dateOnly(txDate).add(const Duration(days: 1));

    final weekTx = _transactions.where((t) {
      final d = _dateOnly(t.date);
      return t.isExpense && !d.isBefore(weekStart) && d.isBefore(weekEnd);
    }).toList();

    final totalSpentWeek =
        weekTx.fold<double>(0.0, (sum, t) => sum + (t.amount ?? 0.0));

    final lastP = _profile!.lastPayday;
    final nextP = _profile!.nextPayday;
    final periodIncome = _transactions
        .where((t) =>
            t.isIncome &&
            t.amount != null &&
            t.date.isAfter(lastP.subtract(const Duration(days: 1))) &&
            t.date.isBefore(nextP.add(const Duration(days: 1))))
        .fold<double>(0.0, (s, t) => s + t.amount!);

    final totalDays = _profile!.totalDaysInPeriod;
    final dailyAllowance = totalDays > 0
        ? (_profile!.disposableIncome + periodIncome) / totalDays
        : 0.0;
    final budgetOfWeek = dailyAllowance * 7;

    final categoryTotals = <String, double>{};
    for (final t in weekTx) {
      categoryTotals[t.categoryName] =
          (categoryTotals[t.categoryName] ?? 0) + (t.amount ?? 0);
    }
    String topCategory = '';
    if (categoryTotals.isNotEmpty) {
      topCategory = categoryTotals.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    int daysOver = 0;
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));
      final daySpent = _transactions
          .where((t) =>
              t.isExpense && !t.date.isBefore(day) && t.date.isBefore(dayEnd))
          .fold<double>(0.0, (sum, t) => sum + (t.amount ?? 0.0));
      if (daySpent > dailyAllowance) daysOver++;
    }

    return {
      'total_spent_of_week': totalSpentWeek,
      'budget_of_week': budgetOfWeek,
      'top_category_of_week': topCategory,
      'days_under_budget': 7 - daysOver,
      'days_over_budget': daysOver,
    };
  }

  // ── Coach / chat JSON snapshot (matches ApiService + Colab contract) ──
  Map<String, dynamic> _coachChatPayloadBase() {
    final b = _budget;
    if (b == null || _profile == null) return {};

    final weekSummary = _buildWeekSummary(DateTime.now());
    TransactionModel? recentExp;
    for (final t in _transactions) {
      if (t.isExpense && (t.amount ?? 0) != 0) {
        recentExp = t;
        break;
      }
    }

    return {
      'safe_to_spend_today': b.safeToSpend,
      'buffer_amount': _buffer.amount,
      'runway_days': b.daysRemaining,
      'current_balance': b.remaining,
      'is_over_budget': b.safeToSpend < 0,
      'recent_expense': recentExp == null
          ? <String, dynamic>{}
          : {
              'amount': recentExp.amount,
              'category': recentExp.categoryName,
              'item': recentExp.item ?? recentExp.intent ?? '',
            },
      'week_summary': weekSummary,
    };
  }

  /// `/chat` receives the numeric snapshot plus the last coach tip (not a hand-written prose summary).
  Map<String, dynamic> _buildChatUserContextMap() {
    final base = _coachChatPayloadBase();
    if (base.isEmpty) return {};
    return {
      ...base,
      'last_coach_message': _lastCoachMessage ?? '',
    };
  }

  // ── Chat & Transaction Processing ─────────────────────────
  Future<void> sendMessage(String input) async {
    if (input.trim().isEmpty) return;

    // Deduplicate rapid double-sends
    if (_chatMessages.isEmpty ||
        _chatMessages.last.text != input ||
        _chatMessages.last.type != ChatMessageType.user) {
      _chatMessages.add(ChatMessage(text: input, type: ChatMessageType.user));
    }
    _isProcessing = true;
    notifyListeners();

    // ── Step 1: Classify ─────────────────────────────────────
    final classification = await _api.classifyInput(input);
    final label = classification['label'] as String;
    final lowConfidence = classification['lowConfidence'] as bool;
    final confidence = classification['confidence'] as double;

    if (lowConfidence) {
      final pct = (confidence * 100).toStringAsFixed(0);
      _chatMessages.add(ChatMessage(
        text: "⚠️ I'm not very sure about this ($pct% confidence). "
            "Here's my best guess — let me know if I got it wrong.",
        type: ChatMessageType.error,
        lowConfidence: true,
      ));
      notifyListeners();
    }

    if (label == 'conversation') {
      await _handleChat(input);
    } else {
      await _handleTransaction(input);
    }

    _isProcessing = false;
    await _persistChatMessages();
    notifyListeners();
  }

  // ── Chat branch ────────────────────────────────────────────
  Future<void> _handleChat(String question) async {
    final ctxMap = _buildChatUserContextMap();
    final answer = ctxMap.isEmpty
        ? _api.localChatFallback(question)
        : (await _api.askChat(question: question, userContext: ctxMap) ??
            _api.localChatFallback(question));

    _chatMessages.add(ChatMessage(
      text: answer,
      type: ChatMessageType.chatbot,
    ));
  }

  // ── Transaction branch ─────────────────────────────────────
  Future<void> _handleTransaction(String input) async {
    final parsed = await _api.parseTransaction(input);

    if (parsed == null) {
      _chatMessages.add(ChatMessage(
        text:
            "⚠️ Something went wrong processing your message. Please try again.",
        type: ChatMessageType.error,
      ));
      return;
    }

    if (parsed['not_parseable'] == true) {
      _chatMessages.add(ChatMessage(
        text: "✏️ I couldn't understand that as a transaction.\n\n"
            "Try rewording it more simply, like:\n"
            "• \"coffee 10\"\n"
            "• \"lunch 45\"\n"
            "• \"salary 12000\"\n\n"
            "Keep it clear and I'll catch it! 😊",
        type: ChatMessageType.error,
      ));
      return;
    }

    final intentStr = (parsed['intent'] as String? ?? '').trim().toLowerCase();
    final modelCategory = (parsed['category'] as String? ?? '').trim().toLowerCase();

    if (intentStr == 'unknown' ||
        modelCategory.isEmpty ||
        modelCategory == 'unknown') {
      _chatMessages.add(ChatMessage(
        text: 'Nothing was saved — the parser treated that as unclear or '
            'non-transaction data.',
        type: ChatMessageType.system,
      ));
      return;
    }

    // Resolve date
    final dateExpr = parsed['date_expression'] as String? ?? 'today';
    final resolvedDate = DateParserService.parse(dateExpr);

    // Build transaction
    final tx = TransactionModel.fromModelA(
      id: _uuid.v4(),
      rawInput: input,
      json: parsed,
      resolvedDate: resolvedDate,
      resolvedCategory: 'other',
    );

    if (tx.amount == null) {
      _chatMessages.add(ChatMessage(
        text:
            "💭 Looks like a ${tx.item ?? 'transaction'} — but what was the amount?",
        type: ChatMessageType.system,
      ));
      return;
    }

    // Save to DB
    await _db.insertTransaction(tx);
    _transactions.insert(0, tx);
    _recalcBudget();

    // Update suggestions
    if (tx.item != null) {
      await _db.upsertSuggestion(
        item: tx.item!,
        amount: tx.amount,
        categoryName: tx.categoryName,
      );
      await _loadSuggestions();
    }

    // Build confirmation message
    final emoji = tx.isIncome
        ? '💰'
        : tx.isSavings
            ? '📈'
            : '🛒';
    final action = tx.isIncome
        ? 'Income logged'
        : tx.isSavings
            ? 'Savings logged'
            : 'Spent';
    final currency = _profile?.currency ?? 'EGP';

    String response =
        '$emoji **$action** $currency ${tx.amount!.toStringAsFixed(2)}'
        '${tx.item != null ? ' on ${tx.item}' : ''} · ${DateParserService.format(tx.date)}\n'
        '📂 Category: ${_catSvc.getDisplayName(tx.categoryName)}';

    if (_budget != null && tx.isExpense) {
      final b = _budget!;
      response +=
          '\n\n📊 Safe to spend today: $currency ${b.safeToSpend.toStringAsFixed(2)}';
    }

    _chatMessages.add(ChatMessage(
      text: response,
      type: ChatMessageType.system,
      transaction: tx,
    ));

    // ── Coach tip — only for expense transactions
    if (tx.isExpense) {
      final weekSummary = _buildWeekSummary(tx.date);
      final tip = await _api.getCoachingTip(
            safeToSpendToday: _budget?.safeToSpend ?? 0,
            runwayDays: _budget?.daysRemaining ?? 0,
            currentBalance: _budget?.remaining ?? 0,
            recentAmount: tx.amount ?? 0,
            recentCategory: tx.categoryName,
            recentItem: tx.item ?? tx.intent ?? 'transaction',
            isOverBudget: (_budget?.safeToSpend ?? 0) < 0,
            weekSummary: weekSummary,
          ) ??
          _api.localCoachingTip(
            safeToSpend: _budget?.safeToSpend ?? 0,
            amountSpent: tx.amount ?? 0,
            currency: currency,
            item: tx.item,
          );

      _lastCoachMessage = tip;
      _chatMessages.add(ChatMessage(text: tip, type: ChatMessageType.tip));
    }
  }

  // ── Suggestions ────────────────────────────────────────────
  Future<void> _loadSuggestions() async {
    _suggestions = await _db.getTopSuggestions(limit: 8);
  }

  void toggleSuggestions() async {
    _showSuggestions = !_showSuggestions;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_suggestions', _showSuggestions);
    notifyListeners();
  }

  Future<void> updateSuggestionPrice(String item, double amount) async {
    await _db.updateSuggestionPrice(item, amount);
    await _loadSuggestions();
    notifyListeners();
  }

  // ── Category management ────────────────────────────────────
  Future<void> renameCategoryDisplay(String original, String newName) async {
    _catSvc.setCustomName(original, newName);
    await _db.saveCategoryName(original, newName);
    _recalcBudget();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('category_metadata', jsonEncode(_catSvc.toJson()));
    notifyListeners();
  }

  Future<void> addUserCategory(String name, {String? emoji}) async {
    _catSvc.addUserCategory(name, emoji: emoji);
    await _db.saveCategoryName(name, name, isUserCreated: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('category_metadata', jsonEncode(_catSvc.toJson()));
    notifyListeners();
  }

  // ── Theme ──────────────────────────────────────────────────
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme_mode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    await prefs.setBool('theme_first_choice_done', true);
    notifyListeners();
  }

  // ── Reset ──────────────────────────────────────────────────
  Future<void> resetApp() async {
    await _db.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _transactions = [];
    _chatMessages = [];
    _profile = null;
    _budget = null;
    _buffer = BufferModel.empty();
    _lastCoachMessage = null;
    _isOnboarded = false;
    _isInitialized = true;
    notifyListeners();
  }
}
