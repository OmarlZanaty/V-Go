// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_suggestion_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlaceSuggestionModelAdapter extends TypeAdapter<PlaceSuggestionModel> {
  @override
  final int typeId = 1;

  @override
  PlaceSuggestionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlaceSuggestionModel(
      placeId: fields[0] as String,
      description: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PlaceSuggestionModel obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.placeId)
      ..writeByte(1)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceSuggestionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
