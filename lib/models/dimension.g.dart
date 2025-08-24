// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dimension.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DimensionAdapter extends TypeAdapter<Dimension> {
  @override
  final int typeId = 5;

  @override
  Dimension read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dimension(
      length: fields[0] as double,
      width: fields[1] as double,
      height: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Dimension obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.length)
      ..writeByte(1)
      ..write(obj.width)
      ..writeByte(2)
      ..write(obj.height);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DimensionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
