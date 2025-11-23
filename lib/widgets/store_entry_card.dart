// lib/src/widgets/store/store_entry_card.dart

import 'package:flutter/material.dart';
import '../../models/store_entry_model.dart';

class StoreEntryCard extends StatelessWidget {
  final StoreEntry record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StoreEntryCard({
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
        title: Text("📅 ${record.date}"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📦 الصنف: ${record.product}"),
            Text("📏 الوحدة: ${record.unit}"),
            Text("🔢 العدد: ${record.quantity}"),
            if (record.notes != null) Text("📝 ملاحظات: ${record.notes!}"),
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
