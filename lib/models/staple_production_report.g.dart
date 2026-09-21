// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staple_production_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StapleProductionReportAdapter
    extends TypeAdapter<StapleProductionReport> {
  @override
  final int typeId = 27;

  @override
  StapleProductionReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StapleProductionReport(
      id: fields[0] as String,
      machineName: fields[1] as String,
      technicianName: fields[2] as String,
      reportDate: fields[3] as DateTime,
      customerName: fields[4] as String,
      itemName: fields[5] as String,
      itemCode: fields[6] as String,
      orderNumber: fields[7] as String,
      runTimeStart: fields[8] as DateTime?,
      runTimeEnd: fields[9] as DateTime?,
      downtimeStart: fields[10] as DateTime?,
      downtimeEnd: fields[11] as DateTime?,
      productionQuantity: fields[12] as double,
      wasteQuantity: fields[13] as double,
      notes: fields[14] as String?,
      factoryId: fields[15] as String?,
      dimensions: (fields[16] as Map?)?.cast<String, dynamic>(),
      crewMembers: (fields[17] as List?)?.cast<String>(),
      shiftName: fields[18] as String?,
      status: fields[19] == null ? 'approved' : fields[19] as String,
    );
  }

  @override
  void write(BinaryWriter writer, StapleProductionReport obj) {
    writer
      ..writeByte(20)
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
      ..write(obj.orderNumber)
      ..writeByte(8)
      ..write(obj.runTimeStart)
      ..writeByte(9)
      ..write(obj.runTimeEnd)
      ..writeByte(10)
      ..write(obj.downtimeStart)
      ..writeByte(11)
      ..write(obj.downtimeEnd)
      ..writeByte(12)
      ..write(obj.productionQuantity)
      ..writeByte(13)
      ..write(obj.wasteQuantity)
      ..writeByte(14)
      ..write(obj.notes)
      ..writeByte(15)
      ..write(obj.factoryId)
      ..writeByte(16)
      ..write(obj.dimensions)
      ..writeByte(17)
      ..write(obj.crewMembers)
      ..writeByte(18)
      ..write(obj.shiftName)
      ..writeByte(19)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StapleProductionReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
