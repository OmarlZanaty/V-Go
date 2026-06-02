import 'package:hive/hive.dart';

part 'place_suggestion_model.g.dart';

@HiveType(typeId: 1) // غير الرقم لو عندك موديلات أخرى
class PlaceSuggestionModel {
  @HiveField(0)
  final String placeId;

  @HiveField(1)
  final String description;

  PlaceSuggestionModel({
    required this.placeId,
    required this.description,
  });
}
