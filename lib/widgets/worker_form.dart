// lib/src/widgets/workers/worker_form.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

class WorkerForm extends StatefulWidget {
  final Worker? existingWorker;

  const WorkerForm({super.key, this.existingWorker});

  @override
  State<WorkerForm> createState() => _WorkerFormState();

  // ✅ الدالة الثابتة لفتح الـ Dialog
  static void show(BuildContext context, {Worker? existingWorker}) {
    showDialog(
      context: context,
      builder: (context) => WorkerForm(existingWorker: existingWorker),
    );
  }
}

class _WorkerFormState extends State<WorkerForm> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late String job;

  final jobOptions = ['رئيس القسم', 'مشرف', 'فني', 'عامل', 'مساعد'];

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.existingWorker?.name ?? '');
    phoneController =
        TextEditingController(text: widget.existingWorker?.phone ?? '');
    job = widget.existingWorker?.job ?? 'عامل';
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _saveWorker() {
    final box = Hive.box<Worker>('workers');
    if (widget.existingWorker == null) {
      box.add(Worker(
        name: nameController.text,
        phone: phoneController.text,
        job: job,
        actions: [],
      ));
    } else {
      final w = widget.existingWorker!;
      w.name = nameController.text;
      w.phone = phoneController.text;
      w.job = job;
      w.save();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existingWorker == null ? "➕ إضافة عامل" : "✏️ تعديل العامل"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "👤 الاسم")),
          TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "📞 الهاتف"),
              keyboardType: TextInputType.phone),
          DropdownButtonFormField(
            value: job,
            items: jobOptions
                .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                .toList(),
            onChanged: (v) => setState(() => job = v ?? 'عامل'),
            decoration: const InputDecoration(labelText: "🛠 الوظيفة"),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("❌ إلغاء")),
        ElevatedButton(onPressed: _saveWorker, child: const Text("💾 حفظ")),
      ],
    );
  }
}
