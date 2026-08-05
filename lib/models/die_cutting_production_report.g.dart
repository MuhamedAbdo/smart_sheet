// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'die_cutting_production_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DieCuttingProductionReportAdapter
    extends TypeAdapter<DieCuttingProductionReport> {
  @override
  final int typeId = 25;

  @override
  DieCuttingProductionReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DieCuttingProductionReport(
      id: fields[0] as String,
      machineName: fields[1] as String,
      technicianName: fields[2] as String,
      reportDate: fields[3] as DateTime,
      customerName: fields[4] as String,
      itemName: fields[5] as String,
      itemCode: fields[6] as String,
      formNumber: fields[7] as String,
      workOrder: fields[8] as String,
      runTimeStart: fields[9] as DateTime?,
      runTimeEnd: fields[10] as DateTime?,
      downtimeStart: fields[11] as DateTime?,
      downtimeEnd: fields[12] as DateTime?,
      productionQuantity: fields[13] as double,
      wasteQuantity: fields[14] as double,
      notes: fields[15] as String?,
      factoryId: fields[16] as String?,
      dimensions: (fields[17] as Map?)?.cast<String, dynamic>(),
      crewMembers: (fields[18] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DieCuttingProductionReport obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.machineName)
      ..writeByte(2)
      ..write(obj.technicianName)
      ..writeByte(3)
      ..write(obj.reportDate)
      ..writeByte(4)
      ..write(obj.customerName)
      ..writeByte(5)
      ..write(obj.itemName)
      ..writeByte(6)
      ..write(obj.itemCode)
      ..writeByte(7)
      ..write(obj.formNumber)
      ..writeByte(8)
      ..write(obj.workOrder)
      ..writeByte(9)
      ..write(obj.runTimeStart)
      ..writeByte(10)
      ..write(obj.runTimeEnd)
      ..writeByte(11)
      ..write(obj.downtimeStart)
      ..writeByte(12)
      ..write(obj.downtimeEnd)
      ..writeByte(13)
      ..write(obj.productionQuantity)
      ..writeByte(14)
      ..write(obj.wasteQuantity)
      ..writeByte(15)
      ..write(obj.notes)
      ..writeByte(16)
      ..write(obj.factoryId)
      ..writeByte(17)
      ..write(obj.dimensions)
      ..writeByte(18)
      ..write(obj.crewMembers);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DieCuttingProductionReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
