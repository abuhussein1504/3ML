import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../sqlite_init.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    await initSqlite();
    final path = join(await getDatabasesPath(), '3ml_budget.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN needsClarificationDetail TEXT NOT NULL DEFAULT 'NO'
      ''');
      await db.rawUpdate('''
        UPDATE transactions SET needsClarificationDetail = CASE WHEN needsClarification = 1 THEN 'Item' ELSE 'NO' END
      ''');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        rawInput TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        intent TEXT,
        item TEXT,
        amount REAL,
        date TEXT NOT NULL,
        dateExpression TEXT,
        needsClarification INTEGER NOT NULL DEFAULT 0,
        needsClarificationDetail TEXT NOT NULL DEFAULT 'NO',
        confidenceScore REAL NOT NULL DEFAULT 1.0,
        categoryName TEXT NOT NULL DEFAULT 'other',
        createdAt TEXT NOT NULL,
        rawModelOutput TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE suggestions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item TEXT NOT NULL UNIQUE,
        amount REAL,
        categoryName TEXT,
        useCount INTEGER NOT NULL DEFAULT 1,
        lastUsed TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE category_metadata (
        original TEXT PRIMARY KEY,
        displayName TEXT NOT NULL,
        isUserCreated INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert(
      'transactions',
      _txToDbMap(tx),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    final db = await database;
    await db.update(
      'transactions',
      _txToDbMap(tx),
      where: 'id = ?',
      whereArgs: [tx.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC, createdAt DESC');
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getTransactionsInPeriod(
      DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> upsertSuggestion({
    required String item,
    double? amount,
    String? categoryName,
  }) async {
    final db = await database;
    final existing = await db.query(
      'suggestions',
      where: 'item = ?',
      whereArgs: [item.toLowerCase()],
    );
    if (existing.isEmpty) {
      await db.insert('suggestions', {
        'item': item.toLowerCase(),
        'amount': amount,
        'categoryName': categoryName,
        'useCount': 1,
        'lastUsed': DateTime.now().toIso8601String(),
      });
    } else {
      final current = existing.first;
      await db.update(
        'suggestions',
        {
          'amount': amount ?? current['amount'],
          'categoryName': categoryName ?? current['categoryName'],
          'useCount': (current['useCount'] as int) + 1,
          'lastUsed': DateTime.now().toIso8601String(),
        },
        where: 'item = ?',
        whereArgs: [item.toLowerCase()],
      );
    }
  }

  Future<List<Map<String, dynamic>>> getTopSuggestions({int limit = 8}) async {
    final db = await database;
    return db.query(
      'suggestions',
      orderBy: 'useCount DESC, lastUsed DESC',
      limit: limit,
    );
  }

  Future<void> updateSuggestionPrice(String item, double amount) async {
    final db = await database;
    await db.update(
      'suggestions',
      {'amount': amount},
      where: 'item = ?',
      whereArgs: [item.toLowerCase()],
    );
  }

  Future<void> saveCategoryName(String original, String displayName,
      {bool isUserCreated = false}) async {
    final db = await database;
    await db.insert(
      'category_metadata',
      {
        'original': original,
        'displayName': displayName,
        'isUserCreated': isUserCreated ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getCategoryNames() async {
    final db = await database;
    final rows = await db.query('category_metadata');
    return {
      for (final r in rows)
        r['original'] as String: r['displayName'] as String,
    };
  }

  Future<List<String>> getUserCreatedCategories() async {
    final db = await database;
    final rows = await db.query(
      'category_metadata',
      where: 'isUserCreated = 1',
    );
    return rows.map((r) => r['original'] as String).toList();
  }

  Map<String, dynamic> _txToDbMap(TransactionModel tx) => {
    'id': tx.id,
    'rawInput': tx.rawInput,
    'transactionType': tx.transactionType,
    'intent': tx.intent,
    'item': tx.item,
    'amount': tx.amount,
    'date': tx.date.toIso8601String(),
    'dateExpression': tx.dateExpression,
    'needsClarification': tx.needsClarificationAsInt,
    'needsClarificationDetail': tx.needsClarification,
    'confidenceScore': tx.confidenceScore,
    'categoryName': tx.categoryName,
    'createdAt': tx.createdAt.toIso8601String(),
    'rawModelOutput': tx.rawModelOutput?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('||'),
  };

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('suggestions');
    await db.delete('category_metadata');
  }
}

