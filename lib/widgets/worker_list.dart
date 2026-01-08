// lib/src/widgets/workers/worker_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

import 'package:smart_sheet/widgets/worker_card.dart';
import 'package:smart_sheet/screens/worker_details_screen.dart';
import 'package:smart_sheet/widgets/worker_form.dart';

class WorkerList extends StatelessWidget {
  final Box<Worker> box; // ✅ إضافة الحقل

  const WorkerList({super.key, required this.box}); // ✅ تعديل المُنشئ

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام الصندوق المُمرر
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<Worker> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("🚫 لا يوجد عمال بعد"));
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final worker = box.getAt(index)!;
            return WorkerCard(
              worker: worker,
              onEdit: () => WorkerForm.show(context,
                  existingWorker: worker, box: box), // ✅ تمرير الصندوق
              onDelete: () => box.deleteAt(index), // ✅ استخدام الصندوق المُمرر
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerDetailsScreen(
                        worker: worker, box: box), // ✅ تمرير الصندوق
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
