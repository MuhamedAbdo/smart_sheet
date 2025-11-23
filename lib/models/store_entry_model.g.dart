// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'store_entry_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StoreEntryAdapter extends TypeAdapter<StoreEntry> {
  @override
  final int typeId = 4;

  @override
  StoreEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StoreEntry(
      date: fields[0] as String,
      product: fields[1] as String,
      unit: fields[2] as String,
      quantity: fields[3] as int,
      notes: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StoreEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.product)
      ..writeByte(2)
      ..write(obj.unit)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoreEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
