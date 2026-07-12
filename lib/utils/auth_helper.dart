// lib/utils/auth_helper.dart
//
// نظام التحقق المركزي من الصلاحيات (Enterprise Department-Scoped RBAC)
// يعتمد على: الصلاحية الأساسية + القسم + الوظيفة
//
// الاستخدام:
//   bool ok = AuthHelper.canManageProduction(currentUser, 'flexo', 'canAdd');
//   bool ok = AuthHelper.canManageWorkers(currentUser, 'flexo', 'canEditWorker');

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

/// الأقسام التي لها صلاحيات إنتاجية (تشغيل + تقارير)
/// أي قسم خارج هذه القائمة يُعامَل على أنه "قسم غير معني بالإنتاج"
const Set<String> _productionRelatedDepartments = {
  'flexo',
  'production_line',
  'die_cutting',
  'staples',
  'general_mgmt',
  'technical_support',
  'quality_control',
  'maintenance',
};

class AuthHelper {
  // ─────────────────────────────────────────────────────────────────────────
  //  جلب العامل الحالي تلقائياً من Hive (نفس آلية PermissionHelper)
  // ─────────────────────────────────────────────────────────────────────────

  /// البريد الإلكتروني للمستخدم المسجل حالياً
  static String? get _currentEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  /// البريد الإلكتروني للسوبر أدمن — يملك كل الصلاحيات دائماً
  static const String _superAdminEmail = 'mohamedabdo9999933@gmail.com';

  /// هل المستخدم الحالي هو السوبر أدمن؟
  static bool get isSuperAdmin =>
      _currentEmail?.toLowerCase().trim() ==
      _superAdminEmail.toLowerCase().trim();

