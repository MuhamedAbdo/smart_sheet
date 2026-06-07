import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/services/auth_service.dart';

class WorkerForm extends StatefulWidget {
  final Worker? existingWorker;
  final Box<Worker> box;
  final String? defaultDepartment;

  const WorkerForm({super.key, this.existingWorker, required this.box, this.defaultDepartment});

  @override
  State<WorkerForm> createState() => _WorkerFormState();

  static void show(BuildContext context,
      {Worker? existingWorker, Box<Worker>? box, String? defaultDepartment}) {
    final effectiveBox = box ?? Hive.box<Worker>('workers');
    showDialog(
      context: context,
      builder: (context) =>
          WorkerForm(existingWorker: existingWorker, box: effectiveBox, defaultDepartment: defaultDepartment),
    );
  }
}

class _WorkerFormState extends State<WorkerForm> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController emailController;

  /// الوظيفة المختارة حالياً (nullable لتجنّب assertion عند تغيير القسم)
  String? selectedJob;

  late String selectedDepartment;
  late bool canAdd;
  late bool canEdit;
  late bool canDelete;

  /// قائمة الوظائف المتاحة بناءً على القسم المختار — تُحدَّث ديناميكياً
  List<String> availableJobs = [];

  // ✅ تعريف المشغل الخاص بالمكتبة الموجودة في pubspec.yaml
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();

  // ─── خريطة القسم ↔ وظائفه ─────────────────────────────────────────────────
  // المفتاح = المسمى الرسمي للقسم (نفس قيمة departmentOptions)
  // القيمة = قائمة الوظائف التابعة لذلك القسم
  static const Map<String, List<String>> departmentJobsMap = {
    'قسم الفلكسو': [
      'رئيس القسم', 'مشرف', 'فني', 'مساعد', 'عامل',
    ],
    'قسم خط الإنتاج': [
      'رئيس القسم', 'مشرف', 'فني', 'مساعد', 'عامل',
    ],
    'قسم الدبوس والتعبئة': [
      'رئيس القسم', 'مشرف', 'فني', 'مساعد', 'عامل',
    ],
    'الإدارة العامة وإدارة الإنتاج': [
      'مدير الإنتاج',
      'مشرف عام الإنتاج',
      'مدير HR / شؤون عاملين',
      'موظف إداري',
    ],
    'قسم الدعم الفني والتجهيزات': [
      'فني مونتاج أكلاشيهات',
      'فني فورم وتكسير',
      'فني عينات / تصميم',
    ],
    'قسم مراقبة الجودة': [
      'مدير الجودة',
      'مراقب جودة (صالة الإنتاج)',
      'فني مختبر / معمل',
    ],
    'قسم الحسابات والمالية': [
      'مدير حسابات',
      'محاسب عملاء',
      'محاسب موردين',
      'خزينة / كاشير',
    ],
    'قسم المخازن واللوجستيات': [
      'مدير مخازن',
      'أمين مخزن رولات',
      'أمين مخزن إنتاج تام',
      'أمين مخزن خامات مساعدة',
      'سائق كلارك',
    ],
    'قسم المبيعات والتعاقدات': [
      'مدير مبيعات',
      'مسؤول مبيعات / مندوب',
    ],
    'قسم السكرتارية والمكتب الأمامي': [
      'سكرتارية تنفيذية',
      'مسؤول إصدار أوامر التشغيل',
      'مدخل بيانات إداري',
    ],
  };

  /// ─── أقسام المصنع العشرة (key = كود Hive، value = المسمى الرسمي) ─────────
  static const Map<String, String> departmentOptions = {
    'flexo':             'قسم الفلكسو',
    'production_line':   'قسم خط الإنتاج',
    'die_cutting':       'قسم الدبوس والتعبئة',
    'general_mgmt':      'الإدارة العامة وإدارة الإنتاج',
    'technical_support': 'قسم الدعم الفني والتجهيزات',
    'quality_control':   'قسم مراقبة الجودة',
    'accounting':        'قسم الحسابات والمالية',
    'stores':            'قسم المخازن واللوجستيات',
    'sales':             'قسم المبيعات والتعاقدات',
    'secretariat':       'قسم السكرتارية والمكتب الأمامي',
  };

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.existingWorker?.name ?? '');
    phoneController =
        TextEditingController(text: widget.existingWorker?.phone ?? '');
    emailController =
        TextEditingController(text: widget.existingWorker?.email ?? '');

    // تحديد القسم الافتراضي
    selectedDepartment = widget.existingWorker?.department ??
        widget.defaultDepartment ??
        'flexo';

    // ملء availableJobs بناءً على القسم الأولي
    _updateJobsForDepartment(selectedDepartment, existingJob: widget.existingWorker?.job);

    canAdd    = widget.existingWorker?.canAdd    ?? false;
    canEdit   = widget.existingWorker?.canEdit   ?? false;
    canDelete = widget.existingWorker?.canDelete ?? false;
  }

  /// يُحدّث [availableJobs] عند تغيير القسم ويعيد تعيين الوظيفة المختارة.
  /// [existingJob] يُمرَّر فقط عند التهيئة الأولى للحفاظ على قيمة العامل الموجود.
  void _updateJobsForDepartment(String deptCode, {String? existingJob}) {
    final deptLabel = departmentOptions[deptCode] ?? '';
    final jobs = List<String>.from(departmentJobsMap[deptLabel] ?? []);

    // إذا القائمة فارغة (قسم غير معرَّف) أضف placeholder
    if (jobs.isEmpty) jobs.add('عامل');

    availableJobs = jobs;

    // إذا الوظيفة الحالية موجودة في القائمة الجديدة → أبقِها، وإلا → أول عنصر
    final jobToUse = existingJob ?? selectedJob;
    selectedJob = (jobToUse != null && jobs.contains(jobToUse))
        ? jobToUse
        : jobs.first;
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
    emailController.dispose();
    super.dispose();
  }

  void _saveWorker() async {
    if (nameController.text.trim().isEmpty) return;

    // جلب factory_id من التخزين الآمن
    const storage = SafeSecureStorage();
    final factoryId = await storage.read(key: 'factory_id');
    
    final emailVal = emailController.text.trim().isEmpty 
        ? null 
        : emailController.text.trim();

    // الوظيفة المُختارة نهائياً (selectedJob مضمون غير null بعد initState)
    final finalJob = selectedJob ?? availableJobs.firstOrNull ?? 'عامل';

    if (widget.existingWorker == null) {
      // إضافة عامل جديد — UUID يُولّد تلقائياً في الـ constructor
      final worker = Worker(
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
        job: finalJob,
        actions: [],
        factoryId: factoryId,
        department: selectedDepartment,
        canAdd: canAdd,
        canEdit: canEdit,
        canDelete: canDelete,
        email: emailVal,
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
      w.job = finalJob;
      w.factoryId ??= factoryId;
      w.department = selectedDepartment;
      w.canAdd = canAdd;
      w.canEdit = canEdit;
      w.canDelete = canDelete;
      w.email = emailVal;
      // نستخدم widget.box.put بدلاً من w.save() لتجنب خطأ (This object is currently not in a box)
      await widget.box.put(w.syncId!, w);
      // رفع للسحاب عبر Queue
      SyncService.instance.pushToQueue('workers', w.toJson());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserEmail = currentUser?.email;

    final authService = Provider.of<AuthService>(context, listen: false);
    bool isCurrentUserManager = authService.isAdmin;

    final bool isSuperAdmin = currentUserEmail == 'mohamedabdo9999933@gmail.com';
    
    if (!isCurrentUserManager) {
      final workersBox = Hive.isBoxOpen('workers') 
          ? Hive.box<Worker>('workers') 
          : null;
      if (workersBox != null && currentUserEmail != null) {
        for (final worker in workersBox.values) {
          if (worker.email?.trim().toLowerCase() == currentUserEmail.trim().toLowerCase()) {
            if (worker.canAdd && worker.canEdit && worker.canDelete) {
              isCurrentUserManager = true;
            }
            break;
          }
        }
      }
    }

    final bool showPermissions = isSuperAdmin || isCurrentUserManager;

    return AlertDialog(
      title: Text(
          widget.existingWorker == null ? "➕ إضافة عامل" : "✏️ تعديل العامل"),
      content: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "📧 البريد الإلكتروني (اختياري)",
                    hintText: "example@email.com",
                  ),
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 10),
              // ─── 1) القسم أولاً (يُظهر الوظائف المناسبة) ─────────────────
              // لا يظهر إذا تم تمرير قسم ثابت من الخارج
              if (widget.defaultDepartment == null) ...[
                InputDecorator(
                  decoration: const InputDecoration(labelText: "🏢 القسم"),
                  child: DropdownButton<String>(
                    value: selectedDepartment,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: departmentOptions.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        selectedDepartment = v;
                        _updateJobsForDepartment(v);
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // ─── 2) الوظيفة — ديناميكية حسب القسم المختار ────────────────
              InputDecorator(
                decoration: const InputDecoration(labelText: "🛠 الوظيفة"),
                child: DropdownButton<String>(
                  value: selectedJob,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: availableJobs
                      .map((j) => DropdownMenuItem(value: j, child: Text(j)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedJob = v),
                ),
              ),
              if (showPermissions && widget.defaultDepartment == null) ...[
                const SizedBox(height: 15),
                const Divider(),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text("🔒 صلاحيات المشرفين (Supabase):", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                CheckboxListTile(
                  title: const Text("إضافة تقارير (canAdd)"),
                  value: canAdd,
                  dense: true,
                  onChanged: (val) => setState(() => canAdd = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text("تعديل تقارير (canEdit)"),
                  value: canEdit,
                  dense: true,
                  onChanged: (val) => setState(() => canEdit = val ?? false),
                ),
                CheckboxListTile(
                  title: const Text("حذف تقارير (canDelete)"),
                  value: canDelete,
                  dense: true,
                  onChanged: (val) => setState(() => canDelete = val ?? false),
                ),
              ],
            ],
          ),
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
