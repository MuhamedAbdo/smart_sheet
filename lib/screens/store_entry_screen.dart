// lib/src/screens/store/store_entry_screen.dart

import 'package:flutter/material.dart';
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
      appBar: AppBar(
        title: Text("📄 $title"),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: StoreEntryList(boxName: boxName),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => StoreEntryForm.show(context, boxName: boxName),
        child: const Icon(Icons.add),
      ),
    );
  }
}
