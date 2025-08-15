// lib/src/widgets/maintenance/maintenance_card.dart

import 'package:flutter/material.dart';

class MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MaintenanceCard({
    super.key,
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text("📅 ${record['issueDate'] ?? ''}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("🏭 ${record['machine'] ?? ''}"),
            Text("⚠️ ${record['issueDescription'] ?? ''}"),
            Text("🗓️ ${record['reportDate'] ?? ''}"),
            Text("👷‍♂️ ${record['reportedToTechnician'] ?? ''}"),
            Text("🔧 ${record['actionTaken'] ?? ''}"),
            Text("📆 ${record['actionDate'] ?? ''}"),
            Text("✅ تم الإصلاح: ${record['isFixed'] == true ? 'نعم' : 'لا'}"),
            Text("🏠 مكان الإصلاح: ${record['repairLocation'] ?? ''}"),
            if (record['repairedBy'] != null && record['repairedBy'].isNotEmpty)
              Text("🛠 تم الإصلاح بواسطة: ${record['repairedBy']}"),
            if (record['notes'] != null && record['notes'].isNotEmpty)
              Text("📝 ملاحظات: ${record['notes']}"),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
