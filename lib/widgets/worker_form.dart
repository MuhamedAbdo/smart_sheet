// lib/src/widgets/workers/worker_form.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

class WorkerForm extends StatefulWidget {
  final Worker? existingWorker;
  final Box<Worker> box; // ✅ إضافة الحقل

  const WorkerForm(
      {super.key, this.existingWorker, required this.box}); // ✅ تعديل المُنشئ

  @override
  State<WorkerForm> createState() => _WorkerFormState();

  // ✅ تعديل الدالة الثابتة لتمرير الصندوق
  static void show(BuildContext context,
      {Worker? existingWorker, Box<Worker>? box}) {
    // ✅ تأكد من أن الصندوق مُمرر، وإلا استخدم القيمة الافتراضية (لكن من الأفضل دائمًا تمريره)
    final effectiveBox = box ?? Hive.box<Worker>('workers');
    showDialog(
      context: context,
      builder: (context) => WorkerForm(
          existingWorker: existingWorker, box: effectiveBox), // ✅ تمرير الصندوق
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
    // ✅ استخدام الصندوق المُمرر
    if (widget.existingWorker == null) {
      widget.box.add(Worker(
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
            initialValue: job,
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
