
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';

class TimeOverlapValidator {
  /// يتحقق مما إذا كان هناك تقاطع زمني مع أي تقرير **معتمد** لنفس الماكينة وفي نفس اليوم
  static bool hasOverlap({
    required Box box,
    required String machineName,
    required String dateStr,
    required String startTimeStr,
    required String endTimeStr,
    String? excludeId,
  }) {
    if (machineName.isEmpty || dateStr.isEmpty || startTimeStr.isEmpty || endTimeStr.isEmpty) {
      return false; // بيانات ناقصة، لا يمكن التحقق
    }

    final targetDate = _normalizeDate(dateStr);
    final targetStartMins = _parseTimeStrToMinutes(startTimeStr);
    final targetEndMins = _parseTimeStrToMinutes(endTimeStr);

    if (targetDate.isEmpty || targetStartMins == null || targetEndMins == null) {
      return false; // فشل في تحليل الوقت
    }

    int adjustedTargetEnd = targetEndMins;
    if (adjustedTargetEnd < targetStartMins) {
      adjustedTargetEnd += 24 * 60; // الوردية امتدت لليوم التالي
    }

    for (var entry in box.values) {
      String rId = '';
      String rMachineName = '';
      String rDate = '';
      String rStart = '';
      String rEnd = '';
      String rStatus = 'approved';

      if (entry is FlexoProductionReport) {
        rId = entry.id;
        rMachineName = entry.machineName ?? '';
        rDate = _normalizeDate(entry.date);
        rStart = entry.startTime ?? '';
        rEnd = entry.endTime ?? '';
        rStatus = entry.status;
      } else if (entry is DieCuttingProductionReport) {
        rId = entry.id;
        rMachineName = entry.machineName;
        rDate = _normalizeDate(entry.reportDate.toIso8601String());
        rStart = entry.runTimeStart != null ? "${entry.runTimeStart!.hour}:${entry.runTimeStart!.minute}" : '';
        rEnd = entry.runTimeEnd != null ? "${entry.runTimeEnd!.hour}:${entry.runTimeEnd!.minute}" : '';
        rStatus = entry.status;
      } else if (entry is Map) {
        rId = entry['sync_id']?.toString() ?? entry['id']?.toString() ?? '';
        rMachineName = entry['machine_name']?.toString() ?? entry['machineName']?.toString() ?? '';
        rDate = _normalizeDate(entry['date']?.toString() ?? entry['report_date']?.toString() ?? '');
        rStart = entry['start_time']?.toString() ?? entry['startTime']?.toString() ?? entry['run_time_start']?.toString() ?? '';
        rEnd = entry['end_time']?.toString() ?? entry['endTime']?.toString() ?? entry['run_time_end']?.toString() ?? '';
        rStatus = entry['status']?.toString() ?? 'approved';
      }

      // لا نقارن التقرير بنفسه
      if (excludeId != null && excludeId == rId) continue;

      // يجب أن يكون التقرير الآخر معتمداً، ونفس الماكينة، ونفس اليوم
      if (rStatus != 'approved' || rMachineName != machineName || rDate != targetDate) {
        continue;
      }

      // استخراج الأوقات للتقرير الموجود
      if (rStart.contains('T')) {
        // Handle ISO8601 format (e.g. from run_time_start)
        final dt = DateTime.tryParse(rStart);
        if (dt != null) rStart = "${dt.hour}:${dt.minute}";
      }
      if (rEnd.contains('T')) {
        final dt = DateTime.tryParse(rEnd);
        if (dt != null) rEnd = "${dt.hour}:${dt.minute}";
      }

      final startMins = _parseTimeStrToMinutes(rStart);
      final endMins = _parseTimeStrToMinutes(rEnd);

      if (startMins == null || endMins == null) continue;

      int adjustedEnd = endMins;
      if (adjustedEnd < startMins) {
        adjustedEnd += 24 * 60;
      }

      // فحص التقاطع الزمني
      // التقاطع يحدث إذا كان هناك تداخل بين الفترتين (TargetStart..TargetEnd) و (Start..End)
      if (targetStartMins < adjustedEnd && startMins < adjustedTargetEnd) {
        return true; // تقاطع!
      }
    }

    return false;
  }

  static String _normalizeDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
    } catch (_) {}
    return dateStr.split(' ')[0].split('T')[0];
  }

  static int? _parseTimeStrToMinutes(String timeStr) {
    if (timeStr.isEmpty || timeStr == '--:--') return null;
    
    timeStr = timeStr.trim();
    int addMins = 0;
    
    // دعم فترات الصباح والمساء باللغة الإنجليزية والعربية
    if (timeStr.toLowerCase().contains('pm') || timeStr.contains('م')) {
      addMins = 12 * 60;
    }

    // استخراج الساعات والدقائق بدقة بغض النظر عن النصوص المحيطة بها
    final RegExp timeRegex = RegExp(r'(\d+)\s*:\s*(\d+)');
    final match = timeRegex.firstMatch(timeStr);

    if (match != null && match.groupCount >= 2) {
      final hours = int.tryParse(match.group(1)!) ?? 0;
      final minutes = int.tryParse(match.group(2)!) ?? 0;
      
      int total = hours * 60 + minutes + addMins;
      
      // معالجة حالة الساعة 12
      if (addMins > 0 && hours == 12) {
        total -= 12 * 60; // 12 PM = 12:00 (ليس 24:00)
      }
      if (addMins == 0 && hours == 12 && (timeStr.toLowerCase().contains('am') || timeStr.contains('ص'))) {
        total -= 12 * 60; // 12 AM = 00:00
      }

      return total;
    }
    
    return null;
  }
}
