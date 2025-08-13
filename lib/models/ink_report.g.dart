// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ink_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InkReportAdapter extends TypeAdapter<InkReport> {
  @override
  final int typeId = 3;

  @override
  InkReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InkReport(
      id: fields[0] as String,
      date: fields[1] as String,
      clientName: fields[2] as String,
      product: fields[3] as String,
      productCode: fields[4] as String,
      dimensions: (fields[5] as Map).cast<String, dynamic>(),
      colors: (fields[6] as List)
          .map((dynamic e) => (e as Map).cast<String, double>())
          .toList(),
      quantity: fields[7] as int,
      notes: fields[8] as String?,
      imageUrls: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, InkReport obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.clientName)
      ..writeByte(3)
      ..write(obj.product)
      ..writeByte(4)
      ..write(obj.productCode)
      ..writeByte(5)
      ..write(obj.dimensions)
      ..writeByte(6)
      ..write(obj.colors)
      ..writeByte(7)
      ..write(obj.quantity)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.imageUrls);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InkReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
