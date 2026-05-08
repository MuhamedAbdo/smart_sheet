import 'package:hive/hive.dart';
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

  LiveSession({
    required this.id,
    required this.machineName,
    required this.clientName,
    required this.productName,
    required this.productCode,
    required this.orderNumber,
    required this.technicianName,
    required this.startTime,
    required this.downtimeIntervals,
    this.isRunning = true,
    required this.lastStateChange,
    this.dimensions,
    this.isSheet,
    this.imagePaths,
    this.factoryId,
    this.createdByDeviceId,
  });

  Duration get totalDowntime {
    return downtimeIntervals.fold(
      Duration.zero,
      (total, interval) => total + interval.duration,
    );
  }

  Duration get netRunningTime {
    final totalElapsed = DateTime.now().difference(startTime.toLocal()).abs();
    final net = totalElapsed - totalDowntime;
    return net.isNegative ? Duration.zero : net;
  }

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime.now();
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      dateStr += 'Z';
    }
    return DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
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
    };
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    List<DowntimeInterval> intervals = [];
    if (json['downtime_intervals'] != null) {
      intervals = (json['downtime_intervals'] as List)
          .map((i) => DowntimeInterval.fromJson(Map<String, dynamic>.from(i)))
          .toList();
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
    );
  }
}
