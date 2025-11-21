// lib/src/widgets/maintenance/maintenance_section.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/widgets/maintenance_form.dart';
import 'package:smart_sheet/widgets/maintenance_list.dart';

class MaintenanceSection extends StatefulWidget {
  final String boxName;
  final String? title;

  const MaintenanceSection({
    super.key,
    required this.boxName,
    this.title,
  });

  @override
  State<MaintenanceSection> createState() => _MaintenanceSectionState();
}

class _MaintenanceSectionState extends State<MaintenanceSection> {
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
    showDialog(
      context: context,
      builder: (context) => MaintenanceForm(
        existingData: existingData,
        onSave: (record) async {
          final box = await _boxFuture;
          if (index == null) {
            await box.add(record);
          } else {
            await box.putAt(index, record);
          }
          // ✅ إعادة تحميل البيانات لعرض الصور مباشرة
          if (mounted) {
            setState(() {
              _boxFuture = _openBox();
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteMaintenance(int index) async {
    final box = await _boxFuture;
    await box.deleteAt(index);
    // ✅ إعادة تحميل البيانات
    if (mounted) {
      setState(() {
        _boxFuture = _openBox();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box>(
      future: _boxFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text("❌ خطأ: ${snapshot.error}"));
          }

          final box = snapshot.data!;

          return Scaffold(
            body: MaintenanceList(
              box: box,
              onAdd: () => _addOrEditMaintenance(),
              onEdit: (index, data) =>
                  _addOrEditMaintenance(index: index, existingData: data),
              onDelete: _deleteMaintenance,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _addOrEditMaintenance(),
              child: const Icon(Icons.add),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
