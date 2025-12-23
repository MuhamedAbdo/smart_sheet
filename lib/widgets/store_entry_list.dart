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
    // نستخدم FutureBuilder للتأكد من أن الصندوق مفتوح بالنوع الصحيح قبل الوصول إليه
    return FutureBuilder<Box<StoreEntry>>(
      future: Hive.isBoxOpen(boxName)
          ? Future.value(Hive.box<StoreEntry>(boxName))
          : Hive.openBox<StoreEntry>(boxName),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final box = snapshot.data!;

        return ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<StoreEntry> box, _) {
            if (box.isEmpty) {
              return const Center(
                  child: Text("🚫 لا يوجد تقارير وارد المخزن بعد"));
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
      },
    );
  }
}
