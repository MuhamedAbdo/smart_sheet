// lib/src/widgets/store/store_entry_form.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/store_entry_model.dart';

class StoreEntryForm extends StatefulWidget {
  final String boxName; // ✅ إضافة boxName
  final int? index;
  final StoreEntry? existing;

  const StoreEntryForm({
    super.key,
    required this.boxName, // ✅ مطلوب
    this.index,
    this.existing,
  });

  static void show(
    BuildContext context, {
    required String boxName, // ✅ جعل boxName مطلوبًا
    int? index,
    StoreEntry? existing,
  }) {
    showDialog(
      context: context,
      builder: (context) => StoreEntryForm(
        boxName: boxName,
        index: index,
        existing: existing,
      ),
    );
  }

  @override
  State<StoreEntryForm> createState() => _StoreEntryFormState();
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
    final e = widget.existing;
    dateController = TextEditingController(text: e?.date ?? '');
    productController = TextEditingController(text: e?.product ?? '');
    unitController = TextEditingController(text: e?.unit ?? '');
    quantityController =
        TextEditingController(text: e?.quantity.toString() ?? '');
    notesController = TextEditingController(text: e?.notes ?? '');
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    // ✅ تجنب null access + تنسيق تاريخ قياسي (مع أصفار بادئة)
    if (picked != null) {
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  void _save() {
    final box =
        Hive.box<StoreEntry>(widget.boxName); // ✅ استخدام الصندوق الصحيح

    final entry = StoreEntry(
      date: dateController.text,
      product: productController.text,
      unit: unitController.text,
      quantity: int.tryParse(quantityController.text) ?? 0,
      notes: notesController.text.isEmpty ? null : notesController.text,
    );

    if (widget.index == null) {
      box.add(entry);
    } else {
      box.putAt(widget.index!, entry);
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
          onPressed: Navigator.of(context).pop,
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
