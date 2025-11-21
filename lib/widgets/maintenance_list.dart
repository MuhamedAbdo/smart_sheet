// lib/src/widgets/maintenance/maintenance_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/maintenance_card.dart';

class MaintenanceList extends StatelessWidget {
  final Box box;
  final VoidCallback onAdd;
  final void Function(int, Map<String, dynamic>) onEdit;
  final void Function(int) onDelete;

  const MaintenanceList({
    super.key,
    required this.box,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام ValueListenableBuilder للتحديث التلقائي عند إضافة الصور
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "🚫 لا يوجد سجلات صيانة بعد",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final record = box.getAt(index);
            if (record is Map<String, dynamic>) {
              return MaintenanceCard(
                record: record,
                onEdit: () => onEdit(index, record),
                onDelete: () => onDelete(index),
              );
            }
            return Container();
          },
        );
      },
    );
  }
}
