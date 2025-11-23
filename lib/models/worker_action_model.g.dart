// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_action_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkerActionAdapter extends TypeAdapter<WorkerAction> {
  @override
  final int typeId = 11;

  @override
  WorkerAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkerAction(
      type: fields[0] as String,
      days: fields[1] as double,
      date: fields[2] as DateTime,
      notes: fields[3] as String?,
      returnDate: fields[4] as DateTime?,
      startTimeHour: fields[5] as int?,
      startTimeMinute: fields[6] as int?,
      endTimeHour: fields[7] as int?,
      endTimeMinute: fields[8] as int?,
      amount: fields[9] as double?,
      bonusDays: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkerAction obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.days)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.returnDate)
      ..writeByte(5)
      ..write(obj.startTimeHour)
      ..writeByte(6)
      ..write(obj.startTimeMinute)
      ..writeByte(7)
      ..write(obj.endTimeHour)
      ..writeByte(8)
      ..write(obj.endTimeMinute)
      ..writeByte(9)
      ..write(obj.amount)
      ..writeByte(10)
      ..write(obj.bonusDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
