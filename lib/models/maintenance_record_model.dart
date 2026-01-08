// lib/src/models/maintenance_record_model.dart

import 'package:hive/hive.dart';

part 'maintenance_record_model.g.dart';

@HiveType(typeId: 6)
class MaintenanceRecord extends HiveObject {
  // إضافة HiveObject تسهل التعامل مع الـ Key
  @HiveField(0)
  final String machine;

  @HiveField(1)
  final bool isFixed;

  @HiveField(2)
  final String issueDate;

  @HiveField(3)
  final String reportDate;

  @HiveField(4)
  final String actionDate;

  @HiveField(5)
  final String issueDescription;

  @HiveField(6)
  final String actionTaken;

  @HiveField(7)
  final String repairLocation;

  @HiveField(8)
  final String repairedBy;

  @HiveField(9)
  final String reportedToTechnician;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final List<String> imagePaths;

  @HiveField(12) // حقل جديد للـ ID
  final String? id;

  MaintenanceRecord({
    this.id, // اجعله اختيارياً
    required this.machine,
    required this.isFixed,
    required this.issueDate,
    required this.reportDate,
    required this.actionDate,
    required this.issueDescription,
    required this.actionTaken,
    required this.repairLocation,
    required this.repairedBy,
    required this.reportedToTechnician,
    this.notes,
    required this.imagePaths,
  });
}
