// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LiveSessionAdapter extends TypeAdapter<LiveSession> {
  @override
  final int typeId = 17;

  @override
  LiveSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LiveSession(
      id: fields[0] as String,
      machineName: fields[1] as String,
      clientName: fields[2] as String,
      productName: fields[3] as String,
      productCode: fields[4] as String,
      orderNumber: fields[5] as String,
      technicianName: fields[6] as String,
      startTime: fields[7] as DateTime,
      downtimeIntervals: (fields[8] as List).cast<DowntimeInterval>(),
      isRunning: fields[9] as bool,
      lastStateChange: fields[10] as DateTime,
      dimensions: (fields[11] as Map?)?.cast<String, dynamic>(),
      isSheet: fields[12] as bool?,
      imagePaths: (fields[13] as List?)?.cast<String>(),
      factoryId: fields[14] as String?,
      createdByDeviceId: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LiveSession obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.machineName)
      ..writeByte(2)
      ..write(obj.clientName)
      ..writeByte(3)
      ..write(obj.productName)
      ..writeByte(4)
      ..write(obj.productCode)
      ..writeByte(5)
      ..write(obj.orderNumber)
      ..writeByte(6)
      ..write(obj.technicianName)
      ..writeByte(7)
      ..write(obj.startTime)
      ..writeByte(8)
      ..write(obj.downtimeIntervals)
      ..writeByte(9)
      ..write(obj.isRunning)
      ..writeByte(10)
      ..write(obj.lastStateChange)
      ..writeByte(11)
      ..write(obj.dimensions)
      ..writeByte(12)
      ..write(obj.isSheet)
      ..writeByte(13)
      ..write(obj.imagePaths)
      ..writeByte(14)
      ..write(obj.factoryId)
      ..writeByte(15)
      ..write(obj.createdByDeviceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
