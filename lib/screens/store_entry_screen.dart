// lib/src/screens/store/store_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/store_entry_form.dart';
import 'package:smart_sheet/widgets/store_entry_list.dart';

class StoreEntryScreen extends StatelessWidget {
  const StoreEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text("📄 تقارير وارد المخزن"),
        centerTitle: true,
      ),
      body: const StoreEntryList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => StoreEntryForm.show(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
