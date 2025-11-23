// lib/src/widgets/store/store_entry_list.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/store_entry_model.dart';
import 'store_entry_card.dart';
import 'store_entry_form.dart';

class StoreEntryList extends StatelessWidget {
  final String boxName;

  const StoreEntryList({super.key, required this.boxName});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<StoreEntry>(boxName);

    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<StoreEntry> box, _) {
        if (box.isEmpty) {
          return const Center(child: Text("🚫 لا يوجد تقارير وارد المخزن بعد"));
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final entry = box.getAt(index)!;
            return StoreEntryCard(
              record: entry,
              onEdit: () => StoreEntryForm.show(
                context,
                boxName: boxName,
                index: index,
                existing: entry,
              ),
              onDelete: () => box.deleteAt(index),
            );
          },
        );
      },
    );
  }
}
