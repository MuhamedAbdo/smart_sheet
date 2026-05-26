import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'active_absence_card.dart';

class ActiveAbsencesDashboard extends StatelessWidget {
  final Box<Worker> workerBox;
  final String? filterDepartment; // ✅ تصفية حية حسب القسم

  const ActiveAbsencesDashboard({super.key, required this.workerBox, this.filterDepartment});

  /// Resets all worker statuses from 'غياب' to 'متواجد' and clears old sessions
  static Future<void> resetAllWorkerStatuses(BuildContext context, Box<Worker> workerBox, String? filterDept) async {
    try {
      int updatedCount = 0;
      
      // نستخدم toMap().entries عشان نوصل للـ key والـ worker مع بعض لازم تستخدم workerBox.toMap().entries
      for (var entry in workerBox.toMap().entries) {
        final worker = entry.value;
        final key = entry.key;
        
        if (filterDept != null && worker.department != filterDept) {
          continue;
        }
        
        List<WorkerAction> actions = List<WorkerAction>.from(worker.actions);
        
        // تنظيف الغيابات القديمة
        bool hasChanged = false;
        final filteredActions = actions.where((action) {
          if (action.type == 'غياب') {
            final daysSinceAbsence = DateTime.now().difference(action.date).inDays;
            if (daysSinceAbsence > 30) {
              hasChanged = true;
              return false; 
            }
          }
          return true;
        }).toList();
        
        // التحقق من الحالة النشطة
        final hasActiveStatus = filteredActions.any((action) => 
            action.isActive && action.returnDate == null);
        
        // التحقق من وجود تاريخ عودة - يجب أن تكون حالة العامل (حضور)
        final hasReturnDate = filteredActions.any((action) => 
            action.returnDate != null);
        
        // Add new 'حضور' status if worker has return date or no active status
        if (hasReturnDate || !hasActiveStatus) {
          final presentAction = WorkerAction(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            type: 'حضور',
            days: 0,
            date: DateTime.now(),
            workerName: worker.name,
          );
          filteredActions.add(presentAction);
          hasChanged = true;
          updatedCount++;
        }
        
        if (hasChanged) {
          final updatedWorker = Worker(
            name: worker.name,
            phone: worker.phone,
            job: worker.job,
            actions: filteredActions,
            hasMedicalInsurance: worker.hasMedicalInsurance,
            factoryId: worker.factoryId,
            department: worker.department,
            canAdd: worker.canAdd,
            canEdit: worker.canEdit,
            canDelete: worker.canDelete,
          );
          await workerBox.put(key, updatedWorker);
        }
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصفير حالات العمال بنجاح: $updatedCount عامل تم تحديث حالته'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تصفير الحالات: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: workerBox.listenable(),
      builder: (context, Box<Worker> box, _) {
        // Find workers with active absence actions
        final activeAbsences = <MapEntry<Worker, WorkerAction>>[];
        
        for (var worker in box.values) {
          if (filterDepartment != null && worker.department != filterDepartment) {
            continue;
          }
          try {
            final activeAction = worker.actions.firstWhere(
              (a) => a.isActive,
            );
            activeAbsences.add(MapEntry(worker, activeAction));
          } catch (_) {
            // No active absence for this worker
          }
        }

        if (activeAbsences.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 280,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_toggle_off, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'الجلسات الحية',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeAbsences.length}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await resetAllWorkerStatuses(context, workerBox, filterDepartment);
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('تصفير الحالات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: activeAbsences.length,
                  itemBuilder: (context, index) {
                    final entry = activeAbsences[index];
                    return ActiveAbsenceCard(
                      worker: entry.key,
                      action: entry.value,
                      onRefresh: () {
                        // ValueListenableBuilder will trigger rebuild
                      },
                    );
                  },
                ),
              ),
              const Divider(indent: 16, endIndent: 16),
            ],
          ),
        );
      },
    );
  }
}
