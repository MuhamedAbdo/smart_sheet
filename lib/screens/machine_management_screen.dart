import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
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
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final box = Hive.box<FlexoMachine>('flexo_machines');
                box.add(FlexoMachine(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                ));
                Navigator.pop(context);
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
        await box.deleteAt(index);
      },
    );
  }
}
