// lib/src/widgets/store/store_entry_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/store_entry_card.dart';
import 'package:smart_sheet/widgets/store_entry_form.dart';

class StoreEntryList extends StatelessWidget {
  const StoreEntryList({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('storeEntries').listenable(),
      builder: (context, Box box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("🚫 لا يوجد تقارير وارد المخزن بعد"));
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final record = box.getAt(index) as Map<String, dynamic>;
            return StoreEntryCard(
              record: record,
              onEdit: () => StoreEntryForm.show(
                context,
                index: index,
                existingData: record,
              ),
              onDelete: () => box.deleteAt(index),
            );
          },
        );
      },
    );
  }
}
