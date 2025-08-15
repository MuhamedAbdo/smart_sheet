// lib/src/widgets/store/store_entry_form.dart

import 'package:flutter/material.dart'; // ✅ هذا الاستيراد يحتوي على showDialog
import 'package:hive_flutter/hive_flutter.dart';

class StoreEntryForm extends StatefulWidget {
  final int? index;
  final Map<String, dynamic>? existingData;

  const StoreEntryForm({super.key, this.index, this.existingData});

  @override
  State<StoreEntryForm> createState() => _StoreEntryFormState();

  // ✅ غير الاسم من showDialog إلى show
  static void show(BuildContext context,
      {int? index, Map<String, dynamic>? existingData}) {
    showDialog(
      context: context,
      builder: (context) =>
          StoreEntryForm(index: index, existingData: existingData),
    );
  }
}

class _StoreEntryFormState extends State<StoreEntryForm> {
  late TextEditingController dateController;
  late TextEditingController productController;
  late TextEditingController unitController;
  late TextEditingController quantityController;
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    dateController =
        TextEditingController(text: widget.existingData?['date'] ?? '');
    productController =
        TextEditingController(text: widget.existingData?['product'] ?? '');
    unitController =
        TextEditingController(text: widget.existingData?['unit'] ?? '');
    quantityController =
        TextEditingController(text: widget.existingData?['quantity'] ?? '');
    notesController =
        TextEditingController(text: widget.existingData?['notes'] ?? '');
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      dateController.text = "${picked.year}-${picked.month}-${picked.day}";
    }
  }

  void _save() {
    final record = {
      'date': dateController.text,
      'product': productController.text,
      'unit': unitController.text,
      'quantity': quantityController.text,
      'notes': notesController.text,
    };

    final box = Hive.box('storeEntries');
    if (widget.index == null) {
      box.add(record);
    } else {
      box.putAt(widget.index!, record);
    }

    Navigator.pop(context);
  }

  @override
  void dispose() {
    dateController.dispose();
    productController.dispose();
    unitController.dispose();
    quantityController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.index == null ? "➕ إضافة وارد" : "✏️ تعديل وارد"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "📅 التاريخ"),
              onTap: () => _selectDate(context),
            ),
            TextField(
              controller: productController,
              decoration: const InputDecoration(labelText: "📦 الصنف"),
            ),
            TextField(
              controller: unitController,
              decoration: const InputDecoration(labelText: "📏 الوحدة"),
            ),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "🔢 العدد"),
            ),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: "📝 الملاحظات"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("❌ إلغاء"),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text("💾 حفظ"),
        ),
      ],
    );
  }
}
