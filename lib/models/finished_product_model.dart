// lib/src/models/finished_product_model.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'finished_product_model.g.dart';

@HiveType(typeId: 5) // ✅ استخدمTypeId فريد (5 مثلاً)
class FinishedProduct extends HiveObject {
  @HiveField(0)
  String? clientName;

  @HiveField(1)
  String? productName;

  @HiveField(2)
  String? operationOrder;

  @HiveField(3)
  String? productCode;

  @HiveField(4)
  double? length;

  @HiveField(5)
  double? width;

  @HiveField(6)
  double? height;

  @HiveField(7)
  int? count;

  @HiveField(8)
  List<String>? imagePaths;

  @HiveField(9)
  String? technician;

  @HiveField(10)
  String? notes;

  // ✅ إضافة الحقل الجديد
  @HiveField(11)
  String? dateBacker;

  FinishedProduct({
    this.clientName,
    this.productName,
    this.operationOrder,
    this.productCode,
    this.length,
    this.width,
    this.height,
    this.count,
    this.imagePaths,
    this.technician,
    this.notes,
    this.dateBacker, // ✅ إضافة الحقل إلى المُنشئ
  });

  Map<String, dynamic> toJson() {
    return {
      'clientName': clientName,
      'productName': productName,
      'operationOrder': operationOrder,
      'productCode': productCode,
      'length': length,
      'width': width,
      'height': height,
      'count': count,
      'imagePaths': imagePaths,
      'technician': technician,
      'notes': notes,
      'dateBacker': dateBacker, // ✅ إضافة الحقل إلى التحويل
    };
  }

  factory FinishedProduct.fromJson(Map<String, dynamic> map) {
    return FinishedProduct(
      clientName: map['clientName'],
      productName: map['productName'],
      operationOrder: map['operationOrder'],
      productCode: map['productCode'],
      length: map['length'] is int
          ? (map['length'] as int).toDouble()
          : map['length'],
      width:
          map['width'] is int ? (map['width'] as int).toDouble() : map['width'],
      height: map['height'] is int
          ? (map['height'] as int).toDouble()
          : map['height'],
      count: map['count'] is int
          ? map['count']
          : int.tryParse(map['count'].toString()) ?? 0,
      imagePaths: List<String>.from(map['imagePaths'] ?? []),
      technician: map['technician'],
      notes: map['notes'],
      dateBacker: map['dateBacker'], // ✅ إضافة الحقل من التحويل
    );
  }
}
