// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flexo_production_report.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlexoProductionReportAdapter extends TypeAdapter<FlexoProductionReport> {
  @override
  final int typeId = 3;

  @override
  FlexoProductionReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlexoProductionReport(
      id: fields[0] as String,
      factoryId: fields[1] as String,
      date: fields[2] as String,
      syncId: fields[3] as String?,
      createdBy: fields[4] as String?,
      department: fields[5] as String?,
      clientName: fields[6] as String,
      productName: fields[7] as String,
      productCode: fields[8] as String,
      orderNumber: fields[9] as String?,
      formNumber: fields[10] as String?,
      machineName: fields[11] as String?,
      technicianName: fields[12] as String?,
      startTime: fields[13] as String?,
      endTime: fields[14] as String?,
      quantity: fields[15] as int,
      lineWaste: fields[16] as int?,
      printWaste: fields[17] as int?,
      weight: fields[18] as double?,
      totalDowntime: fields[19] as int?,
      downtimeIntervals: (fields[20] as List?)?.cast<dynamic>(),
      elapsedTime: fields[21] as int?,
      netTime: fields[22] as int?,
      averageSpeed: fields[23] as double?,
      colors: fields[24] == null ? [] : (fields[24] as List).cast<dynamic>(),
      dimensions:
          fields[25] == null ? {} : (fields[25] as Map).cast<String, dynamic>(),
      paperLayers: (fields[26] as List?)?.cast<dynamic>(),
      rollWidth: fields[27] as double?,
      imagePaths: (fields[28] as List?)?.cast<dynamic>(),
      isSheet: fields[29] as bool?,
      notes: fields[30] as String?,
      crewMembers: (fields[31] as List?)?.cast<String>(),
      shiftName: fields[32] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FlexoProductionReport obj) {
    writer
      ..writeByte(33)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.factoryId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.syncId)
      ..writeByte(4)
      ..write(obj.createdBy)
      ..writeByte(5)
      ..write(obj.department)
      ..writeByte(6)
      ..write(obj.clientName)
      ..writeByte(7)
      ..write(obj.productName)
      ..writeByte(8)
      ..write(obj.productCode)
      ..writeByte(9)
      ..write(obj.orderNumber)
      ..writeByte(10)
      ..write(obj.formNumber)
      ..writeByte(11)
      ..write(obj.machineName)
      ..writeByte(12)
      ..write(obj.technicianName)
      ..writeByte(13)
      ..write(obj.startTime)
      ..writeByte(14)
      ..write(obj.endTime)
      ..writeByte(15)
      ..write(obj.quantity)
      ..writeByte(16)
      ..write(obj.lineWaste)
      ..writeByte(17)
      ..write(obj.printWaste)
      ..writeByte(18)
      ..write(obj.weight)
      ..writeByte(19)
      ..write(obj.totalDowntime)
      ..writeByte(20)
      ..write(obj.downtimeIntervals)
      ..writeByte(21)
      ..write(obj.elapsedTime)
      ..writeByte(22)
      ..write(obj.netTime)
      ..writeByte(23)
      ..write(obj.averageSpeed)
      ..writeByte(24)
      ..write(obj.colors)
      ..writeByte(25)
      ..write(obj.dimensions)
      ..writeByte(26)
      ..write(obj.paperLayers)
      ..writeByte(27)
      ..write(obj.rollWidth)
      ..writeByte(28)
      ..write(obj.imagePaths)
      ..writeByte(29)
      ..write(obj.isSheet)
      ..writeByte(30)
      ..write(obj.notes)
      ..writeByte(31)
      ..write(obj.crewMembers)
      ..writeByte(32)
      ..write(obj.shiftName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlexoProductionReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
