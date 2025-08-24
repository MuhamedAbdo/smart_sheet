import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smart_sheet/models/ink_report.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  Future<void> _backupData(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentSession?.user;
      if (user == null) throw Exception('لم يتم تسجيل الدخول');

      final backupData = <String, dynamic>{};

      // 1. الصناديق العادية (Map<String, dynamic>)
      for (final boxName in [
        'settings',
        'savedSheetSizes',
        'maintenanceRecords',
        'storeEntries'
      ]) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          backupData[boxName] = Map.from(box.toMap());
        }
      }

      // 2. صندوق التقارير (Box<InkReport>)
      if (Hive.isBoxOpen('inkReports')) {
        final box = Hive.box('inkReports'); // 👈 بدون <InkReport>
        backupData['inkReports'] = box.toMap().map((key, value) {
          if (value is InkReport) {
            return MapEntry(key.toString(), value.toJson());
          } else if (value is Map) {
            return MapEntry(
              key.toString(),
              InkReport.fromJson(Map<String, dynamic>.from(value)).toJson(),
            );
          } else {
            throw Exception("قيمة غير متوقعة في inkReports: $value");
          }
        });
      }

      // 3. صندوق العمال (Box<Worker>)
      if (Hive.isBoxOpen('workers')) {
        final box = Hive.box<Worker>('workers');
        backupData['workers'] = box.toMap().map((key, value) => MapEntry(
              key.toString(),
              (value as Worker).toJson(),
            ));
      }

      // 4. صندوق الإجراءات (Box<WorkerAction>)
      if (Hive.isBoxOpen('worker_actions')) {
        final box = Hive.box<WorkerAction>('worker_actions');
        backupData['worker_actions'] = box.toMap().map((key, value) => MapEntry(
              key.toString(),
              (value as WorkerAction).toJson(),
            ));
      }

      // ✅ تحويل إلى JSON للتأكد
      final jsonData = json.encode(backupData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));

      // ✅ رفع على Supabase
      final fileName = 'backup_${DateTime.now().toIso8601String()}.json';
      await Supabase.instance.client.storage.from('backups').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/json'),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم رفع النسخة الاحتياطية بنجاح')),
      );
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في النسخ: ${e.toString()}')),
      );
    }
  }

  Future<void> _restoreData(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentSession?.user;
      if (user == null) throw Exception('لم يتم تسجيل الدخول');

      final files =
          await Supabase.instance.client.storage.from('backups').list();
      if (files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ لا يوجد نسخ احتياطية')),
        );
        return;
      }

      // رتب الملفات من الأحدث للأقدم
      files.sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
      final latestFile = files.first;

      // نزّل الملف
      final downloadedData = await Supabase.instance.client.storage
          .from('backups')
          .download(latestFile.name);

      // حوّل إلى نص
      final String jsonString = String.fromCharCodes(downloadedData);
      final backupData = json.decode(jsonString) as Map<String, dynamic>;

      // استعد كل صندوق حسب نوعه

      // الصناديق العادية
      for (final boxName in [
        'settings',
        'savedSheetSizes',
        'maintenanceRecords',
        'storeEntries'
      ]) {
        if (Hive.isBoxOpen(boxName) && backupData.containsKey(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          final data = backupData[boxName] as Map<dynamic, dynamic>;
          data.forEach((key, value) {
            box.put(key, value);
          });
        }
      }

      // صندوق InkReports
      if (Hive.isBoxOpen('inkReports') &&
          backupData.containsKey('inkReports')) {
        final box = Hive.box('inkReports'); // 👈 بدون <InkReport>
        await box.clear();
        final data = backupData['inkReports'] as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is InkReport) {
            box.put(key, value);
          } else if (value is Map) {
            box.put(key, InkReport.fromJson(Map<String, dynamic>.from(value)));
          }
        });
      }

      // صندوق العمال
      if (Hive.isBoxOpen('workers') && backupData.containsKey('workers')) {
        final box = Hive.box<Worker>('workers');
        await box.clear();
        final data = backupData['workers'] as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          box.put(key, Worker.fromJson(Map<String, dynamic>.from(value)));
        });
      }

      // صندوق الإجراءات
      if (Hive.isBoxOpen('worker_actions') &&
          backupData.containsKey('worker_actions')) {
        final box = Hive.box<WorkerAction>('worker_actions');
        await box.clear();
        final data = backupData['worker_actions'] as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          box.put(key, WorkerAction.fromJson(Map<String, dynamic>.from(value)));
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم استعادة النسخة من: ${latestFile.name}')),
      );
    } on Exception catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في الاستعادة: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('النسخ الاحتياطي والاستعادة'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('رفع نسخة احتياطية'),
                subtitle: const Text('احفظ كل بياناتك على السحابة'),
                trailing: const Icon(Icons.upload, color: Colors.green),
                onTap: () => _backupData(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('استعادة نسخة احتياطية'),
                subtitle: const Text('استعد بياناتك من السحابة'),
                trailing: const Icon(Icons.download, color: Colors.blue),
                onTap: () => _restoreData(context),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ملاحظة: يتم ربط النسخ بحسابك. تأكد من تسجيل الدخول.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
