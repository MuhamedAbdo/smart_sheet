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
}
