import 'package:hive/hive.dart';
import 'package:smart_sheet/services/server_time_service.dart';
import 'downtime_interval.dart';

part 'live_session.g.dart';

@HiveType(typeId: 17)
class LiveSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String machineName;

  @HiveField(2)
  final String clientName;

  @HiveField(3)
  final String productName;

  @HiveField(4)
  final String productCode;

  @HiveField(5)
  final String orderNumber;

  @HiveField(6)
  final String technicianName;

  @HiveField(7)
  DateTime startTime;

  @HiveField(8)
  final List<DowntimeInterval> downtimeIntervals;

  @HiveField(9)
  bool isRunning;

  @HiveField(10)
  DateTime lastStateChange;

  @HiveField(11)
  final Map<String, dynamic>? dimensions;

  @HiveField(12)
  final bool? isSheet;

  @HiveField(13)
  final List<String>? imagePaths;

  @HiveField(14)
  final String? factoryId;

  @HiveField(15)
  final String? createdByDeviceId;

  @HiveField(16)
  final String? technicianId;

  @HiveField(17)
  final String? department;

  @HiveField(18)
  final String? shift;

  @HiveField(19)
  final List<String>? paperLayers;

  @HiveField(20)
  final String? formNumber;

  @HiveField(21)
  final List<String>? crewMembers;

  @HiveField(22, defaultValue: 'pending')
  final String status;

  LiveSession({
    required this.id,
    required this.machineName,
    required this.clientName,
    required this.productName,
    required this.productCode,
    required this.orderNumber,
    required this.technicianName,
    required DateTime startTime,
    required this.downtimeIntervals,
    this.isRunning = true,
    required DateTime lastStateChange,
    this.dimensions,
    this.isSheet,
    this.imagePaths,
    this.factoryId,
    this.createdByDeviceId,
    this.technicianId,
    this.department = 'flexo',
    this.shift,
    this.paperLayers,
    this.formNumber,
    this.crewMembers,
    this.status = 'pending',
  })  : startTime = startTime.toUtc(),
        lastStateChange = lastStateChange.toUtc();

  LiveSession copyWith({
    String? id,
    String? machineName,
    String? clientName,
    String? productName,
    String? productCode,
    String? orderNumber,
    String? technicianName,
    DateTime? startTime,
    List<DowntimeInterval>? downtimeIntervals,
    bool? isRunning,
    DateTime? lastStateChange,
    Map<String, dynamic>? dimensions,
    bool? isSheet,
    List<String>? imagePaths,
    String? factoryId,
    String? createdByDeviceId,
    String? technicianId,
    String? department,
    String? shift,
    List<String>? paperLayers,
    String? formNumber,
    List<String>? crewMembers,
    String? status,
  }) {
    return LiveSession(
      id: id ?? this.id,
      machineName: machineName ?? this.machineName,
      clientName: clientName ?? this.clientName,
      productName: productName ?? this.productName,
      productCode: productCode ?? this.productCode,
      orderNumber: orderNumber ?? this.orderNumber,
      technicianName: technicianName ?? this.technicianName,
      startTime: startTime ?? this.startTime,
      downtimeIntervals: downtimeIntervals ?? this.downtimeIntervals,
      isRunning: isRunning ?? this.isRunning,
      lastStateChange: lastStateChange ?? this.lastStateChange,
      dimensions: dimensions ?? this.dimensions,
      isSheet: isSheet ?? this.isSheet,
      imagePaths: imagePaths ?? this.imagePaths,
      factoryId: factoryId ?? this.factoryId,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      technicianId: technicianId ?? this.technicianId,
      department: department ?? this.department,
      shift: shift ?? this.shift,
      paperLayers: paperLayers ?? this.paperLayers,
      formNumber: formNumber ?? this.formNumber,
      crewMembers: crewMembers ?? this.crewMembers,
      status: status ?? this.status,
    );
  }

  @override
  Future<void> save() {
    startTime = startTime.toUtc();
    lastStateChange = lastStateChange.toUtc();
    return super.save();
  }

  Duration get totalDowntime {
    return downtimeIntervals.fold(
      Duration.zero,
      (total, interval) => total + interval.duration,
    );
  }

  Duration get netRunningTime {
    final totalElapsed = ServerTimeService.nowUtc.difference(startTime.toUtc());
    final net = totalElapsed - totalDowntime;
    return net;
  }

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return ServerTimeService.nowUtc;
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      dateStr += 'Z';
    }
    return DateTime.tryParse(dateStr)?.toUtc() ?? ServerTimeService.nowUtc;
  }

  Map<String, dynamic> toJson() {
    return {
      'sync_id': id,
      'machine_name': machineName,
      'client_name': clientName,
      'product_name': productName,
      'product_code': productCode,
      'order_number': orderNumber,
      'technician_name': technicianName,
      'start_time': startTime.toUtc().toIso8601String(),
      'downtime_intervals': downtimeIntervals.map((i) => i.toJson()).toList(),
      'is_running': isRunning,
      'last_state_change': lastStateChange.toUtc().toIso8601String(),
      'dimensions': dimensions,
      'is_sheet': isSheet,
      'image_paths': imagePaths,
      'factory_id': factoryId,
      'created_by_device_id': createdByDeviceId,
      'technician_id': technicianId,
      'department': department ?? 'flexo',
      'shift': shift,
      'paper_layers': paperLayers,
      'form_number': formNumber,
      'crew_members': crewMembers,
      'status': status,
    };
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    List<DowntimeInterval> intervals = [];
    if (json['downtime_intervals'] != null) {
      intervals = (json['downtime_intervals'] as List)
          .map((i) => DowntimeInterval.fromJson(Map<String, dynamic>.from(i)))
          .toList();
    }

    final rawLayers = json['paper_layers'] ?? json['paperLayers'];
    String? dept = json['department']?.toString();
    if (dept == null || dept.trim().isEmpty || dept == 'null') {
      final mName = json['machine_name']?.toString() ?? '';
      if (mName == 'خط الإنتاج') {
        dept = 'production_line';
      } else {
        dept = 'flexo';
      }
    }

    return LiveSession(
      id: json['sync_id']?.toString() ?? json['id']?.toString() ?? '',
      machineName: json['machine_name']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      technicianName: json['technician_name']?.toString() ?? '',
      startTime: _parseDate(json['start_time']?.toString()),
      downtimeIntervals: intervals,
      isRunning: json['is_running'] ?? true,
      lastStateChange: _parseDate(json['last_state_change']?.toString()),
      dimensions: json['dimensions'] is Map ? Map<String, dynamic>.from(json['dimensions']) : null,
      isSheet: json['is_sheet'],
      imagePaths: json['image_paths'] != null ? List<String>.from(json['image_paths']) : null,
      factoryId: json['factory_id']?.toString(),
      createdByDeviceId: json['created_by_device_id']?.toString(),
      technicianId: json['technician_id']?.toString() ?? json['technicianId']?.toString(),
      department: dept,
      shift: json['shift']?.toString(),
      paperLayers: rawLayers != null ? List<String>.from(rawLayers) : null,
      formNumber: json['formNumber']?.toString() ?? json['form_number']?.toString(),
      crewMembers: json['crew_members'] != null ? List<String>.from(json['crew_members']) : null,
      status: json['status']?.toString() ?? 'pending',
    );
  }
}
