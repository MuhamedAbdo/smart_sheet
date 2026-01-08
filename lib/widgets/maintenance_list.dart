// lib/src/widgets/maintenance/maintenance_list.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/maintenance_record_model.dart';
import 'maintenance_card.dart';

class MaintenanceList extends StatelessWidget {
  final Box<MaintenanceRecord> box;
  final VoidCallback onAdd;
  final Function(int index, MaintenanceRecord record) onEdit;
  final Function(int index) onDelete;

  const MaintenanceList({
    super.key,
    required this.box,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (box.isEmpty) {
      return const Center(
        child: Text("لا توجد سجلات صيانة"),
      );
    }

    return ListView.builder(
      itemCount: box.length,
      itemBuilder: (context, index) {
        final item = box.getAt(index)!;
        return MaintenanceCard(
          record: item,
          onEdit: () => onEdit(index, item),
          onDelete: () => onDelete(index),
        );
      },
    );
  }
}
