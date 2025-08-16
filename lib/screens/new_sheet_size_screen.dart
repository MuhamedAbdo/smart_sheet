// lib/src/screens/sheet_size/new_sheet_size_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/new_sheet_size_form.dart';

class NewSheetSizeScreen extends StatefulWidget {
  final String? existingDataKey;
  final Map<String, dynamic>? existingData;
  final String boxName; // ✅ لدعم صناديق متعددة

  const NewSheetSizeScreen({
    super.key,
    this.existingDataKey,
    this.existingData,
    this.boxName =
        'savedSheetSizes_production', // ✅ القيمة الافتراضية لخط الإنتاج
  });

  @override
  State<NewSheetSizeScreen> createState() => _NewSheetSizeScreenState();
}

class _NewSheetSizeScreenState extends State<NewSheetSizeScreen> {
  late Box _savedBox;

  @override
  void initState() {
    super.initState();
    _savedBox = Hive.box(widget.boxName);
  }

  void _saveSize(Map<String, dynamic> sizeData) {
    if (widget.existingDataKey != null) {
      _savedBox.put(widget.existingDataKey, sizeData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم تحديث المقاس")),
      );
    } else {
      _savedBox.add(sizeData);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ تم حفظ المقاس")),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          widget.existingDataKey == null
              ? "📏 إضافة مقاس جديد"
              : "✏️ تعديل المقاس",
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: NewSheetSizeForm(
          existingData: widget.existingData,
          onSave: _saveSize,
        ),
      ),
    );
  }
}
