import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/active_absences_dashboard.dart';

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
    return FutureBuilder<Box<Worker>>(
      // الفحص يمنع حدوث "Already open with different type"
      future: Hive.isBoxOpen(departmentBoxName)
          ? Future.value(Hive.box<Worker>(departmentBoxName))
          : Hive.openBox<Worker>(departmentBoxName),
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

        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: Text("👷‍♂️ $departmentTitle - العمال"),
            centerTitle: true,
          ),
          body: Column(
            children: [
              ActiveAbsencesDashboard(workerBox: box),
              Expanded(child: WorkerList(box: box)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: "workers_fab",
            onPressed: () => WorkerForm.show(context, box: box),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
