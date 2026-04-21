// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'production_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductionReportAdapter extends TypeAdapter<ProductionReport> {
  @override
  final int typeId = 3;

  @override
  ProductionReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductionReport(
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
      orderNumber: fields[9] as String?,
      startTime: fields[10] as String?,
      endTime: fields[11] as String?,
      lineWaste: fields[12] as int?,
      printWaste: fields[13] as int?,
      downtimeStart: fields[14] as String?,
      downtimeEnd: fields[15] as String?,
      machineName: fields[16] as String?,
      technicianName: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductionReport obj) {
    writer
      ..writeByte(18)
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
      ..write(obj.orderNumber)
      ..writeByte(10)
      ..write(obj.startTime)
      ..writeByte(11)
      ..write(obj.endTime)
      ..writeByte(12)
      ..write(obj.lineWaste)
      ..writeByte(13)
      ..write(obj.printWaste)
      ..writeByte(14)
      ..write(obj.downtimeStart)
      ..writeByte(15)
      ..write(obj.downtimeEnd)
      ..writeByte(16)
      ..write(obj.machineName)
      ..writeByte(17)
      ..write(obj.technicianName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductionReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
