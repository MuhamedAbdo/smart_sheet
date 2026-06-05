import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/worker_card.dart';
import 'package:smart_sheet/screens/worker_details_screen.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/utils/permission_helper.dart';

class WorkerList extends StatelessWidget {
  final Box<Worker> box; // ✅ إضافة الحقل
  final String? filterDepartment; // ✅ تصفية حية حسب القسم

  const WorkerList({super.key, required this.box, this.filterDepartment}); // ✅ تعديل المُنشئ

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Worker>>(
      valueListenable: box.listenable(),
      builder: (context, Box<Worker> box, _) {
        final allWorkers = box.values.toList();
        final filteredWorkers = filterDepartment == null
            ? allWorkers
            : allWorkers.where((w) => w.department == filterDepartment).toList();

        if (filteredWorkers.isEmpty) {
          return const Center(child: Text("🚫 لا يوجد عمال في هذا القسم بعد"));
        }

        // ✅ نفحص الصلاحيات هنا — الـ ValueListenableBuilder سيعيد البناء تلقائياً عند تغيير الـ box
        final canEdit = PermissionHelper.canEdit;
        final canDelete = PermissionHelper.canDelete;

        return ListView.builder(
          itemCount: filteredWorkers.length,
          itemBuilder: (context, index) {
            final worker = filteredWorkers[index];
            return WorkerCard(
              worker: worker,
              onEdit: canEdit
                  ? () => WorkerForm.show(
                        context,
                        existingWorker: worker,
                        box: box,
                        defaultDepartment: filterDepartment,
                      )
                  : null,
              onDelete: canDelete
                  ? () {
                      final hiveKey = worker.key;
                      final syncId = worker.syncId ?? hiveKey.toString();
                      UIUtils.showDeleteConfirmation(
                        context: context,
                        title: "حذف العامل",
                        content: "هل أنت متأكد من حذف العامل \"${worker.name}\"؟",
                        onConfirm: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final workerJson = worker.toJson();
                          if (hiveKey != null) {
                            await box.delete(hiveKey);
                          }
                          SyncService.instance.pushToQueue(
                            'workers',
                            {'sync_id': syncId, 'id': syncId},
                            operation: 'delete',
                          );
                          debugPrint('🗑️ [WorkerList] تم إرسال طلب حذف [sync_id=$syncId] إلى Queue');
                          if (!context.mounted) return;
                          messenger.clearSnackBars();
                          UIUtils.showUndoSnackBar(
                            context: context,
                            message: "تم حذف العامل",
                            onUndo: () async {
                              messenger.clearSnackBars();
                              if (hiveKey != null) {
                                await box.put(hiveKey, worker);
                              }
                              SyncService.instance.pushToQueue('workers', workerJson);
                              debugPrint('↩️ [WorkerList] إلغاء الحذف — تم إعادة sync_id=$syncId');
                            },
                          );
                        },
                      );
                    }
                  : null,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerDetailsScreen(worker: worker, box: box),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
