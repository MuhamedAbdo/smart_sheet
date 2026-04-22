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

  @HiveField(13)
  final String? factoryId;

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
    this.factoryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'machine': machine,
      'is_fixed': isFixed,
      'issue_date': issueDate,
      'report_date': reportDate,
      'action_date': actionDate,
      'issue_description': issueDescription,
      'action_taken': actionTaken,
      'repair_location': repairLocation,
      'repaired_by': repairedBy,
      'reported_to_technician': reportedToTechnician,
      'notes': notes,
      'image_paths': imagePaths,
      'factory_id': factoryId,
    };
  }

  factory MaintenanceRecord.fromJson(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'],
      machine: map['machine'] ?? '',
      isFixed: map['is_fixed'] ?? false,
      issueDate: map['issue_date'] ?? '',
      reportDate: map['report_date'] ?? '',
      actionDate: map['action_date'] ?? '',
      issueDescription: map['issue_description'] ?? '',
      actionTaken: map['action_taken'] ?? '',
      repairLocation: map['repair_location'] ?? '',
      repairedBy: map['repaired_by'] ?? '',
      reportedToTechnician: map['reported_to_technician'] ?? '',
      notes: map['notes'],
      imagePaths: List<String>.from(map['image_paths'] ?? []),
      factoryId: map['factory_id'],
    );
  }
}
