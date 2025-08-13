// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maintenance_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaintenanceRecordAdapter extends TypeAdapter<MaintenanceRecord> {
  @override
  final int typeId = 0;

  @override
  MaintenanceRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaintenanceRecord(
      date: fields[0] as String,
      machine: fields[1] as String,
      issue: fields[2] as String,
      technician: fields[3] as String,
      action: fields[4] as String,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MaintenanceRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.machine)
      ..writeByte(2)
      ..write(obj.issue)
      ..writeByte(3)
      ..write(obj.technician)
      ..writeByte(4)
      ..write(obj.action)
      ..writeByte(5)
      ..write(obj.notes);
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
