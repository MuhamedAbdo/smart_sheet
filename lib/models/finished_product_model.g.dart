// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finished_product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FinishedProductAdapter extends TypeAdapter<FinishedProduct> {
  @override
  final int typeId = 5;

  @override
  FinishedProduct read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FinishedProduct(
      clientName: fields[0] as String?,
      productName: fields[1] as String?,
      operationOrder: fields[2] as String?,
      productCode: fields[3] as String?,
      length: fields[4] as double?,
      width: fields[5] as double?,
      height: fields[6] as double?,
      count: fields[7] as int?,
      imagePaths: (fields[8] as List?)?.cast<String>(),
      technician: fields[9] as String?,
      notes: fields[10] as String?,
      dateBacker: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FinishedProduct obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.clientName)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.operationOrder)
      ..writeByte(3)
      ..write(obj.productCode)
      ..writeByte(4)
      ..write(obj.length)
      ..writeByte(5)
      ..write(obj.width)
      ..writeByte(6)
      ..write(obj.height)
      ..writeByte(7)
      ..write(obj.count)
      ..writeByte(8)
      ..write(obj.imagePaths)
      ..writeByte(9)
      ..write(obj.technician)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.dateBacker);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinishedProductAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