  /// سجل Worker المقابل للمستخدم الحالي (null إذا لم يُسجّل دخول أو لم يُعثر عليه)
  static Worker? get currentWorker {
    final email = _currentEmail;
    if (email == null || email.isEmpty) return null;
    if (!Hive.isBoxOpen('workers')) return null;
    final box = Hive.box<Worker>('workers');
    try {
      return box.values.firstWhere(
        (w) => w.email?.trim().toLowerCase() == email.trim().toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  دوال مريحة للاستخدام المباشر من الـ UI (تجلب currentUser تلقائياً)
  // ─────────────────────────────────────────────────────────────────────────

  /// فحص صلاحية الإنتاج للمستخدم الحالي على قسم معين.
  /// السوبر أدمن يملك الصلاحية دائماً.
  /// إذا لم يُعثر على سجل العامل → false.
  static bool currentUserCanManageProduction(
    String targetDepartment,
    String action,
  ) {
    if (isSuperAdmin) return true;
    final user = currentWorker;
    if (user == null) return false;
    return canManageProduction(user, targetDepartment, action);
  }

  /// فحص صلاحية إدارة العمال للمستخدم الحالي على قسم مستهدف.
  /// السوبر أدمن يملك الصلاحية دائماً.
  /// إذا لم يُعثر على سجل العامل → false.
  static bool currentUserCanManageWorkers(
    String targetWorkerDepartment,
    String action,
  ) {
    if (isSuperAdmin) return true;
    final user = currentWorker;
    if (user == null) return false;
    return canManageWorkers(user, targetWorkerDepartment, action);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  صلاحيات إدارة الإنتاج والتقارير
  // ─────────────────────────────────────────────────────────────────────────

  /// يتحقق من صلاحية [currentUser] لإدارة تقارير/إنتاج قسم [targetDepartment].
  ///
  /// المعاملات:
  /// - [currentUser]      : بيانات المستخدم الحالي من Hive
  /// - [targetDepartment] : كود القسم المستهدف (مثل 'flexo', 'production_line')
  /// - [action]           : الإجراء المطلوب: 'canAdd' | 'canEdit' | 'canDelete'
  ///
  /// القواعد (بالترتيب):
  ///   1. المدير الشامل: department == 'general_mgmt' && job == 'مدير الإنتاج'
  ///      → يُقيّم الصلاحية الأساسية على أي قسم
  ///   2. القسم غير المعني بالإنتاج → false دائماً
  ///   3. المشرف المحلي: currentUser.department == targetDepartment && يمتلك الصلاحية
  ///      → true فقط على قسمه
  static bool canManageProduction(
    Worker currentUser,
    String targetDepartment,
    String action,
  ) {
    final bool basePermission = _getProductionPermission(currentUser, action);

    // القاعدة 1: المدير الشامل (مدير الإنتاج في الإدارة العامة)
    if (currentUser.department == 'general_mgmt' &&
        currentUser.job == 'مدير الإنتاج') {
      // يملك الصلاحية على كل الأقسام إذا كانت الصلاحية الأساسية مفعّلة
      return basePermission;
    }

    // القاعدة 2: الأقسام غير المعنية بالإنتاج → false دائماً
    if (!_productionRelatedDepartments.contains(currentUser.department)) {
      return false;
    }

    // القاعدة 3: المشرف/رئيس القسم المحلي — قسمه فقط
    if (currentUser.department == targetDepartment) {
      return basePermission;
    }

    // قسم مختلف ولم تنطبق أي قاعدة شاملة → false
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  صلاحيات إدارة بيانات العمال (شؤون العاملين)
  // ─────────────────────────────────────────────────────────────────────────

  /// يتحقق من صلاحية [currentUser] لإدارة عامل ينتمي إلى [targetWorkerDepartment].
  ///
  /// المعاملات:
  /// - [currentUser]             : بيانات المستخدم الحالي من Hive
  /// - [targetWorkerDepartment]  : كود القسم الذي ينتمي إليه العامل المستهدف
  /// - [action]                  : الإجراء: 'canAddWorker' | 'canEditWorker' | 'canDeleteWorker'
  ///
  /// القواعد (بالترتيب):
  ///   0. التحقق من الصلاحية الأساسية (canAddWorker / canEditWorker / canDeleteWorker)
  ///      إذا لم يمتلكها → false فوراً
  ///   1. الاستثناء الشامل: قسم الموارد البشرية (hr)
  ///      → يحق له إدارة عمال كل الأقسام
  ///   2. الإدارة المحلية: currentUser.department == targetWorkerDepartment
  ///      → true فقط على قسمه
  static bool canManageWorkers(
    Worker currentUser,
    String targetWorkerDepartment,
    String action,
  ) {
    // التحقق الأساسي: هل يمتلك الصلاحية أصلاً؟
    final bool basePermission = _getWorkerPermission(currentUser, action);
    if (!basePermission) return false;

    // القاعدة 1: قسم الموارد البشرية → صلاحية شاملة على كل المصنع
    if (currentUser.department == 'hr') {
      return true;
    }

    // القاعدة 2: الإدارة المحلية — قسمه فقط
    if (currentUser.department == targetWorkerDepartment) {
      return true;
    }

    // قسم مختلف ولا يعمل في HR → false
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  دوال مساعدة خاصة
  // ─────────────────────────────────────────────────────────────────────────

  /// يُرجع قيمة صلاحية الإنتاج المطلوبة من Worker
  static bool _getProductionPermission(Worker user, String action) {
    switch (action) {
      case 'canAdd':
        return user.canAdd;
      case 'canEdit':
        return user.canEdit;
      case 'canDelete':
        return user.canDelete;
      default:
        return false;
    }
  }

  /// يُرجع قيمة صلاحية شؤون العاملين المطلوبة من Worker
  static bool _getWorkerPermission(Worker user, String action) {
    switch (action) {
      case 'canAddWorker':
        return user.canAddWorker;
      case 'canEditWorker':
        return user.canEditWorker;
      case 'canDeleteWorker':
        return user.canDeleteWorker;
      default:
        return false;
    }
  }
}
