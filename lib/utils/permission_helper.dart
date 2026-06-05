// lib/utils/permission_helper.dart
//
// Helper مشترك لفحص صلاحيات المستخدم الحالي (canAdd / canEdit / canDelete)
// يعتمد على: Supabase auth لمعرفة الـ email، و Hive box<Worker> لجلب السجل المقابل.
//
// الاستخدام:
//   bool canAdd = PermissionHelper.canAdd;    // true أو false

import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

const String _superAdminEmail = 'mohamedabdo9999933@gmail.com';

class PermissionHelper {
  /// البريد الإلكتروني للسوبر أدمن — يملك كل الصلاحيات دائماً
  static const String superAdminEmail = _superAdminEmail;

  /// البريد الإلكتروني للمستخدم المسجل حالياً (null إذا لم يسجل دخول)
  static String? get currentEmail =>
      Supabase.instance.client.auth.currentUser?.email;

  /// هل المستخدم الحالي هو السوبر أدمن؟
  static bool get isSuperAdmin =>
      currentEmail?.toLowerCase().trim() ==
      _superAdminEmail.toLowerCase().trim();

  /// جلب سجل Worker المقابل للمستخدم الحالي من Hive (null إذا لم يوجد)
  static Worker? get currentWorker {
    final email = currentEmail;
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

  /// صلاحية الإضافة — true للسوبر أدمن أو للعامل الذي canAdd == true
  static bool get canAdd {
    if (isSuperAdmin) return true;
    return currentWorker?.canAdd == true;
  }

  /// صلاحية التعديل — true للسوبر أدمن أو للعامل الذي canEdit == true
  static bool get canEdit {
    if (isSuperAdmin) return true;
    return currentWorker?.canEdit == true;
  }

  /// صلاحية الحذف — true للسوبر أدمن أو للعامل الذي canDelete == true
  static bool get canDelete {
    if (isSuperAdmin) return true;
    return currentWorker?.canDelete == true;
  }
}
