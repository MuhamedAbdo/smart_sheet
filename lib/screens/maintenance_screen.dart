// lib/src/screens/maintenance/maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../models/maintenance_record_model.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/maintenance_form.dart';
import '../../widgets/maintenance_list.dart';

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
  // 1. جعل الصندوق nullable واستخدام متغير لحالة التحميل
  Box<MaintenanceRecord>? _box;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMaintenanceBox();
  }

  // 2. دالة لفتح الصندوق بأمان قبل بناء الواجهة
  Future<void> _initMaintenanceBox() async {
    try {
      // التحقق مما إذا كان الصندوق مفتوحاً، وإذا لم يكن، نفتحه
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
      debugPrint("❌ Error opening maintenance box (${widget.boxName}): $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addOrEdit({int? index, MaintenanceRecord? existing}) {
    if (_box == null) return; // حماية إضافية

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MaintenanceForm(
        existing: existing,
        onSave: (record) async {
          if (index == null) {
            await _box!.add(record);
          } else {
            await _box!.putAt(index, record);
          }
          if (mounted) setState(() {});
          Navigator.pop(context);
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
    // 3. عرض مؤشر تحميل حتى يتم فتح الصندوق
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? "تحميل...")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 4. حالة فشل فتح الصندوق
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
