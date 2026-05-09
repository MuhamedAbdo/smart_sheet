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
  });

  Duration get totalDowntime {
    return downtimeIntervals.fold(
      Duration.zero,
      (total, interval) => total + interval.duration,
    );
  }

  Duration get netRunningTime {
    final totalElapsed = DateTime.now().difference(startTime);
    return totalElapsed - totalDowntime;
  }

  factory LiveSession.fromJson(Map<String, dynamic> json) {
    return LiveSession(
      id: (json['id'] ?? json['sync_id'] ?? '').toString(),
      machineName: json['machine_name'] ?? json['machineName'] ?? '',
      clientName: json['client_name'] ?? json['clientName'] ?? '',
      productName: json['product_name'] ?? json['productName'] ?? '',
      productCode: json['product_code'] ?? json['productCode'] ?? '',
      orderNumber: json['order_number'] ?? json['orderNumber'] ?? '',
      technicianName: json['technician_name'] ?? json['technicianName'] ?? '',
      startTime: DateTime.parse(json['start_time'] ?? json['startTime']),
      downtimeIntervals: (json['downtime_intervals'] as List? ?? json['downtimeIntervals'] as List? ?? [])
          .map((i) => DowntimeInterval.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      isRunning: json['is_running'] ?? json['isRunning'] ?? true,
      lastStateChange: DateTime.parse(json['last_state_change'] ?? json['lastStateChange'] ?? DateTime.now().toIso8601String()),
      dimensions: json['dimensions'],
      isSheet: json['is_sheet'] ?? json['isSheet'],
      imagePaths: (json['image_paths'] as List?)?.map((e) => e.toString()).toList(),
      factoryId: (json['factory_id'] ?? json['factoryId'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sync_id': id,
      'machine_name': machineName,
      'client_name': clientName,
      'product_name': productName,
      'product_code': productCode,
      'order_number': orderNumber,
      'technician_name': technicianName,
      'start_time': startTime.toIso8601String(),
      'downtime_intervals': downtimeIntervals.map((i) => i.toJson()).toList(),
      'is_running': isRunning,
      'last_state_change': lastStateChange.toIso8601String(),
      'dimensions': dimensions,
      'is_sheet': isSheet,
      'image_paths': imagePaths,
      'factory_id': factoryId,
    };
  }
}
