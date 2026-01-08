// lib/src/screens/maintenance/maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/maintenance_form.dart';
import 'package:smart_sheet/widgets/maintenance_list.dart';
import '../../models/maintenance_record_model.dart';
import '../../widgets/app_drawer.dart';

class MaintenanceScreen extends StatefulWidget {
  final String boxName;
  final String? title;

  const MaintenanceScreen({
    super.key,
    required this.boxName,
    this.title,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Box<MaintenanceRecord>? _box;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMaintenanceBox();
  }

  Future<void> _initMaintenanceBox() async {
    try {
      if (!Hive.isBoxOpen(widget.boxName)) {
        await Hive.openBox<MaintenanceRecord>(widget.boxName);
      }

      if (mounted) {
        setState(() {
          _box = Hive.box<MaintenanceRecord>(widget.boxName);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error opening maintenance box: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addOrEdit({int? index, MaintenanceRecord? existing}) {
    if (_box == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // منع إغلاق الـ BottomSheet بسحبها لأسفل أثناء الرفع (اختياري)
      enableDrag: true,
      builder: (_) => MaintenanceForm(
        existing: existing,
        onSave: (record) async {
          // التعديل هنا: يتم الحفظ في Hive بعد أن يكون الرفع لـ Supabase قد تم داخل الـ Form
          if (index == null) {
            await _box!.add(record);
          } else {
            await _box!.putAt(index, record);
          }

          if (mounted) {
            setState(() {});
            // نغلق النموذج فقط بعد نجاح عملية الحفظ
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _delete(int index) async {
    if (_box != null) {
      await _box!.deleteAt(index);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? "تحميل...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_box == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("خطأ")),
        body: const Center(child: Text("تعذر فتح قاعدة بيانات الصيانة")),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.title ?? "سجلات الصيانة"),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: _box!.listenable(),
        builder: (context, Box<MaintenanceRecord> box, __) {
          if (box.isEmpty) {
            return const Center(child: Text("لا توجد سجلات صيانة"));
          }

          return MaintenanceList(
            box: box,
            onAdd: () => _addOrEdit(),
            onEdit: (i, r) => _addOrEdit(index: i, existing: r),
            onDelete: _delete,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
