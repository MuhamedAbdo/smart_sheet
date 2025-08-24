// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'color_quantity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ColorQuantityAdapter extends TypeAdapter<ColorQuantity> {
  @override
  final int typeId = 6;

  @override
  ColorQuantity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ColorQuantity(
      color: fields[0] as String,
      quantity: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, ColorQuantity obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.color)
      ..writeByte(1)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColorQuantityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
