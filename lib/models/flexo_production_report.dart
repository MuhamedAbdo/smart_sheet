import 'package:hive_flutter/hive_flutter.dart';

part 'flexo_production_report.g.dart';

@HiveType(typeId: 3)
class FlexoProductionReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String factoryId;

  @HiveField(2)
  final String date;

  @HiveField(3)
  final String? syncId;

  @HiveField(4)
  final String? createdBy;

  @HiveField(5)
  final String? department;

  @HiveField(6)
  final String clientName;

  @HiveField(7)
  final String productName;

  @HiveField(8)
  final String productCode;

  @HiveField(9)
  final String? orderNumber;

  @HiveField(10)
  final String? formNumber;

  @HiveField(11)
  final String? machineName;

  @HiveField(12)
  final String? technicianName;

  @HiveField(13)
  final String? startTime;

  @HiveField(14)
  final String? endTime;

  @HiveField(15)
  final int quantity;

  @HiveField(16)
  final int? lineWaste;

  @HiveField(17)
  final int? printWaste;

  @HiveField(18)
  final double? weight;

  @HiveField(19)
  final int? totalDowntime;

  @HiveField(20)
  final List<dynamic>? downtimeIntervals;

  @HiveField(21)
  final int? elapsedTime;

  @HiveField(22)
  final int? netTime;

  @HiveField(23)
  final double? averageSpeed;

  @HiveField(24, defaultValue: [])
  final List<dynamic> colors;

  @HiveField(25, defaultValue: {})
  final Map<String, dynamic> dimensions;

  @HiveField(26)
  final List<dynamic>? paperLayers;

  @HiveField(27)
  final double? rollWidth;

  @HiveField(28)
  final List<dynamic>? imagePaths;

  @HiveField(29)
  final bool? isSheet;

  @HiveField(30)
  final String? notes;

  FlexoProductionReport({
    required this.id,
    required this.factoryId,
    required this.date,
    this.syncId,
    this.createdBy,
    this.department,
    required this.clientName,
    required this.productName,
    required this.productCode,
    this.orderNumber,
    this.formNumber,
    this.machineName,
    this.technicianName,
    this.startTime,
    this.endTime,
    required this.quantity,
    this.lineWaste,
    this.printWaste,
    this.weight,
    this.totalDowntime,
    this.downtimeIntervals,
    this.elapsedTime,
    this.netTime,
    this.averageSpeed,
    required this.colors,
    required this.dimensions,
    this.paperLayers,
    this.rollWidth,
    this.imagePaths,
    this.isSheet,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factory_id': factoryId,
      'date': date,
      'sync_id': syncId ?? id,
      'created_by': createdBy,
      'department': department ?? 'flexo',
      'client_name': clientName,
      'product_name': productName,
      'product_code': productCode,
      'order_number': orderNumber,
      'form_number': formNumber,
      'machine_name': machineName,
      'technician_name': technicianName,
      'start_time': startTime,
      'end_time': endTime,
      'quantity': quantity,
      'line_waste': lineWaste,
      'print_waste': printWaste,
      'weight': weight,
      'total_downtime': totalDowntime,
      'downtime_intervals': downtimeIntervals ?? [],
      'elapsed_time': elapsedTime,
      'net_time': netTime,
      'average_speed': averageSpeed,
      'colors': colors,
      'dimensions': dimensions,
      'paper_layers': paperLayers ?? [],
      'roll_width': rollWidth,
      'image_paths': imagePaths ?? [],
      'is_sheet': isSheet ?? false,
      'notes': notes,
    };
  }

  factory FlexoProductionReport.fromJson(Map<String, dynamic> map) {
    return FlexoProductionReport(
      id: map['id']?.toString() ?? map['sync_id']?.toString() ?? '',
      factoryId: map['factory_id']?.toString() ?? map['factoryId']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      syncId: map['sync_id']?.toString() ?? map['syncId']?.toString(),
      createdBy: map['created_by']?.toString() ?? map['createdBy']?.toString(),
      department: map['department']?.toString(),
      clientName: map['client_name']?.toString() ?? map['clientname']?.toString() ?? map['clientName']?.toString() ?? '---',
      productName: map['product']?.toString() ?? map['product_name']?.toString() ?? map['productname']?.toString() ?? map['productName']?.toString() ?? '---',
      productCode: map['product_code']?.toString() ?? map['productcode']?.toString() ?? map['productCode']?.toString() ?? '---',
      orderNumber: map['order_number']?.toString() ?? map['ordernumber']?.toString() ?? map['orderNumber']?.toString(),
      formNumber: map['form_number']?.toString() ?? map['formnumber']?.toString() ?? map['formNumber']?.toString(),
      machineName: map['machine_name']?.toString() ?? map['machinename']?.toString() ?? map['machineName']?.toString(),
      technicianName: map['technician_name']?.toString() ?? map['technicianname']?.toString() ?? map['technicianName']?.toString(),
      startTime: map['start_time']?.toString() ?? map['starttime']?.toString() ?? map['startTime']?.toString(),
      endTime: map['end_time']?.toString() ?? map['endtime']?.toString() ?? map['endTime']?.toString(),
      quantity: _toInt(map['quantity']) ?? 0,
      lineWaste: _toInt(map['line_waste']) ?? _toInt(map['linewaste']) ?? _toInt(map['lineWaste']),
      printWaste: _toInt(map['print_waste']) ?? _toInt(map['printwaste']) ?? _toInt(map['printWaste']),
      weight: _toDouble(map['weight']),
      totalDowntime: _toInt(map['total_downtime']) ?? _toInt(map['totaldowntime']) ?? _toInt(map['totalDowntime']),
      downtimeIntervals: (map['downtime_intervals'] ?? map['downtimeIntervals']) is List ? (map['downtime_intervals'] ?? map['downtimeIntervals']) as List<dynamic> : null,
      elapsedTime: _toInt(map['elapsed_time']) ?? _toInt(map['elapsedtime']) ?? _toInt(map['elapsedTime']),
      netTime: _toInt(map['net_time']) ?? _toInt(map['nettime']) ?? _toInt(map['netTime']),
      averageSpeed: _toDouble(map['average_speed']) ?? _toDouble(map['averagespeed']) ?? _toDouble(map['averageSpeed']),
      colors: map['colors'] is List ? map['colors'] as List<dynamic> : [],
      dimensions: map['dimensions'] is Map ? Map<String, dynamic>.from(map['dimensions']) : {},
      paperLayers: (map['paper_layers'] ?? map['paperLayers']) is List ? (map['paper_layers'] ?? map['paperLayers']) as List<dynamic> : null,
      rollWidth: _toDouble(map['roll_width']) ?? _toDouble(map['rollwidth']) ?? _toDouble(map['rollWidth']),
      imagePaths: (map['image_paths'] ?? map['imagePaths']) is List ? (map['image_paths'] ?? map['imagePaths']) as List<dynamic> : null,
      isSheet: map['is_sheet'] == true || map['isSheet'] == true,
      notes: map['notes']?.toString(),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
