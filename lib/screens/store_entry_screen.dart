// lib/src/screens/store/store_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/store_entry_form.dart';
import 'package:smart_sheet/widgets/store_entry_list.dart';

class StoreEntryScreen extends StatelessWidget {
  final String boxName; // ✅ اسم الصندوق المخصص للقسم
  final String title;

  const StoreEntryScreen({
    super.key,
    required this.boxName,
    this.title = "تقارير وارد المخزن",
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text("📄 $title"),
        centerTitle: true,
      ),
      body: StoreEntryList(boxName: boxName),
      floatingActionButton: FloatingActionButton(
        onPressed: () => StoreEntryForm.show(context, boxName: boxName),
        child: const Icon(Icons.add),
      ),
    );
  }
}
