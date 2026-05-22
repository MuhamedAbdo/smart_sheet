// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkerAdapter extends TypeAdapter<Worker> {
  @override
  final int typeId = 1;

  @override
  Worker read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Worker(
      id: fields[6] as String?,
      name: fields[0] as String,
      phone: fields[1] as String,
      job: fields[2] as String,
      hasMedicalInsurance: fields[4] as bool,
      factoryId: fields[5] as String?,
    ).._actions = (fields[3] as HiveList?)?.castHiveList();
  }

  @override
  void write(BinaryWriter writer, Worker obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.phone)
      ..writeByte(2)
      ..write(obj.job)
      ..writeByte(3)
      ..write(obj._actions)
      ..writeByte(4)
      ..write(obj.hasMedicalInsurance)
      ..writeByte(5)
      ..write(obj.factoryId)
      ..writeByte(6)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
