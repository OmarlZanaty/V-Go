import 'package:hive_flutter/adapters.dart';

import '../../features/map/data/model/place_suggestion_model.dart';
import '../utils/app_constants.dart';

class HiveService {
  static const String _boxName = 'search_history';
  static const int _maxItems = 10;

  static Box<PlaceSuggestionModel> get _box =>
      Hive.box<PlaceSuggestionModel>(_boxName);

  static Future<void> initHive() async {
    Hive.registerAdapter(PlaceSuggestionModelAdapter());
    await Hive.initFlutter();
    await Hive.openBox<PlaceSuggestionModel>(_boxName);
  }

  /// Adds a search entry for a specific user
  static Future<void> addSearch(PlaceSuggestionModel model) async {
    final userKeyPrefix = '${AppConstants.kUserId}-';
    final userHistoryKeys = _box.keys
        .where((key) => key.toString().startsWith(userKeyPrefix))
        .toList();

    // Check if the place already exists in the user's history
    final existingKey = userHistoryKeys.firstWhere(
      (key) => _box.get(key)?.placeId == model.placeId,
      orElse: () => null,
    );

    if (existingKey != null) {
      await _box.delete(existingKey);
    }

    // If the user's history exceeds max items, remove the oldest
    if (userHistoryKeys.length >= _maxItems) {
      await _box.delete(userHistoryKeys.first);
    }

    // Add new search with user-specific key
    await _box.put(
      '$userKeyPrefix${DateTime.now().millisecondsSinceEpoch}',
      model,
    );
  }

  /// Retrieves search history for a specific user
  static List<PlaceSuggestionModel> getHistory() {
    final userKeyPrefix = '${AppConstants.kUserId}-';
    return _box.values
        .where(
          (model) => _box.keys
              .where((key) => key.toString().startsWith(userKeyPrefix))
              .any((key) => _box.get(key)?.placeId == model.placeId),
        )
        .toList()
        .reversed
        .toList();
  }

  /// Clears search history for a specific user
  static Future<void> clearHistory() async {
    final userKeyPrefix = '${AppConstants.kUserId}-';
    final keysToDelete = _box.keys
        .where((key) => key.toString().startsWith(userKeyPrefix))
        .toList();
    await _box.deleteAll(keysToDelete);
  }
}
