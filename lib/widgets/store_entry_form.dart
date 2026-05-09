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
    required String boxName,
    int? index,
    StoreEntry? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.index == null ? "➕ إضافة وارد" : "✏️ تعديل وارد",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),
                  _buildField(
                    controller: dateController,
                    label: "📅 التاريخ",
                    readOnly: true,
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: productController,
                    label: "📦 الصنف",
                    icon: Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: unitController,
                    label: "📏 الوحدة",
                    icon: Icons.straighten,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: quantityController,
                    label: "🔢 العدد",
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: notesController,
                    label: "📝 الملاحظات",
                    icon: Icons.notes,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("إلغاء"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _save,
                          child: const Text("حفظ البيانات"),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1),
        ),
      ),
    );
  }
}
