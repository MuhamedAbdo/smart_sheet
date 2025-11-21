// lib/src/screens/workers/workers_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart'; // ✅ استيراد نموذج العامل
import 'package:hive_flutter/hive_flutter.dart'; // ✅ استيراد Hive
import 'package:smart_sheet/models/worker_model.dart'; // ✅ استيراد النموذج

class WorkersScreen extends StatefulWidget {
  final String departmentBoxName; // ← الاسم المراد استخدامه
  final String departmentTitle;

  const WorkersScreen({
    super.key,
    required this.departmentBoxName,
    required this.departmentTitle,
  });

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  late Box<Worker> _box; // ✅ إضافة الحقل

  @override
  void initState() {
    super.initState();
    // ✅ فتح الصندوق المحدد عند تهيئة الشاشة
    _box = Hive.box<Worker>(widget.departmentBoxName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text("👷‍♂️ ${widget.departmentTitle} - العمال"),
        centerTitle: true,
      ),
      // ✅ تمرير الصندوق إلى WidgetList
      body: WorkerList(box: _box),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            WorkerForm.show(context, box: _box), // ✅ تمرير الصندوق إلى النموذج
        child: const Icon(Icons.add),
      ),
    );
  }
}
