// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'die_cutting_form.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DieCuttingFormAdapter extends TypeAdapter<DieCuttingForm> {
  @override
  final int typeId = 20;

  @override
  DieCuttingForm read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DieCuttingForm(
      id: fields[0] as String,
      formNumber: fields[1] as String,
      length: fields[2] as double,
      width: fields[3] as double,
      height: fields[4] as double,
      sheetLength: fields[5] as double,
      sheetWidth: fields[6] as double,
      numberOfBoxes: fields[7] as double,
      isSheet: fields[8] as bool,
      shelfLocation: fields[9] as String?,
      customerName: fields[10] as String?,
      customerCode: fields[11] as String?,
      itemName: fields[12] as String?,
      itemCode: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DieCuttingForm obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.formNumber)
      ..writeByte(2)
      ..write(obj.length)
      ..writeByte(3)
      ..write(obj.width)
      ..writeByte(4)
      ..write(obj.height)
      ..writeByte(5)
      ..write(obj.sheetLength)
      ..writeByte(6)
      ..write(obj.sheetWidth)
      ..writeByte(7)
      ..write(obj.numberOfBoxes)
      ..writeByte(8)
      ..write(obj.isSheet)
      ..writeByte(9)
      ..write(obj.shelfLocation)
      ..writeByte(10)
      ..write(obj.customerName)
      ..writeByte(11)
      ..write(obj.customerCode)
      ..writeByte(12)
      ..write(obj.itemName)
      ..writeByte(13)
      ..write(obj.itemCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DieCuttingFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
