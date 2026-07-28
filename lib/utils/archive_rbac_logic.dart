// Archive RBAC Logic (Role-Based Access Control)
// 
// هذا الملف مخصص كمرجع لقواعد الصلاحيات الخاصة بالأرشيف (Archive) عند بناء شاشات 
// وعمليات الأرشيف (إضافة/تعديل/حذف/قراءة).
// 
// ── القاعدة الأولى: صلاحية القراءة (Global Scope) ──
// - المتغير: `canReadArchive`
// - الوصف: صلاحية عامة على مستوى المصنع.
// - الشرط: إذا كانت `canReadArchive == true`، يُسمح للمستخدم برؤية وتصفح **جميع السجلات**
//   في الأرشيف لجميع الأقسام، بغض النظر عن قسم المستخدم.
// - ملاحظة: تُستخدم هذه الصلاحية لمديري الإنتاج ومديري الجودة الذين يحتاجون للاطلاع 
//   على تاريخ الإنتاج دون صلاحية التعديل.
// 
// ── القاعدة الثانية: صلاحيات الإضافة، الاستعادة، والحذف (Department-Scoped) ──
// - المتغيرات: `canAddArchive`, `canRestoreArchive`, `canDeleteArchive`
// - الوصف: صلاحيات مقيدة بالقسم الخاص بالعامل.
// - الشرط: العامل لا يُسمح له بإضافة، أو استعادة، أو حذف أي سجل أرشيفي إلا إذا تحقق الشرطان معاً:
//   1. لديه الصلاحية المحددة (مثلاً `canRestoreArchive == true`).
//   2. السجل الأرشيفي ينتمي لنفس القسم الذي يعمل فيه العامل (`record.department == currentUser.department`).
// - مثال تطبيقي:
//   إذا كان العامل ينتمي لقسم "الفلكسو" ولديه صلاحية `canRestoreArchive`، سيظهر له زر الاستعادة
//   فقط على سجلات الفلكسو. السجلات الأخرى سيستطيع قراءتها فقط (إذا كان يملك `canReadArchive`)
//   ولكن لن يظهر زر الاستعادة.
// 
// ── القاعدة الثالثة: الأقسام التي ليس لها أرشيف مباشر ──
// - الوصف: بعض الأقسام (مثل قسم مراقبة الجودة أو الإدارة) ليس لها سجلات إنتاج أرشيفية.
// - التطبيق: يمكن للأدمن منحهم `canReadArchive = true`، ولكن منحهم صلاحيات الاستعادة/الإضافة 
//   لن يكون له تأثير فعلي في الواجهة، لأن شرط التطابق (`record.department == currentUser.department`) 
//   لن يتحقق، وبالتالي لن تظهر لهم أزرار التحكم نهائياً.
// 

import '../models/worker_model.dart';

class ArchiveRbacService {
  
  /// التحقق مما إذا كان العامل يملك صلاحية القراءة العامة للأرشيف
  static bool canRead(Worker? worker) {
    return worker?.canReadArchive ?? false;
  }

  /// التحقق مما إذا كان العامل يملك صلاحية إضافة سجل جديد للقسم الخاص به
  static bool canAdd(Worker? worker, String targetDepartment) {
    if (worker == null) return false;
    return worker.canAddArchive && (worker.department == targetDepartment);
  }

  /// التحقق مما إذا كان العامل يملك صلاحية استعادة سجل أرشيفي في القسم الخاص به
  static bool canRestore(Worker? worker, String targetDepartment) {
    if (worker == null) return false;
    return worker.canRestoreArchive && (worker.department == targetDepartment);
  }

  /// التحقق مما إذا كان العامل يملك صلاحية حذف سجل أرشيفي في القسم الخاص به
  static bool canDelete(Worker? worker, String targetDepartment) {
    if (worker == null) return false;
    return worker.canDeleteArchive && (worker.department == targetDepartment);
  }
}
