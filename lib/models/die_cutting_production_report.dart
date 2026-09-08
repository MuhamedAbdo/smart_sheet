import 'package:hive_flutter/hive_flutter.dart';

part 'die_cutting_production_report.g.dart';

@HiveType(typeId: 25)
class DieCuttingProductionReport extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String machineName;

  @HiveField(2)
  final String technicianName;

  @HiveField(3)
  final DateTime reportDate;

  @HiveField(4)
  final String customerName;

  @HiveField(5)
  final String itemName;

  @HiveField(6)
  final String itemCode;

  @HiveField(7)
  final String formNumber;

  @HiveField(8)
  final String workOrder;

  @HiveField(9)
  final DateTime? runTimeStart;

  @HiveField(10)
  final DateTime? runTimeEnd;

  @HiveField(11)
  final DateTime? downtimeStart;

  @HiveField(12)
  final DateTime? downtimeEnd;

  @HiveField(13)
  final double productionQuantity;

  @HiveField(14)
  final double wasteQuantity;

  @HiveField(15)
  final String? notes;

  @HiveField(16)
  final String? factoryId;

  @HiveField(17)
  final Map<String, dynamic>? dimensions;

  @HiveField(18)
  final List<String>? crewMembers;

  @HiveField(19)
  final String? shiftName;

  @HiveField(20, defaultValue: 'approved')
  final String status;

  DieCuttingProductionReport({
    required this.id,
    required this.machineName,
    required this.technicianName,
    required this.reportDate,
    required this.customerName,
    required this.itemName,
    required this.itemCode,
    required this.formNumber,
    required this.workOrder,
    this.runTimeStart,
    this.runTimeEnd,
    this.downtimeStart,
    this.downtimeEnd,
    required this.productionQuantity,
    required this.wasteQuantity,
    this.notes,
    this.factoryId,
    this.dimensions,
    this.crewMembers,
    this.shiftName,
    this.status = 'approved',
  });

  DieCuttingProductionReport copyWith({
    String? id,
    String? machineName,
    String? technicianName,
    DateTime? reportDate,
    String? customerName,
    String? itemName,
    String? itemCode,
    String? formNumber,
    String? workOrder,
    DateTime? runTimeStart,
    DateTime? runTimeEnd,
    DateTime? downtimeStart,
    DateTime? downtimeEnd,
    double? productionQuantity,
    double? wasteQuantity,
    String? notes,
    String? factoryId,
    Map<String, dynamic>? dimensions,
    List<String>? crewMembers,
    String? shiftName,
    String? status,
  }) {
    return DieCuttingProductionReport(
      id: id ?? this.id,
      machineName: machineName ?? this.machineName,
      technicianName: technicianName ?? this.technicianName,
      reportDate: reportDate ?? this.reportDate,
      customerName: customerName ?? this.customerName,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      formNumber: formNumber ?? this.formNumber,
      workOrder: workOrder ?? this.workOrder,
      runTimeStart: runTimeStart ?? this.runTimeStart,
      runTimeEnd: runTimeEnd ?? this.runTimeEnd,
      downtimeStart: downtimeStart ?? this.downtimeStart,
      downtimeEnd: downtimeEnd ?? this.downtimeEnd,
      productionQuantity: productionQuantity ?? this.productionQuantity,
      wasteQuantity: wasteQuantity ?? this.wasteQuantity,
      notes: notes ?? this.notes,
      factoryId: factoryId ?? this.factoryId,
      dimensions: dimensions ?? this.dimensions,
      crewMembers: crewMembers ?? this.crewMembers,
      shiftName: shiftName ?? this.shiftName,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(),
      'sync_id': id.toString(),
      'factory_id': factoryId,
      'report_date': reportDate.toIso8601String(),
      'machine_name': machineName,
      'technician_name': technicianName,
      'customer_name': customerName,
      'item_name': itemName,
      'item_code': itemCode,
      'form_number': formNumber,
      'work_order': workOrder,
      'run_time_start': runTimeStart?.toIso8601String(),
      'run_time_end': runTimeEnd?.toIso8601String(),
      'downtime_start': downtimeStart?.toIso8601String(),
      'downtime_end': downtimeEnd?.toIso8601String(),
      'production_quantity': productionQuantity,
      'waste_quantity': wasteQuantity,
      'notes': notes,
      'dimensions': dimensions,
      'crew_members': crewMembers,
      'shift_name': shiftName,
      'status': status,
    };
  }

  factory DieCuttingProductionReport.fromJson(Map<String, dynamic> map) {
    return DieCuttingProductionReport(
      id: map['sync_id']?.toString() ?? map['id']?.toString() ?? '',
      factoryId: map['factory_id']?.toString(),
      machineName: map['machine_name']?.toString() ?? '',
      technicianName: map['technician_name']?.toString() ?? '',
      reportDate: map['report_date'] != null 
          ? DateTime.tryParse(map['report_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      customerName: map['customer_name']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      itemCode: map['item_code']?.toString() ?? '',
      formNumber: map['form_number']?.toString() ?? '',
      workOrder: map['work_order']?.toString() ?? '',
      runTimeStart: map['run_time_start'] != null 
          ? DateTime.tryParse(map['run_time_start'].toString()) 
          : null,
      runTimeEnd: map['run_time_end'] != null 
          ? DateTime.tryParse(map['run_time_end'].toString()) 
          : null,
      downtimeStart: map['downtime_start'] != null 
          ? DateTime.tryParse(map['downtime_start'].toString()) 
          : null,
      downtimeEnd: map['downtime_end'] != null 
          ? DateTime.tryParse(map['downtime_end'].toString()) 
          : null,
      productionQuantity: (map['production_quantity'] as num?)?.toDouble() ?? (map['quantity'] as num?)?.toDouble() ?? double.tryParse(map['production_quantity']?.toString() ?? '') ?? double.tryParse(map['quantity']?.toString() ?? '') ?? 0.0,
      wasteQuantity: (map['waste_quantity'] as num?)?.toDouble() ?? (map['line_waste'] as num?)?.toDouble() ?? double.tryParse(map['waste_quantity']?.toString() ?? '') ?? double.tryParse(map['line_waste']?.toString() ?? '') ?? 0.0,
      notes: map['notes']?.toString(),
      dimensions: map['dimensions'] is Map ? Map<String, dynamic>.from(map['dimensions']) : null,
      crewMembers: map['crew_members'] is List ? List<String>.from(map['crew_members']) : null,
      shiftName: map['shift_name']?.toString() ?? map['shiftName']?.toString(),
      status: map['status']?.toString() ?? 'approved',
    );
  }
}

