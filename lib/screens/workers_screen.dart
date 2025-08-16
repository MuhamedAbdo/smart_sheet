// lib/src/screens/workers/workers_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart'; // ✅ استيراد نموذج العامل

class WorkersScreen extends StatelessWidget {
  final String departmentBoxName;
  final String departmentTitle;

  const WorkersScreen({
    super.key,
    required this.departmentBoxName,
    required this.departmentTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text("👷‍♂️ $departmentTitle - العمال"),
        centerTitle: true,
      ),
      body: const WorkerList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => WorkerForm.show(context), // ✅ تم التصحيح
        child: const Icon(Icons.add),
      ),
    );
  }
}
