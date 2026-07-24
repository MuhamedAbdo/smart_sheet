import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

class WorkerUtils {
  /// جلب قائمة العمال مرتبة بحسب:
  /// 1- القسم الحالي (يظهر أولاً)
  /// 2- الدور (مشرف، رئيس قسم، فني، مساعد، عامل)
  /// 3- باقي الأقسام مرتبة أيضاً بحسب الدور
  static List<Worker> getSortedWorkers(String currentDepartment) {
    if (!Hive.isBoxOpen('workers')) return [];

    final box = Hive.box<Worker>('workers');
    final workers = box.values.toList();

    // خريطة ترتيب الأدوار (الرقم الأقل = أولوية أعلى)
    final rolePriority = {
      'مشرف': 1,
      'رئيس قسم': 2,
      'فني': 3,
      'مساعد': 4,
      'عامل': 5,
    };

    int getRolePriority(String jobTitle) {
      final title = jobTitle.trim().toLowerCase();
      if (title.contains('مشرف')) return rolePriority['مشرف']!;
      if (title.contains('رئيس')) return rolePriority['رئيس قسم']!;
      if (title.contains('فني')) return rolePriority['فني']!;
      if (title.contains('مساعد')) return rolePriority['مساعد']!;
      if (title.contains('عامل')) return rolePriority['عامل']!;
      return 99; // أدوار أخرى
    }

    // توحيد اسم القسم لمطابقة ما هو مسجل في بيانات العمال
    String normalizedDept = currentDepartment;
    if (normalizedDept == 'crushing') normalizedDept = 'die_cutting';
    if (normalizedDept == 'staple') normalizedDept = 'staples';

    workers.sort((a, b) {
      // 1. أولوية القسم الحالي
      final aIsCurrentDept = (a.department == normalizedDept);
      final bIsCurrentDept = (b.department == normalizedDept);

      if (aIsCurrentDept && !bIsCurrentDept) return -1;
      if (!aIsCurrentDept && bIsCurrentDept) return 1;

      // 2. إذا تساووا في القسم (كلاهما في القسم الحالي، أو كلاهما في أقسام أخرى) -> نرتب حسب الدور
      final aRolePrio = getRolePriority(a.job);
      final bRolePrio = getRolePriority(b.job);

      if (aRolePrio != bRolePrio) {
        return aRolePrio.compareTo(bRolePrio);
      }

      // 3. إذا تساووا في الدور، الترتيب أبجدياً (اختياري)
      return a.name.compareTo(b.name);
    });

    return workers;
  }
}
