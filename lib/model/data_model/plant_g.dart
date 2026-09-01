// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-maintained Hive adapter. Fields 14–18 are additive and optional
// on read so existing 14-field / 15-field / 17-field records continue to load.

part of 'plant_model.dart';

class PlantAdapter extends TypeAdapter<Plant> {
  @override
  final int typeId = 0;

  @override
  Plant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final storedId = fields[14] as String?;
    final storedLocation = fields[16] as String?;
    return Plant(
      id: (storedId != null && storedId.isNotEmpty) ? storedId : null,
      name: fields[0] as String,
      scientificName: fields[1] as String,
      description: fields[2] as String,
      taxonomy: fields[3] is Map
          ? (fields[3] as Map).cast<String, dynamic>()
          : <String, dynamic>{},
      nativeRegion: fields[4] as String,
      growthSeason: fields[5] as String,
      toxicity: fields[6] as String,
      careGuide: fields[7] is Map
          ? (fields[7] as Map).cast<String, dynamic>()
          : <String, dynamic>{},
      healthScan: fields[8] as String,
      commonPests: fields[9] as String,
      commonDiseases: fields[10] as String,
      usage: fields[11] as String,
      funFact: fields[12] as String,
      imagePath: fields[13] as String?,
      placement: PlantWeatherContextEligibility.fromStored(fields[15]),
      locationId: (storedLocation != null && storedLocation.isNotEmpty)
          ? storedLocation
          : null,
      isHarvestable: fields[17] == true,
      cropId: fields[18] is String && (fields[18] as String).isNotEmpty
          ? fields[18] as String
          : null,
    );
  }

  @override
  void write(BinaryWriter writer, Plant obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.scientificName)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.taxonomy)
      ..writeByte(4)
      ..write(obj.nativeRegion)
      ..writeByte(5)
      ..write(obj.growthSeason)
      ..writeByte(6)
      ..write(obj.toxicity)
      ..writeByte(7)
      ..write(obj.careGuide)
      ..writeByte(8)
      ..write(obj.healthScan)
      ..writeByte(9)
      ..write(obj.commonPests)
      ..writeByte(10)
      ..write(obj.commonDiseases)
      ..writeByte(11)
      ..write(obj.usage)
      ..writeByte(12)
      ..write(obj.funFact)
      ..writeByte(13)
      ..write(obj.imagePath)
      ..writeByte(14)
      ..write(obj.id)
      ..writeByte(15)
      ..write(obj.placement.wireName)
      ..writeByte(16)
      ..write(obj.locationId)
      ..writeByte(17)
      ..write(obj.isHarvestable)
      ..writeByte(18)
      ..write(obj.cropId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
