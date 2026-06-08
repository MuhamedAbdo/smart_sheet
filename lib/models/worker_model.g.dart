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
      hasMedicalInsurance: fields[4] == null ? false : fields[4] as bool,
      factoryId: fields[5] as String?,
      department: fields[7] as String,
      canAdd: fields[8] == null ? false : fields[8] as bool,
      canEdit: fields[9] == null ? false : fields[9] as bool,
      canDelete: fields[10] == null ? false : fields[10] as bool,
      email: fields[11] as String?,
      canManageClientsAdd: fields[12] == null ? false : fields[12] as bool,
      canManageClientsEdit: fields[13] == null ? false : fields[13] as bool,
      canManageClientsDelete: fields[14] == null ? false : fields[14] as bool,
    ).._actions = (fields[3] as HiveList?)?.castHiveList();
  }

  @override
  void write(BinaryWriter writer, Worker obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.id)
      ..writeByte(7)
      ..write(obj.department)
      ..writeByte(8)
      ..write(obj.canAdd)
      ..writeByte(9)
      ..write(obj.canEdit)
      ..writeByte(10)
      ..write(obj.canDelete)
      ..writeByte(11)
      ..write(obj.email)
      ..writeByte(12)
      ..write(obj.canManageClientsAdd)
      ..writeByte(13)
      ..write(obj.canManageClientsEdit)
      ..writeByte(14)
      ..write(obj.canManageClientsDelete);
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
