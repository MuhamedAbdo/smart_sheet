// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceRecordAdapter extends TypeAdapter<MaintenanceRecord> {
  @override
  final int typeId = 6;

  @override
  MaintenanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceRecord(
      id: fields[12] as String?,
      machine: fields[0] as String,
      isFixed: fields[1] as bool,
      issueDate: fields[2] as String,
      reportDate: fields[3] as String,
      actionDate: fields[4] as String,
      issueDescription: fields[5] as String,
      actionTaken: fields[6] as String,
      repairLocation: fields[7] as String,
      repairedBy: fields[8] as String,
      reportedToTechnician: fields[9] as String,
      notes: fields[10] as String?,
      imagePaths: (fields[11] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.machine)
      ..writeByte(1)
      ..write(obj.isFixed)
      ..writeByte(2)
      ..write(obj.issueDate)
      ..writeByte(3)
      ..write(obj.reportDate)
      ..writeByte(4)
      ..write(obj.actionDate)
      ..writeByte(5)
      ..write(obj.issueDescription)
      ..writeByte(6)
      ..write(obj.actionTaken)
      ..writeByte(7)
      ..write(obj.repairLocation)
      ..writeByte(8)
      ..write(obj.repairedBy)
      ..writeByte(9)
      ..write(obj.reportedToTechnician)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.imagePaths)
      ..writeByte(12)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
