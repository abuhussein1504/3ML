import '../data/items_db.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final Map<String, String> _customNames = {};
  final List<String> _userCategories = [];
  final Map<String, String> _userCategoryIcons = {};

  void setCustomName(String original, String custom) {
    _customNames[original] = custom;
  }

  String getDisplayName(String original) => _customNames[original] ?? original;

  void addUserCategory(String name, {String? emoji}) {
    if (!_userCategories.contains(name) && !itemsDb.containsKey(name)) {
      _userCategories.add(name);
    }
    if (emoji != null && emoji.isNotEmpty) {
      _userCategoryIcons[name] = emoji;
    }
  }

  void setUserIcon(String categoryName, String emoji) {
    _userCategoryIcons[categoryName] = emoji;
  }

  List<String> get allCategories => [
        ...expenseCategories,
        'investment',
        'income',
        'other',
        ..._userCategories,
      ];

  List<String> get allCategoriesIncludingSpecial => [
        ...itemsDb.keys.where((k) => k != 'Unknown'),
        ..._userCategories,
      ];

  String categorize({
    required String transactionType,
    String? item,
    String? intent,
  }) {
    if (transactionType == 'Income') return 'Income';
    if (transactionType == 'Investment') return 'Investment';
    if (transactionType == 'Unknown') return 'Unknown';

    final searchTerms = [
      if (item != null) item.toLowerCase(),
      if (intent != null) intent.toLowerCase(),
    ];

    if (searchTerms.isEmpty) return 'Other';

    String bestCategory = 'Other';
    int bestScore = 0;

    for (final entry in itemsDb.entries) {
      if (entry.key == 'Unknown' ||
          entry.key == 'Income' ||
          entry.key == 'Investment') {
        continue;
      }

      for (final term in searchTerms) {
        for (final keyword in entry.value) {
          if (term == keyword) {
            return entry.key;
          }
          if (term.contains(keyword) || keyword.contains(term)) {
            final score = keyword.length;
            if (score > bestScore) {
              bestScore = score;
              bestCategory = entry.key;
            }
          }
        }
      }
    }
    return bestCategory;
  }

  String iconFor(String categoryName) =>
      _userCategoryIcons[categoryName] ?? categoryIcons[categoryName] ?? '🏷️';

  Map<String, dynamic> toJson() => {
        'customNames': _customNames,
        'userCategories': _userCategories,
        'userCategoryIcons': _userCategoryIcons,
      };

  void loadFromJson(Map<String, dynamic> json) {
    _customNames.clear();
    _userCategories.clear();
    _userCategoryIcons.clear();
    final names = json['customNames'] as Map<String, dynamic>?;
    if (names != null) {
      names.forEach((k, v) => _customNames[k] = v as String);
    }
    final cats = json['userCategories'] as List<dynamic>?;
    if (cats != null) {
      _userCategories.addAll(cats.cast<String>());
    }
    final icons = json['userCategoryIcons'] as Map<String, dynamic>?;
    if (icons != null) {
      icons.forEach((k, v) => _userCategoryIcons[k] = v as String);
    }
  }
}
