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
import 'package:shared_preferences/shared_preferences.dart';

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
  late bool canManageClientsAdd;
  late bool canManageClientsEdit;
  late bool canManageClientsDelete;
  late bool canAddWorker;
  late bool canEditWorker;
  late bool canDeleteWorker;
  late bool canReadArchive;
  late bool canAddArchive;
  late bool canRestoreArchive;
  late bool canDeleteArchive;
  late bool canAddWorkerAction;
  late bool canIssueJobOrders;

  /// قائمة الوظائف المتاحة بناءً على القسم المختار — تُحدَّث ديناميكياً
  List<String> availableJobs = [];

  /// قائمة الأقسام الكاملة الديناميكية (ثابتة + من Hive)
  List<String> _allDepartmentCodes = [];
  List<String> _allDepartmentLabels = [];


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
    // التكسير (die_cutting)
    'قسم التكسير': [
      'رئيس القسم', 'مشرف', 'فني', 'مساعد', 'عامل',
    ],
    // الدبوس والتعبئة (staples)
    'قسم الدبوس والتعبئة': [
      'رئيس القسم', 'مشرف', 'فني', 'مساعد', 'عامل',
    ],

    'الإدارة العامة وإدارة الإنتاج': [
      'مدير الإنتاج',
      'مشرف عام الإنتاج',
      'مشرف وردية',
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
    'قسم الصيانة': [
      'مهندس صيانة',
      'فني صيانة',
      'رئيس قسم',
    ],
    'قسم الموارد البشرية (HR)': [
      'مدير موارد بشرية',
      'أخصائي موارد بشرية',
      'شؤون عاملين',
    ],
  };


  /// ─── أقسام المصنع (key = كود Hive، value = المسمى الرسمي) ─────────────────
  // يجب أن يتطابق مع worker_card.dart (_getDepartmentArabicName) و workers_screen.dart
  static const Map<String, String> departmentOptions = {
    'flexo':             'قسم الفلكسو',
    'production_line':   'قسم خط الإنتاج',
    'die_cutting':       'قسم التكسير',          // workers_crushing → die_cutting
    'staples':           'قسم الدبوس والتعبئة',  // workers_staple → staples (مستقل)
    'general_mgmt':      'الإدارة العامة وإدارة الإنتاج',
    'technical_support': 'قسم الدعم الفني والتجهيزات',
    'quality_control':   'قسم مراقبة الجودة',
    'accounting':        'قسم الحسابات والمالية',
    'stores':            'قسم المخازن واللوجستيات',
    'sales':             'قسم المبيعات والتعاقدات',
    'secretariat':       'قسم السكرتارية والمكتب الأمامي',
    'maintenance':       'قسم الصيانة',
    'hr':                'قسم الموارد البشرية (HR)',
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

    // بناء قوائم الأقسام الديناميكية (Static + Hive)
    _buildDynamicDepartmentLists();

    // تحديد القسم الافتراضي
    String initialDept = widget.existingWorker?.department ??
        widget.defaultDepartment ??
        'flexo';

    // لا نحول 'staples' إلى 'die_cutting' — كل منهما كود مستقل الآن
    // إذا كان القسم ليس في القائمة الثابتة ولا الديناميكية → أضفه كقسم مخصص
    if (!_allDepartmentCodes.contains(initialDept)) {
      _allDepartmentCodes.add(initialDept);
      // إذا كان موجوداً في departmentOptions نأخذ مسماه من هناك، وإلا نستخدم الكود
      final label = departmentOptions[initialDept] ?? initialDept;
      _allDepartmentLabels.add(label);
    }
    
    selectedDepartment = initialDept;

    // ملء availableJobs بناءً على القسم الأولي
    _updateJobsForDepartment(selectedDepartment, existingJob: widget.existingWorker?.job);

    canAdd    = widget.existingWorker?.canAdd    ?? false;
    canEdit   = widget.existingWorker?.canEdit   ?? false;
    canDelete = widget.existingWorker?.canDelete ?? false;
    canManageClientsAdd    = widget.existingWorker?.canManageClientsAdd    ?? false;
    canManageClientsEdit   = widget.existingWorker?.canManageClientsEdit   ?? false;
    canManageClientsDelete = widget.existingWorker?.canManageClientsDelete ?? false;
    canAddWorker    = widget.existingWorker?.canAddWorker    ?? false;
    canEditWorker   = widget.existingWorker?.canEditWorker   ?? false;
    canDeleteWorker = widget.existingWorker?.canDeleteWorker ?? false;
    canReadArchive  = widget.existingWorker?.canReadArchive  ?? false;
    canAddArchive   = widget.existingWorker?.canAddArchive   ?? false;
    canRestoreArchive = widget.existingWorker?.canRestoreArchive ?? false;
    canDeleteArchive= widget.existingWorker?.canDeleteArchive?? false;
    canAddWorkerAction = widget.existingWorker?.canAddWorkerAction ?? false;
    canIssueJobOrders = widget.existingWorker?.canIssueJobOrders ?? false;

    // تحميل أي أقسام أو وظائف مخصصة محفوظة في SharedPreferences
    _loadCustomDepartmentsAndJobsFromPrefs();
  }

  Future<void> _loadCustomDepartmentsAndJobsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customDepts = prefs.getStringList('custom_departments') ?? [];
      bool changed = false;
      for (final dept in customDepts) {
        if (dept.trim().isNotEmpty && !_allDepartmentCodes.contains(dept)) {
          _allDepartmentCodes.add(dept);
          _allDepartmentLabels.add(departmentOptions[dept] ?? dept);
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {});
      }
      await _loadCustomJobsFromPrefs(selectedDepartment);
    } catch (e) {
      debugPrint('Error loading custom departments/jobs from prefs: $e');
    }
  }

  Future<void> _loadCustomJobsFromPrefs(String deptCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customJobs = prefs.getStringList('custom_jobs_$deptCode') ?? [];
      bool changed = false;
      for (final cJob in customJobs) {
        if (cJob.trim().isNotEmpty && !availableJobs.contains(cJob)) {
          availableJobs.add(cJob);
          changed = true;
        }
      }
      if (changed && mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading custom jobs from prefs: $e');
    }
  }

  // ─── بناء قوائم الأقسام الديناميكية — Static + Hive extraction ────────────────────
  void _buildDynamicDepartmentLists() {
    _allDepartmentCodes = List<String>.from(departmentOptions.keys);
    _allDepartmentLabels = List<String>.from(departmentOptions.values);

    if (Hive.isBoxOpen('workers')) {
      final workersBox = Hive.box<Worker>('workers');
      for (final worker in workersBox.values) {
        final dept = worker.department.trim();
        if (dept.isNotEmpty && !_allDepartmentCodes.contains(dept)) {
          _allDepartmentCodes.add(dept);
          _allDepartmentLabels.add(departmentOptions[dept] ?? dept);
          debugPrint('🏭 [WorkerForm] قسم جديد من Hive: $dept');
        }
      }
    }
  }

  void _updateJobsForDepartment(String deptCode, {String? existingJob}) {
    final deptLabel = departmentOptions[deptCode] ?? deptCode;
    final staticJobs = List<String>.from(departmentJobsMap[deptLabel] ?? []);

    if (Hive.isBoxOpen('workers')) {
      final workersBox = Hive.box<Worker>('workers');
      for (final worker in workersBox.values) {
        if (worker.department.trim() == deptCode) {
          final job = worker.job.trim();
          if (job.isNotEmpty && !staticJobs.contains(job)) {
            staticJobs.add(job);
            debugPrint('🛠 [WorkerForm] وظيفة جديدة من Hive: $job');
          }
        }
      }
    }

    if (staticJobs.isEmpty) staticJobs.add('عامل');

    availableJobs = staticJobs;

    final jobToUse = existingJob ?? selectedJob;
    selectedJob = (jobToUse != null && staticJobs.contains(jobToUse))
        ? jobToUse
        : staticJobs.first;

    _loadCustomJobsFromPrefs(deptCode);
  }

  // ─── ديالوج إضافة قسم جديد (Inline Add) ───────────────────────────────
  Future<void> _showAddDepartmentDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_business, color: Colors.blue),
            SizedBox(width: 8),
            Text('إضافة قسم جديد'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اسم القسم',
            hintText: 'مثال: قسم التغليف...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('حفظ'),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final customDepts = prefs.getStringList('custom_departments') ?? [];
      if (!customDepts.contains(result)) {
        customDepts.add(result);
        await prefs.setStringList('custom_departments', customDepts);
      }
    } catch (e) {
      debugPrint('Error saving custom department: $e');
    }

    setState(() {
      if (!_allDepartmentCodes.contains(result)) {
        _allDepartmentCodes.add(result);
        _allDepartmentLabels.add(result);
      }
      selectedDepartment = result;
      _updateJobsForDepartment(result);
    });
    debugPrint('➕ [WorkerForm] قسم جديد مضاف: $result');
  }

  // ─── ديالوج إضافة وظيفة جديدة (Inline Add) ──────────────────────────
  Future<void> _showAddJobDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.work_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('إضافة وظيفة جديدة'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            labelText: 'اسم الوظيفة',
            hintText: 'مثال: مشغّل آلات...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('حفظ'),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'custom_jobs_$selectedDepartment';
      final customJobs = prefs.getStringList(key) ?? [];
      if (!customJobs.contains(result)) {
        customJobs.add(result);
        await prefs.setStringList(key, customJobs);
      }
    } catch (e) {
      debugPrint('Error saving custom job: $e');
    }

    setState(() {
      if (!availableJobs.contains(result)) {
        availableJobs.add(result);
      }
      selectedJob = result;
    });
    debugPrint('➕ [WorkerForm] وظيفة جديدة مضافة: $result');
  }

  // ─── ميزة الحذف الآمن للأقسام والوظائف اليدوية ───────────────────────
  Future<bool> _attemptDeleteCustomDepartment(String deptCode) async {
    if (departmentOptions.containsKey(deptCode)) return false;

    final workersBox = Hive.isBoxOpen('workers') ? Hive.box<Worker>('workers') : widget.box;
    final isUsed = workersBox.values.any((w) {
      final wDept = w.department.trim();
      return wDept == deptCode.trim() ||
          (departmentOptions[wDept] ?? wDept) == (departmentOptions[deptCode] ?? deptCode.trim());
    });

    if (isUsed) {
      UIUtils.showInfoSnackBar(
        message: "لا يمكن حذف هذا القسم/الوظيفة لوجود عمال مسجلين عليه حالياً. قم بنقل العمال أولاً.",
        backgroundColor: Colors.redAccent,
        icon: Icons.warning_amber_rounded,
      );
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('custom_departments') ?? [];
      list.remove(deptCode);
      await prefs.setStringList('custom_departments', list);
      await prefs.remove('custom_jobs_$deptCode');
    } catch (e) {
      debugPrint('Error deleting custom department from prefs: $e');
    }

    setState(() {
      final idx = _allDepartmentCodes.indexOf(deptCode);
      if (idx != -1) {
        _allDepartmentCodes.removeAt(idx);
        if (idx < _allDepartmentLabels.length) {
          _allDepartmentLabels.removeAt(idx);
        }
      }
      if (selectedDepartment == deptCode) {
        selectedDepartment = _allDepartmentCodes.isNotEmpty ? _allDepartmentCodes.first : 'flexo';
        _updateJobsForDepartment(selectedDepartment);
      }
    });

    UIUtils.showInfoSnackBar(
      message: "تم حذف القسم بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
    return true;
  }

  Future<bool> _attemptDeleteCustomJob(String jobName) async {
    final deptLabel = departmentOptions[selectedDepartment] ?? selectedDepartment;
    final hardcodedJobs = departmentJobsMap[deptLabel] ?? [];
    if (hardcodedJobs.contains(jobName)) return false;

    final workersBox = Hive.isBoxOpen('workers') ? Hive.box<Worker>('workers') : widget.box;
    final isUsed = workersBox.values.any((w) {
      final wDept = w.department.trim();
      final wJob = w.job.trim();
      final isSameDept = wDept == selectedDepartment.trim() ||
          (departmentOptions[wDept] ?? wDept) ==
              (departmentOptions[selectedDepartment] ?? selectedDepartment.trim());
      return isSameDept && wJob == jobName.trim();
    });

    if (isUsed) {
      UIUtils.showInfoSnackBar(
        message: "لا يمكن حذف هذا القسم/الوظيفة لوجود عمال مسجلين عليه حالياً. قم بنقل العمال أولاً.",
        backgroundColor: Colors.redAccent,
        icon: Icons.warning_amber_rounded,
      );
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'custom_jobs_$selectedDepartment';
      final list = prefs.getStringList(key) ?? [];
      list.remove(jobName);
      await prefs.setStringList(key, list);
    } catch (e) {
      debugPrint('Error deleting custom job from prefs: $e');
    }

    setState(() {
      availableJobs.remove(jobName);
      if (selectedJob == jobName) {
        selectedJob = availableJobs.isNotEmpty ? availableJobs.first : 'عامل';
      }
    });

    UIUtils.showInfoSnackBar(
      message: "تم حذف الوظيفة بنجاح",
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
    return true;
  }

  void _showDepartmentPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'اختر القسم',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _allDepartmentCodes.length,
                        itemBuilder: (context, idx) {
                          final code = _allDepartmentCodes[idx];
                          final label = idx < _allDepartmentLabels.length
                              ? _allDepartmentLabels[idx]
                              : code;
                          final isSelected = code == selectedDepartment;
                          final isHardcoded = departmentOptions.containsKey(code);

                          return ListTile(
                            leading: Icon(
                              isHardcoded ? Icons.business : Icons.business_outlined,
                              color: isSelected ? Colors.blue : Colors.grey[700],
                            ),
                            title: Text(
                              label,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.blue : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isHardcoded)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                    tooltip: 'حذف القسم اليدوي',
                                    onPressed: () async {
                                      final success = await _attemptDeleteCustomDepartment(code);
                                      if (success) {
                                        setSheetState(() {});
                                      }
                                    },
                                  ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                selectedDepartment = code;
                                _updateJobsForDepartment(code);
                              });
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                      title: const Text(
                        '➕ إضافة قسم جديد...',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _showAddDepartmentDialog();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showJobPickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final deptLabel = departmentOptions[selectedDepartment] ?? selectedDepartment;
            final hardcodedJobs = departmentJobsMap[deptLabel] ?? [];

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.work, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'اختر الوظيفة',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableJobs.length,
                        itemBuilder: (context, idx) {
                          final job = availableJobs[idx];
                          final isSelected = job == selectedJob;
                          final isHardcoded = hardcodedJobs.contains(job);

                          return ListTile(
                            leading: Icon(
                              isHardcoded ? Icons.work : Icons.work_outline,
                              color: isSelected ? Colors.green : Colors.grey[700],
                            ),
                            title: Text(
                              job,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.green : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isHardcoded)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                                    tooltip: 'حذف الوظيفة اليدوية',
                                    onPressed: () async {
                                      final success = await _attemptDeleteCustomJob(job);
                                      if (success) {
                                        setSheetState(() {});
                                      }
                                    },
                                  ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                              ],
                            ),
                            onTap: () {
                              setState(() => selectedJob = job);
                              Navigator.pop(sheetContext);
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.green),
                      title: const Text(
                        '➕ إضافة وظيفة جديدة...',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        await _showAddJobDialog();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

    try {
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
          canManageClientsAdd: canManageClientsAdd,
          canManageClientsEdit: canManageClientsEdit,
          canManageClientsDelete: canManageClientsDelete,
          canAddWorker: canAddWorker,
          canEditWorker: canEditWorker,
          canDeleteWorker: canDeleteWorker,
          canReadArchive: canReadArchive,
          canAddArchive: canAddArchive,
          canRestoreArchive: canRestoreArchive,
          canDeleteArchive: canDeleteArchive,
          canAddWorkerAction: canAddWorkerAction,
          canIssueJobOrders: canIssueJobOrders,
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
        w.canManageClientsAdd = canManageClientsAdd;
        w.canManageClientsEdit = canManageClientsEdit;
        w.canManageClientsDelete = canManageClientsDelete;
        w.canAddWorker = canAddWorker;
        w.canEditWorker = canEditWorker;
        w.canDeleteWorker = canDeleteWorker;
        w.canReadArchive = canReadArchive;
        w.canAddArchive = canAddArchive;
        w.canRestoreArchive = canRestoreArchive;
        w.canDeleteArchive = canDeleteArchive;
        w.canAddWorkerAction = canAddWorkerAction;
        w.canIssueJobOrders = canIssueJobOrders;
        w.email = emailVal;
        
        // ✅ الحل الصحيح والآمن للتعامل مع كائنات Hive
        if (w.isInBox) {
          await w.save(); // يقوم بتحديث نفسه بمفتاحه الأصلي دون تعارض
        } else {
          // مفتاح احتياطي في حال كان الكائن غير مرتبط بصندوق
          final keyToUse = w.key ?? w.syncId!; 
          await widget.box.put(keyToUse, w);
        }
        
        // ✅ إصلاح: لا نُرسل device_id و is_device_linked من جهاز الأدمن
        // لأن الأدمن لا يملك هذه البيانات محلياً — إرسالها بـ null يمسح ربط جهاز العامل!
        // نستخدم نسخة منقّحة من toJson() تحذف هذين الحقلين عند التعديل فقط.
        final editPayload = Map<String, dynamic>.from(w.toJson())
          ..remove('device_id')
          ..remove('is_device_linked');
        SyncService.instance.pushToQueue('workers', editPayload);
      }
      
      if (mounted) Navigator.pop(context); // الإغلاق فقط عند النجاح
      
    } catch (e) {
      debugPrint("Error saving worker: $e");
      if (mounted) {
        UIUtils.showInfoSnackBar(
          message: "عفواً، حدث خطأ أثناء الحفظ. (السبب: ${e.toString().split('\n').first})",
          backgroundColor: Colors.redAccent,
          icon: Icons.error_outline,
        );
      }
    }
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
                InkWell(
                  onTap: _showDepartmentPickerBottomSheet,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "🏢 القسم",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _allDepartmentLabels.isNotEmpty && _allDepartmentCodes.contains(selectedDepartment)
                          ? _allDepartmentLabels[_allDepartmentCodes.indexOf(selectedDepartment)]
                          : (departmentOptions[selectedDepartment] ?? selectedDepartment),
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // ─── 2) الوظيفة — ديناميكية حسب القسم المختار ────────────────
              InkWell(
                onTap: _showJobPickerBottomSheet,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "🛠 الوظيفة",
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    selectedJob ?? availableJobs.firstOrNull ?? 'عامل',
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (showPermissions && widget.defaultDepartment == null) ...[
                const SizedBox(height: 15),
                const Divider(),
                ExpansionTile(
                  title: const Text("🏭 صلاحيات الإنتاج", style: TextStyle(fontWeight: FontWeight.bold)),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  dense: true,
                  children: [
                    CheckboxListTile(
                      title: const Text("إضافة تقارير"),
                      value: canAdd,
                      dense: true,
                      onChanged: (val) => setState(() => canAdd = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("تعديل تقارير"),
                      value: canEdit,
                      dense: true,
                      onChanged: (val) => setState(() => canEdit = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("حذف تقارير"),
                      value: canDelete,
                      dense: true,
                      onChanged: (val) => setState(() => canDelete = val ?? false),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text("📦 صلاحيات العملاء والأصناف", style: TextStyle(fontWeight: FontWeight.bold)),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  dense: true,
                  children: [
                    CheckboxListTile(
                      title: const Text("إضافة عملاء وأصناف"),
                      value: canManageClientsAdd,
                      dense: true,
                      onChanged: (val) => setState(() => canManageClientsAdd = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("تعديل عملاء وأصناف"),
                      value: canManageClientsEdit,
                      dense: true,
                      onChanged: (val) => setState(() => canManageClientsEdit = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("حذف عملاء وأصناف"),
                      value: canManageClientsDelete,
                      dense: true,
                      onChanged: (val) => setState(() => canManageClientsDelete = val ?? false),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text("📄 صلاحيات أوامر التشغيل", style: TextStyle(fontWeight: FontWeight.bold)),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  dense: true,
                  children: [
                    CheckboxListTile(
                      title: const Text("إصدار أوامر التشغيل"),
                      value: canIssueJobOrders,
                      dense: true,
                      onChanged: (val) => setState(() => canIssueJobOrders = val ?? false),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text("👥 صلاحيات شؤون العاملين", style: TextStyle(fontWeight: FontWeight.bold)),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  dense: true,
                  children: [
                    CheckboxListTile(
                      title: const Text("إضافة عامل"),
                      value: canAddWorker,
                      dense: true,
                      onChanged: (val) => setState(() => canAddWorker = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("تعديل عامل"),
                      value: canEditWorker,
                      dense: true,
                      onChanged: (val) => setState(() => canEditWorker = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("حذف عامل"),
                      value: canDeleteWorker,
                      dense: true,
                      onChanged: (val) => setState(() => canDeleteWorker = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("إضافة حركة عامل"),
                      value: canAddWorkerAction,
                      dense: true,
                      onChanged: (val) => setState(() => canAddWorkerAction = val ?? false),
                    ),
                  ],
                ),
                ExpansionTile(
                  title: const Text("🗄️ صلاحيات الأرشيف", style: TextStyle(fontWeight: FontWeight.bold)),
                  collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
                  shape: const RoundedRectangleBorder(side: BorderSide.none),
                  dense: true,
                  children: [
                    CheckboxListTile(
                      title: const Text("قراءة الأرشيف (جميع الأقسام)"),
                      value: canReadArchive,
                      dense: true,
                      onChanged: (val) => setState(() => canReadArchive = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("إضافة للأرشيف (نفس القسم فقط)"),
                      value: canAddArchive,
                      dense: true,
                      onChanged: (val) => setState(() => canAddArchive = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("استعادة الأرشيف (نفس القسم فقط)"),
                      value: canRestoreArchive,
                      dense: true,
                      onChanged: (val) => setState(() => canRestoreArchive = val ?? false),
                    ),
                    CheckboxListTile(
                      title: const Text("حذف من الأرشيف (نفس القسم فقط)"),
                      value: canDeleteArchive,
                      dense: true,
                      onChanged: (val) => setState(() => canDeleteArchive = val ?? false),
                    ),
                  ],
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
