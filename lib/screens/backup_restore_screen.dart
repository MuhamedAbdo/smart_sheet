// lib/src/screens/backup/backup_restore_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
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

      for (final boxName in [
        'settings',
        'savedSheetSizes',
        'inkReports',
        'maintenanceRecords',
        'storeEntries',
        'workers',
        'worker_actions'
      ]) {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);

          if (boxName == 'workers') {
            backupData[boxName] = box
                .toMap()
                .map((key, value) => MapEntry(key, (value as Worker).toJson()));
          } else if (boxName == 'worker_actions') {
            backupData[boxName] = box.toMap().map((key, value) =>
                MapEntry(key, (value as WorkerAction).toJson()));
          } else {
            backupData[boxName] = Map.from(box.toMap());
          }
        }
      }

      final jsonData = json.encode(backupData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonData));

      final fileName = 'backup_${DateTime.now().toIso8601String()}.json';
      await Supabase.instance.client.storage.from('backups').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'application/json'),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم رفع النسخة الاحتياطية بنجاح')),
      );
    } catch (e) {
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

      files.sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
      final latestFile = files.first;

      final downloadedData = await Supabase.instance.client.storage
          .from('backups')
          .download(latestFile.name);

      final String jsonString = String.fromCharCodes(downloadedData);
      final backupData = json.decode(jsonString) as Map<String, dynamic>;

      for (final entry in backupData.entries) {
        final boxName = entry.key;
        final data = entry.value as Map<dynamic, dynamic>;

        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();

          if (boxName == 'workers') {
            data.forEach((key, value) {
              box.put(key, Worker.fromJson(Map<String, dynamic>.from(value)));
            });
          } else if (boxName == 'worker_actions') {
            data.forEach((key, value) {
              box.put(
                  key, WorkerAction.fromJson(Map<String, dynamic>.from(value)));
            });
          } else {
            data.forEach((key, value) {
              box.put(key, value);
            });
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم استعادة النسخة من: ${latestFile.name}')),
      );
    } catch (e) {
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
