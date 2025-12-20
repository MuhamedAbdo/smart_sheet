import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';

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
    // نستخدم FutureBuilder للتأكد من فتح الصندوق قبل عرض الواجهة
    return FutureBuilder<Box<Worker>>(
      future: Hive.openBox<Worker>(
          departmentBoxName), // يفتحه إذا كان مغلقاً أو يعيده إذا كان مفتوحاً
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body:
                Center(child: Text("خطأ في تحميل البيانات: ${snapshot.error}")),
          );
        }

        final Box<Worker> box = snapshot.data!;

        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Text("👷‍♂️ $departmentTitle - العمال"),
            centerTitle: true,
          ),
          body: WorkerList(box: box),
          floatingActionButton: FloatingActionButton(
            onPressed: () => WorkerForm.show(context, box: box),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
