import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'active_absence_card.dart';

class ActiveAbsencesDashboard extends StatelessWidget {
  final Box<Worker> workerBox;

  const ActiveAbsencesDashboard({super.key, required this.workerBox});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: workerBox.listenable(),
      builder: (context, Box<Worker> box, _) {
        // Find workers with active absence actions
        final activeAbsences = <MapEntry<Worker, WorkerAction>>[];
        
        for (var worker in box.values) {
          try {
            final activeAction = worker.actions.firstWhere(
              (a) => a.isActive && (
                     (a.type == 'غياب' && DateTime.now().difference(a.date).inDays <= 30) ||
                     ((a.type == 'إذن') && DateTime.now().difference(a.date).inHours <= 24) ||
                     (a.type == 'تأمين صحي' && DateTime.now().difference(a.date).inHours <= 48) ||
                     ((a.type == 'إجازة' || a.type == 'أجازة عارضة') && DateTime.now().difference(a.date).inDays <= 30)
              ),
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
