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

  factory DowntimeInterval.fromJson(Map<String, dynamic> json) {
    return DowntimeInterval(
      start: DateTime.parse(json['start']),
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
    };
  }
}
