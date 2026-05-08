import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/worker_form.dart';
import 'package:smart_sheet/widgets/worker_list.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/active_absences_dashboard.dart';

class WorkersScreen extends StatefulWidget {
  final String departmentBoxName;
  final String departmentTitle;

  const WorkersScreen({
    super.key,
    required this.departmentBoxName,
    required this.departmentTitle,
  });

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  Box<Worker>? _box;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _openBox();
  }

  Future<void> _openBox() async {
    try {
      final box = Hive.isBoxOpen(widget.departmentBoxName)
          ? Hive.box<Worker>(widget.departmentBoxName)
          : await Hive.openBox<Worker>(widget.departmentBoxName);
      if (mounted) {
        setState(() {
          _box = box;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _box == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.departmentTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "❌ خطأ: ${_errorMessage ?? 'فشل فتح الصندوق.'}\nيرجى إعادة تشغيل التطبيق.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    // ✅ ValueListenableBuilder يراقب الـ Box مباشرةً
    // فور وصول أي تغيير من SyncService (مثل 'محمود السيد') تُعاد بناء الشاشة تلقائياً
    return ValueListenableBuilder<Box<Worker>>(
      valueListenable: _box!.listenable(),
      builder: (context, box, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text("👷‍♂️ ${widget.departmentTitle} - العمال (${box.length})"),
            centerTitle: true,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
          ),
          body: Column(
            children: [
              ActiveAbsencesDashboard(workerBox: box),
              Expanded(child: WorkerList(box: box)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => WorkerForm.show(context, box: box),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
