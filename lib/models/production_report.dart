// lib/models/production_report.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'production_report.g.dart';

@HiveType(typeId: 3)
class ProductionReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String date;

  @HiveField(2)
  final String clientName;

  @HiveField(3)
  final String product;

  @HiveField(4)
  final String productCode;

  @HiveField(5)
  final Map<String, dynamic> dimensions;

  @HiveField(6)
  final List<Map<String, double>> colors;

  @HiveField(7)
  final int quantity;

  @HiveField(8)
  final String? notes;

  @HiveField(9)
  final String? orderNumber;

  @HiveField(10)
  final String? startTime;

  @HiveField(11)
  final String? endTime;

  @HiveField(12)
  final int? lineWaste;

  @HiveField(13)
  final int? printWaste;

  @HiveField(14)
  final String? downtimeStart;

  @HiveField(15)
  final String? downtimeEnd;

  @HiveField(16)
  final String? machineName;

  @HiveField(17)
  final String? technicianName;

  @HiveField(18)
  final String? factoryId;

  ProductionReport({
    required this.id,
    required this.date,
    required this.clientName,
    required this.product,
    required this.productCode,
    required this.dimensions,
    required this.colors,
    required this.quantity,
    this.notes,
    this.orderNumber,
    this.startTime,
    this.endTime,
    this.lineWaste,
    this.printWaste,
    this.downtimeStart,
    this.downtimeEnd,
    this.machineName,
    this.technicianName,
    this.factoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'client_name': clientName,
      'product': product,
      'product_code': productCode,
      'dimensions': dimensions,
      'colors': colors,
      'quantity': quantity,
      'notes': notes,
      'order_number': orderNumber,
      'start_time': startTime,
      'end_time': endTime,
      'line_waste': lineWaste,
      'print_waste': printWaste,
      'downtime_start': downtimeStart,
      'downtime_end': downtimeEnd,
      'machine_name': machineName,
      'technician_name': technicianName,
      'factory_id': factoryId,
    };
  }

  factory ProductionReport.fromJson(Map<String, dynamic> map) {
    // معالجة قائمة الألوان بأمان لضمان عدم حدوث Type Error
    List<dynamic> colorsList = map['colors'] ?? [];
    List<Map<String, double>> parsedColors =
        colorsList.map<Map<String, double>>((item) {
      if (item is Map) {
        return item
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    }).toList();

    return ProductionReport(
      id: map['id']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      // الأولوية دائماً لتنسيق السيرفر (snake_case)
      clientName: map['client_name'] ?? map['clientName'] ?? '',
      product: map['product'] ?? '',
      productCode: map['product_code'] ?? map['productCode'] ?? '',
      dimensions: map['dimensions'] is Map
          ? Map<String, dynamic>.from(map['dimensions'])
          : {},
      colors: parsedColors,
      // ضمان أن القيمة int وليست null
      quantity: _toInt(map['quantity']) ?? 0,
      notes: map['notes']?.toString(),
      orderNumber: (map['order_number'] ?? map['orderNumber'])?.toString(),
      startTime: (map['start_time'] ?? map['startTime'])?.toString(),
      endTime: (map['end_time'] ?? map['endTime'])?.toString(),
      lineWaste: _toInt(map['line_waste'] ?? map['lineWaste']),
      printWaste: _toInt(map['print_waste'] ?? map['printWaste']),
      downtimeStart:
          (map['downtime_start'] ?? map['downtimeStart'])?.toString(),
      downtimeEnd: (map['downtime_end'] ?? map['downtimeEnd'])?.toString(),
      machineName: (map['machine_name'] ?? map['machineName'])?.toString(),
      technicianName:
          (map['technician_name'] ?? map['technicianName'])?.toString(),
      factoryId: (map['factory_id'] ?? map['factoryId'])?.toString(),
    );
  }

  // دالة مساعدة قوية لتحويل أي نوع بيانات إلى int
  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }
}
