// lib/src/models/maintenance_record.dart

import 'package:hive_flutter/hive_flutter.dart';

part 'maintenance_record.g.dart';

@HiveType(typeId: 0)
class MaintenanceRecord extends HiveObject {
  @HiveField(0)
  final String date;

  @HiveField(1)
  final String machine;

  @HiveField(2)
  final String issue;

  @HiveField(3)
  final String technician;

  @HiveField(4)
  final String action;

  @HiveField(5)
  final String? notes;

  // ✅ إضافة الحقل لدعم الصور
  @HiveField(6)
  final List<String>? imagePaths;

  MaintenanceRecord({
    required this.date,
    required this.machine,
    required this.issue,
    required this.technician,
    required this.action,
    this.notes,
    // ✅ تمرير الحقل الجديد في المُنشئ
    this.imagePaths,
  });

  // ✅ دالة لتحويل النموذج إلى Map (للاستخدام مع Hive)
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'machine': machine,
      'issue': issue,
      'technician': technician,
      'action': action,
      'notes': notes,
      // ✅ إضافة الحقل الجديد إلى التحويل
      'imagePaths': imagePaths,
    };
  }

  // ✅ دالة لتحويل Map إلى نموذج (للاستخدام مع Hive)
  factory MaintenanceRecord.fromJson(Map<String, dynamic> map) {
    return MaintenanceRecord(
      date: map['date'] ?? '',
      machine: map['machine'] ?? '',
      issue: map['issue'] ?? '',
      technician: map['technician'] ?? '',
      action: map['action'] ?? '',
      notes: map['notes'],
      // ✅ قراءة الحقل الجديد من الـ Map
      imagePaths:
          (map['imagePaths'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
