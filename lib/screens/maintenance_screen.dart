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
  late Box<MaintenanceRecord> _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<MaintenanceRecord>(widget.boxName);
  }

  void _addOrEdit({int? index, MaintenanceRecord? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => MaintenanceForm(
        existing: existing,
        onSave: (record) async {
          if (index == null) {
            await _box.add(record);
          } else {
            await _box.putAt(index, record);
          }
          if (mounted) setState(() {});
          Navigator.pop(context);
        },
      ),
    );
  }

  void _delete(int index) async {
    await _box.deleteAt(index);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(widget.title ?? "سجلات الصيانة"),
        centerTitle: true,
      ),
      body: ValueListenableBuilder(
        valueListenable: _box.listenable(),
        builder: (context, _, __) {
          if (_box.isEmpty) {
            return const Center(child: Text("لا توجد سجلات صيانة"));
          }

          return MaintenanceList(
            box: _box,
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
