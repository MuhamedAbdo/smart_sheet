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
  final String? orderNumber;

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

  @HiveField(21)
  final DateTime? createdAt;

  DieCuttingProductionReport({
    required this.id,
    required this.machineName,
    required this.technicianName,
    required this.reportDate,
    required this.customerName,
    required this.itemName,
    required this.itemCode,
    required this.formNumber,
    this.orderNumber,
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
    this.createdAt,
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
    String? orderNumber,
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
    DateTime? createdAt,
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
      orderNumber: orderNumber ?? this.orderNumber,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
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
      'order_number': orderNumber,
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
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
    // قسم التكسير لا يتعامل مع الألوان ولا يحتوي جدوله على عمود colors
    map.remove('colors');
    return map;
  }

  Map<String, dynamic> toMap() => toJson();

  /// إرجاع الحقول المتوافقة فقط مع جدول `die_cutting_archived_reports` على Supabase
  /// واستبعاد أي حقول أخرى تماماً (مثل: shift_name, colors, department, status)
  Map<String, dynamic> toSupabaseMap() {
    final Map<String, dynamic> map = {
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
      'run_time_start': runTimeStart?.toIso8601String(),
      'run_time_end': runTimeEnd?.toIso8601String(),
      'downtime_start': downtimeStart?.toIso8601String(),
      'downtime_end': downtimeEnd?.toIso8601String(),
      'production_quantity': productionQuantity,
      'waste_quantity': wasteQuantity,
      'notes': notes,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'dimensions': dimensions,
      'crew_members': crewMembers,
      'order_number': (orderNumber != null && orderNumber!.trim().isNotEmpty)
          ? orderNumber!.trim()
          : null,
    };

    // القائمة البيضاء الدقيقة المعتمدة لأعمدة جدول die_cutting_archived_reports على Supabase
    const allowedKeys = {
      'id',
      'sync_id',
      'factory_id',
      'report_date',
      'machine_name',
      'technician_name',
      'customer_name',
      'item_name',
      'item_code',
      'form_number',
      'run_time_start',
      'run_time_end',
      'downtime_start',
      'downtime_end',
      'production_quantity',
      'waste_quantity',
      'notes',
      'created_at',
      'dimensions',
      'crew_members',
      'order_number',
    };

    // حذف وتجاهل أي مفتاح غير موجود في القائمة البيضاء تماماً
    map.removeWhere((key, _) => !allowedKeys.contains(key));

    return map;
  }

  factory DieCuttingProductionReport.fromJson(Map<String, dynamic> map) {
    return DieCuttingProductionReport(
      id: map['sync_id']?.toString() ?? map['id']?.toString() ?? '',
      factoryId: map['factory_id']?.toString() ?? map['factoryId']?.toString(),
      machineName: map['machine_name']?.toString() ?? map['machineName']?.toString() ?? '',
      technicianName: map['technician_name']?.toString() ?? map['technicianName']?.toString() ?? '',
      reportDate: (map['report_date'] != null || map['date'] != null)
          ? DateTime.tryParse((map['report_date'] ?? map['date']).toString()) ?? DateTime.now()
          : DateTime.now(),
      customerName: map['customer_name']?.toString() ?? map['client_name']?.toString() ?? map['clientName']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? map['product_name']?.toString() ?? map['product']?.toString() ?? '',
      itemCode: map['item_code']?.toString() ?? map['product_code']?.toString() ?? map['productCode']?.toString() ?? '',
      formNumber: map['form_number']?.toString() ?? map['formNumber']?.toString() ?? '',
      orderNumber: map['order_number']?.toString() ?? map['orderNumber']?.toString() ?? map['work_order']?.toString(),
      runTimeStart: map['run_time_start'] != null 
          ? DateTime.tryParse(map['run_time_start'].toString()) 
          : (map['start_time'] != null 
              ? DateTime.tryParse(map['start_time'].toString()) 
              : (map['startTime'] != null ? DateTime.tryParse(map['startTime'].toString()) : null)),
      runTimeEnd: map['run_time_end'] != null 
          ? DateTime.tryParse(map['run_time_end'].toString()) 
          : (map['end_time'] != null 
              ? DateTime.tryParse(map['end_time'].toString()) 
              : (map['endTime'] != null ? DateTime.tryParse(map['endTime'].toString()) : null)),
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
      crewMembers: map['crew_members'] is List 
          ? List<String>.from(map['crew_members']) 
          : (map['crewMembers'] is List ? List<String>.from(map['crewMembers']) : null),
      shiftName: map['shift_name']?.toString() ?? map['shiftName']?.toString(),
      status: map['status']?.toString() ?? 'approved',
      createdAt: map['created_at'] != null 
          ? DateTime.tryParse(map['created_at'].toString()) 
          : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null),
    );
  }
}

typedef DieCuttingArchivedReport = DieCuttingProductionReport;

