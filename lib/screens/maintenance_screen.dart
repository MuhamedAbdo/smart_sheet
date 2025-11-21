// lib/src/screens/maintenance/maintenance_screen.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/maintenance_form.dart';
import 'package:smart_sheet/widgets/maintenance_list.dart';

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
  late Future<Box> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = _openBox();
  }

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(widget.boxName)) {
      await Hive.openBox(widget.boxName);
    }
    return Hive.box(widget.boxName);
  }

  void _addOrEditMaintenance({int? index, Map<String, dynamic>? existingData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ مقبض السحب
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor, // ✅ استخدام dividerColor
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ✅ العنوان
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    existingData == null ? Icons.add : Icons.edit,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existingData == null
                        ? "إضافة سجل صيانة"
                        : "تعديل سجل صيانة",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            // ✅ الفورم
            Expanded(
              child: MaintenanceForm(
                existingData: existingData,
                onSave: (record) async {
                  final box = await _boxFuture;
                  if (index == null) {
                    await box.add(record);
                  } else {
                    await box.putAt(index, record);
                  }
                  // ✅ إعادة تحميل البيانات
                  if (mounted) {
                    setState(() {
                      _boxFuture = _openBox();
                    });
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMaintenance(int index) async {
    final box = await _boxFuture;

    // ✅ تأكيد الحذف مع دعم الوضع الليلي
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        title: Text(
          "تأكيد الحذف",
          style:
              TextStyle(color: Theme.of(context).textTheme.titleLarge?.color),
        ),
        content: Text(
          "هل أنت متأكد من حذف سجل الصيانة هذا؟",
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("حذف", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await box.deleteAt(index);
      // ✅ إعادة تحميل البيانات
      if (mounted) {
        setState(() {
          _boxFuture = _openBox();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.title ?? "🛠 سجلات الصيانة"),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: FutureBuilder<Box>(
          future: _boxFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error,
                        size: 50,
                        color: Theme.of(context)
                            .colorScheme
                            .error, // ✅ استخدام colorScheme.error
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "❌ خطأ: ${snapshot.error}",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                );
              }

              final box = snapshot.data!;

              // ✅ استخدام ValueListenableBuilder للتحديث التلقائي
              return ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box box, _) {
                  return MaintenanceList(
                    box: box,
                    onAdd: () => _addOrEditMaintenance(),
                    onEdit: (index, data) =>
                        _addOrEditMaintenance(index: index, existingData: data),
                    onDelete: (index) => _deleteMaintenance(index),
                  );
                },
              );
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color:
                          Theme.of(context).primaryColor, // ✅ دعم الوضع الليلي
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "جاري تحميل سجلات الصيانة...",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditMaintenance(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
