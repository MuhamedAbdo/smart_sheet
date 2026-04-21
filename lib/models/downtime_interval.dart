import 'package:hive/hive.dart';

part 'downtime_interval.g.dart';

@HiveType(typeId: 16)
class DowntimeInterval {
  @HiveField(0)
  DateTime start;

  @HiveField(1)
  DateTime? end;

  DowntimeInterval({
    required this.start,
    this.end,
  });

  Duration get duration => (end ?? DateTime.now()).difference(start);
}
