// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ShiftAdapter extends TypeAdapter<Shift> {
  @override
  final int typeId = 26;

  @override
  Shift read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Shift(
      name: fields[0] as String,
      startTime: fields[1] as String,
      endTime: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Shift obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DayScheduleAdapter extends TypeAdapter<DaySchedule> {
  @override
  final int typeId = 18;

  @override
  DaySchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DaySchedule(
      dayName: fields[0] as String,
      isWorkingDay: fields[1] as bool,
      shiftStart: fields[2] as String,
      shiftEnd: fields[3] as String,
      shifts: (fields[4] as List?)?.cast<Shift>(),
      shiftNames: (fields[5] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DaySchedule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.dayName)
      ..writeByte(1)
      ..write(obj.isWorkingDay)
      ..writeByte(2)
      ..write(obj.shiftStart)
      ..writeByte(3)
      ..write(obj.shiftEnd)
      ..writeByte(4)
      ..write(obj.shifts)
      ..writeByte(5)
      ..write(obj.shiftNames);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
