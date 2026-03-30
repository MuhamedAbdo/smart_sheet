import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart'; 
import 'package:smart_sheet/utils/ui_utils.dart';

class WorkerForm extends StatefulWidget {
  final Worker? existingWorker;
  final Box<Worker> box;

  const WorkerForm({super.key, this.existingWorker, required this.box});

  @override
  State<WorkerForm> createState() => _WorkerFormState();

  static void show(BuildContext context,
      {Worker? existingWorker, Box<Worker>? box}) {
    final effectiveBox = box ?? Hive.box<Worker>('workers');
    showDialog(
      context: context,
      builder: (context) =>
          WorkerForm(existingWorker: existingWorker, box: effectiveBox),
    );
  }
}

class _WorkerFormState extends State<WorkerForm> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late String job;

  // ✅ تعريف المشغل الخاص بالمكتبة الموجودة في pubspec.yaml
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();

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

  // ✅ الدالة المعدلة لتتوافق مع flutter_native_contact_picker
  Future<void> _pickContact() async {
    try {
      // المكتبة تعيد كائن من نوع Contact
      final Contact? contact = await _contactPicker.selectContact();

      if (contact != null &&
          contact.phoneNumbers != null &&
          contact.phoneNumbers!.isNotEmpty) {
        setState(() {
          // نأخذ أول رقم موجود في قائمة أرقام جهة الاتصال
          String rawNumber = contact.phoneNumbers!.first;

          // تنظيف الرقم من المسافات أو الرموز الغريبة
          String cleanNumber = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
          phoneController.text = cleanNumber;

          // إذا كان الاسم فارغاً، نضع اسم جهة الاتصال
          if (nameController.text.isEmpty && contact.fullName != null) {
            nameController.text = contact.fullName!;
          }
        });
      }
    } catch (e) {
      debugPrint("Error picking contact: $e");
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "تعذر الوصول لجهات الاتصال",
          backgroundColor: Colors.redAccent,
          icon: Icons.contact_phone,
        );
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _saveWorker() {
    if (nameController.text.trim().isEmpty) return;

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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "👤 الاسم")),
            const SizedBox(height: 10),
            TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: "📞 الهاتف",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contact_phone, color: Colors.blue),
                    onPressed: _pickContact,
                    tooltip: "اختيار من جهات الاتصال",
                  ),
                ),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
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
