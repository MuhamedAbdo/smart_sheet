import 'package:hive/hive.dart';

part 'downtime_interval.g.dart';

@HiveType(typeId: 16)
class DowntimeInterval {
  @HiveField(0)
  DateTime start;

  @HiveField(1)
  DateTime? end;

  DowntimeInterval({
    required DateTime start,
    DateTime? end,
  })  : start = start.toUtc(),
        end = end?.toUtc();

  Duration get duration => (end?.toUtc() ?? DateTime.now().toUtc()).difference(start.toUtc()).abs();

  Map<String, dynamic> toJson() {
    return {
      'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end!.toUtc().toIso8601String(),
    };
  }

  factory DowntimeInterval.fromJson(Map<String, dynamic> json) {
    return DowntimeInterval(
      start: _parseDate(json['start'] as String?),
      end: json['end'] != null ? _parseDate(json['end'] as String?) : null,
    );
  }

  static DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime.now().toUtc();
    if (!dateStr.endsWith('Z') && !dateStr.contains('+') && !dateStr.contains('-')) {
      dateStr += 'Z';
    }
    return DateTime.tryParse(dateStr)?.toUtc() ?? DateTime.now().toUtc();
  }
}
