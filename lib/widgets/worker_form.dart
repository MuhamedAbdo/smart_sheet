import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_sheet/services/sync_service.dart';

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

  void _saveWorker() async {
    if (nameController.text.trim().isEmpty) return;

    // جلب factory_id من التخزين الآمن
    const storage = FlutterSecureStorage();
    final factoryId = await storage.read(key: 'factory_id');

    if (widget.existingWorker == null) {
      // إضافة عامل جديد — UUID يُولّد تلقائياً في الـ constructor
      final worker = Worker(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        job: job,
        actions: [],
        factoryId: factoryId,
      );

      // FIX: box.put(syncId) بدلاً من box.add() — مفتاح ثابت يمنع التكرار
      await widget.box.put(worker.syncId!, worker);
      debugPrint('✅ [WorkerForm] أُضيف العامل: ${worker.name} (key=${worker.syncId})');

      // رفع للسحاب عبر Queue (يتضمن sync_id تلقائياً من toJson)
      SyncService.instance.pushToQueue('workers', worker.toJson());
    } else {
      final w = widget.existingWorker!;
      w.name = nameController.text.trim();
      w.phone = phoneController.text.trim();
      w.job = job;
      w.factoryId ??= factoryId;
      // الـ syncId محفوظ بالفعل في الكائن — لا نغيره
      await w.save();
      // رفع للسحاب عبر Queue
      SyncService.instance.pushToQueue('workers', w.toJson());
    }
    if (mounted) Navigator.pop(context);
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
