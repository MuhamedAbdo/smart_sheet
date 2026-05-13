import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class MachineManagementScreen extends StatelessWidget {
  const MachineManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة ماكينات الفلكسو'),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<FlexoMachine>('flexo_machines').listenable(),
        builder: (context, Box<FlexoMachine> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('لا توجد ماكينات مسجلة حالياً'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: box.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final machine = box.getAt(index);
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.settings, color: Colors.white),
                  ),
                  title: Text(
                    machine?.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteMachine(context, box, index),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMachineDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddMachineDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ماكينة جديدة'),
        content: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'اسم الماكينة',
                    hintText: 'مثلاً: ماكينة 1، ماكينة 2...',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final box = Hive.box<FlexoMachine>('flexo_machines');

                // جلب factory_id من التخزين الآمن
                final factoryId = await SupabaseManager.getFactoryId();
                debugPrint('📤 [ماكينات] محاولة رفع ماكينة جديدة: "$name" | factory_id=${factoryId ?? "غير محدد"}');

                if (factoryId == null) {
                  debugPrint('❌ [ماكينات] فشل رفع الماكينة "‏$name"‏: factory_id غير موجود. تأكد من ربط الجهاز بالمصنع.');
                  if (context.mounted) Navigator.pop(context);
                  return;
                }

                // توليد sync_id فريد وثابت لضمان المزامنة
                final syncId = '${factoryId}_machine_${DateTime.now().millisecondsSinceEpoch}';

                final newMachine = FlexoMachine(
                  id: syncId,
                  name: name,
                );

                // حفظ محلياً بمفتاح ثابت
                await box.put(syncId, newMachine);
                debugPrint('✅ [ماكينات] تم حفظ محلياً: "$name" (sync_id=$syncId)');

                // رفع لـ Supabase عبر طابور المزامنة
                await SyncService.instance.pushToQueue(
                  'machines',
                  {
                    'sync_id': syncId,
                    'id': syncId,
                    'name': name,
                    'factory_id': factoryId,
                  },
                  operation: 'upsert',
                );
                debugPrint('📤 [ماكينات] تم إضافة الماكينة "‏$name"‏ لطابور المزامنة. سيتم رفعها لـ Supabase فوراً.');

                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteMachine(BuildContext context, Box<FlexoMachine> box, int index) {
    UIUtils.showDeleteConfirmation(
      context: context,
      title: 'حذف ماكينة',
      content: 'هل أنت متأكد من حذف هذه الماكينة؟',
      onConfirm: () async {
        final machine = box.getAt(index);
        final syncId = machine?.id;
        final machineName = machine?.name ?? '';

        debugPrint('🗑️ [ماكينات] محاولة حذف: "$machineName" (sync_id=$syncId)');
        await box.deleteAt(index);

        // حذف من Supabase عبر طابور المزامنة إذا كان عندنا sync_id
        if (syncId != null && syncId.isNotEmpty) {
          await SyncService.instance.pushToQueue(
            'machines',
            {'sync_id': syncId, 'id': syncId},
            operation: 'delete',
          );
          debugPrint('🗑️ [ماكينات] تم إضافة طلب الحذف لـ طابور المزامنة: "$machineName"');
        }
      },
    );
  }
}
