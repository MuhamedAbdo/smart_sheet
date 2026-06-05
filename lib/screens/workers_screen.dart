import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/active_absences_dashboard.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/permission_helper.dart';

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
    // تحديد كود القسم المفلتر بناءً على departmentBoxName المُمرر
    String? filterDept;
    if (departmentBoxName == 'workers_flexo') {
      filterDept = 'flexo';
    } else if (departmentBoxName == 'workers_production') {
      filterDept = 'production_line';
    } else if (departmentBoxName == 'workers_crushing') {
      filterDept = 'die_cutting';
    } else if (departmentBoxName == 'workers_staple') {
      filterDept = 'die_cutting'; // الدبوس والتعبئة → نفس كود die_cutting
    } else if (departmentBoxName == 'workers_general_mgmt') {
      filterDept = 'general_mgmt';
    } else if (departmentBoxName == 'workers_technical_support') {
      filterDept = 'technical_support';
    } else if (departmentBoxName == 'workers_quality_control') {
      filterDept = 'quality_control';
    } else if (departmentBoxName == 'workers_accounting') {
      filterDept = 'accounting';
    } else if (departmentBoxName == 'workers_stores') {
      filterDept = 'stores';
    } else if (departmentBoxName == 'workers_sales') {
      filterDept = 'sales';
    } else if (departmentBoxName == 'workers_secretariat') {
      filterDept = 'secretariat';
    }

    if (Hive.isBoxOpen('workers')) {
      final box = Hive.box<Worker>('workers');
      return _buildScreenContent(context, box, filterDept);
    }

    return FutureBuilder<Box<Worker>>(
      future: Hive.openBox<Worker>('workers'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(departmentTitle)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "❌ خطأ: الصندوق مفتوح بنوع مختلف.\nيرجى إعادة تشغيل التطبيق.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final Box<Worker> box = snapshot.data!;
        return _buildScreenContent(context, box, filterDept);
      },
    );
  }

  Widget _buildScreenContent(BuildContext context, Box<Worker> box, String? filterDept) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("👷‍♂️ $departmentTitle - العمال"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: Colors.blueAccent),
            tooltip: "حذف التكرارات",
            onPressed: () => _cleanDuplicates(context, box, filterDept),
          ),
        ],
      ),
      body: Column(
        children: [
          ActiveAbsencesDashboard(workerBox: box, filterDepartment: filterDept),
          Expanded(child: WorkerList(box: box, filterDepartment: filterDept)),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<Box<Worker>>(
        valueListenable: box.listenable(),
        builder: (context, _, __) {
          if (!PermissionHelper.canAdd) return const SizedBox.shrink();
          return FloatingActionButton(
            heroTag: "workers_fab",
            onPressed: () => WorkerForm.show(context, box: box, defaultDepartment: filterDept),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  void _cleanDuplicates(BuildContext context, Box<Worker> box, String? filterDept) async {
    final Map<String, Worker> uniqueWorkers = {};
    final List<dynamic> keysToDelete = [];

    // تحديد العمال الفريدين (الاسم + الهاتف)
    for (int i = 0; i < box.length; i++) {
      final worker = box.getAt(i);
      if (worker == null) continue;
      if (filterDept != null && worker.department != filterDept) continue;

      final identifier = "${worker.name.trim()}_${worker.phone.trim()}";

      if (uniqueWorkers.containsKey(identifier)) {
        // إذا وجدنا تكراراً، نضيف مفتاحه للحذف
        keysToDelete.add(box.keyAt(i));
      } else {
        uniqueWorkers[identifier] = worker;
      }
    }

    if (keysToDelete.isEmpty) {
      if (context.mounted) {
        UIUtils.showInfoSnackBar(
          message: "✅ لا يوجد تكرارات لحذفها",
          backgroundColor: Colors.green,
          icon: Icons.check_circle,
        );
      }
      return;
    }

    // تأكيد الحذف
    if (context.mounted) {
      UIUtils.showDeleteConfirmation(
        context: context,
        title: "حذف التكرارات",
        content: "تم العثور على ${keysToDelete.length} سجل مكرر. هل تريد حذفهم؟",
        confirmLabel: "حذف الكل",
        onConfirm: () async {
          for (final key in keysToDelete) {
            await box.delete(key);
          }
          if (context.mounted) {
            UIUtils.showInfoSnackBar(
              message: "✅ تم حذف التكرارات بنجاح",
              backgroundColor: Colors.blue,
              icon: Icons.cleaning_services,
            );
          }
        },
      );
    }
  }
}
