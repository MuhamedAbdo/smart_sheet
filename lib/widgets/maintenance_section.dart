// lib/src/widgets/maintenance/maintenance_section.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../models/maintenance_record_model.dart';
import 'maintenance_form.dart';
import 'maintenance_list.dart';

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
  late Future<Box<MaintenanceRecord>> _boxFuture;

  @override
  void initState() {
    super.initState();
    _boxFuture = _openBox();
  }

  Future<Box<MaintenanceRecord>> _openBox() async {
    return await Hive.openBox<MaintenanceRecord>(widget.boxName);
  }

  void _addOrEdit({int? index, MaintenanceRecord? existing}) {
    showDialog(
      context: context,
      builder: (_) => MaintenanceForm(
        existing: existing,
        onSave: (record) async {
          final box = await _boxFuture;

          if (index == null) {
            await box.add(record);
          } else {
            await box.putAt(index, record);
          }

          if (mounted) setState(() {});
          Navigator.pop(context);
        },
      ),
    );
  }

  void _delete(int index) async {
    final box = await _boxFuture;
    await box.deleteAt(index);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Box<MaintenanceRecord>>(
      future: _boxFuture,
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final box = snapshot.data!;

        return Scaffold(
          body: MaintenanceList(
            box: box,
            onAdd: () => _addOrEdit(),
            onEdit: (i, r) => _addOrEdit(index: i, existing: r),
            onDelete: _delete,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addOrEdit(),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
