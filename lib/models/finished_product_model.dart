// lib/src/models/finished_product_model.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'finished_product_model.g.dart';

@HiveType(typeId: 5)
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

  @HiveField(11)
  String? dateBacker;

  @HiveField(12)
  String? factoryId;

  @HiveField(13)
  String? id; // تم الإضافة للمزامنة

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
    this.dateBacker,
    this.factoryId,
    this.id,
  }) {
    id ??= const Uuid().v4(); // توليد معرف تلقائي لو لم يوجد
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sync_id': id,
      'client_name': clientName,
      'product_name': productName,
      'operation_order': operationOrder,
      'product_code': productCode,
      'length': length,
      'width': width,
      'height': height,
      'count': count,
      'image_paths': imagePaths,
      'technician': technician,
      'notes': notes,
      'date_backer': dateBacker,
      'factory_id': factoryId,
    };
  }

  factory FinishedProduct.fromJson(Map<String, dynamic> map) {
    try {
      return FinishedProduct(
        id: map['sync_id']?.toString() ?? map['id']?.toString(),
        clientName: map['client_name']?.toString() ?? map['clientName']?.toString() ?? '',
        productName: map['product_name']?.toString() ?? map['productName']?.toString() ?? '',
        operationOrder: map['operation_order']?.toString() ?? map['operationOrder']?.toString(),
        productCode: map['product_code']?.toString() ?? map['productCode']?.toString() ?? '',
        length: double.tryParse(map['length']?.toString() ?? ''),
        width: double.tryParse(map['width']?.toString() ?? ''),
        height: double.tryParse(map['height']?.toString() ?? ''),
        count: int.tryParse(map['count']?.toString() ?? '') ?? 0,
        imagePaths: map['image_paths'] is List ? List<String>.from(map['image_paths']) : (map['imagePaths'] is List ? List<String>.from(map['imagePaths']) : []),
        technician: map['technician']?.toString(),
        notes: map['notes']?.toString(),
        dateBacker: map['date_backer']?.toString() ?? map['dateBacker']?.toString(),
        factoryId: map['factory_id']?.toString() ?? map['factoryId']?.toString(),
      );
    } catch (e) {
      return FinishedProduct(
        id: map['sync_id']?.toString() ?? map['id']?.toString(),
        clientName: 'خطأ في البيانات',
      );
    }
  }
}
