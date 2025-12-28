import 'dart:io';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // ضروري للتعامل مع MethodChannel
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyBackupTaskHandler());
}

class MyBackupTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  void onRepeatEvent(DateTime timestamp) {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BackupService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String BUCKET_NAME = 'backups';
  static const String _backupFileName = 'smart_sheet_backup.zip';

  // قناة الاتصال مع كود الاندرويد (Kotlin) لإعادة التشغيل
  static const _platform = MethodChannel('com.smart_sheet/app_control');

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  // --- 1. النسخ الاحتياطي المحلي ---
  Future<String?> createBackup() async {
    try {
      final localPath = await _createLocalBackupFile();
      if (localPath == null) return '❌ فشل إنشاء الملف المؤقت';
      final file = File(localPath);
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName:
            'smart_sheet_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (outputFile != null) {
        await file.copy(outputFile);
        await file.delete();
        return '✅ تم حفظ النسخة الاحتياطية بنجاح';
      }
      return null;
    } catch (e) {
      return '❌ فشل الحفظ المحلي: $e';
    }
  }

  // --- 2. الاستعادة المحلية ---
  Future<String?> restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result != null && result.files.single.path != null) {
        final res = await _restoreFromZipPath(result.files.single.path!);
        if (res == 'SUCCESS_RESTORE') {
          await _restartApp(); // تنفيذ إعادة التشغيل عند النجاح
        }
        return res;
      }
      return null;
    } catch (e) {
      return '❌ فشل الاستعادة المحلية: $e';
    }
  }

  // --- 3. الرفع السحابي ---
  Future<String?> uploadToSupabase() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';
      await _requestPermissions();
      _initService();
      await _startService();

      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null) {
        await _stopService();
        return '❌ فشل إنشاء ملف النسخة المحلية.';
      }

      final backupFile = File(localBackupPath);
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        await _stopService();
        return '❌ يجب تسجيل الدخول للرفع السحابي.';
      }

      final uniqueFileName =
          '${DateTime.now().toIso8601String().replaceAll(':', '-')}_$_backupFileName';
      final uploadPath = 'manual_backups/${user.id}/$uniqueFileName';

      _updateForegroundNotification(
        title: 'جاري الرفع...',
        content: 'يتم الآن نقل النسخة الاحتياطية إلى السحابة',
      );

      await _supabaseClient.storage.from(BUCKET_NAME).upload(
            uploadPath,
            backupFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      if (await backupFile.exists()) await backupFile.delete();
      await _stopService();
      await _showNotification(
          id: 1, title: 'النسخ السحابي', body: '✅ اكتمل الرفع بنجاح.');
      return '✅ تم الرفع بنجاح.';
    } catch (e) {
      await _stopService();
      return '❌ فشل الرفع: ${e.toString()}';
    }
  }

  // --- 4. الاستعادة من السحاب ---
  Future<String?> downloadAndRestore(String fullPath) async {
    try {
      _initService();
      await _startService();
      _updateForegroundNotification(
          title: 'جاري الاستعادة', content: 'يتم الآن التحميل...');
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');

      final Uint8List bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(fullPath);
      await File(tempZipPath).writeAsBytes(bytes);

      final result = await _restoreFromZipPath(tempZipPath);

      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
      await _stopService();

      if (result == 'SUCCESS_RESTORE') {
        await _restartApp(); // تنفيذ إعادة التشغيل عند النجاح
      }
      return result;
    } catch (e) {
      await _stopService();
      return '❌ فشل الاستعادة: $e';
    }
  }

  // --- وظائف المساعدة ---

  Future<void> _restartApp() async {
    try {
      // مهلة بسيطة لضمان كتابة الملفات وإغلاق قواعد البيانات
      await Future.delayed(const Duration(milliseconds: 500));
      await _platform.invokeMethod('restartApp');
    } catch (e) {
      debugPrint("Restart failed: $e");
    }
  }

  Future<List<FileObject>> listBackups() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return [];
      return await _supabaseClient.storage
          .from(BUCKET_NAME)
          .list(path: 'manual_backups/${user.id}');
    } catch (e) {
      return [];
    }
  }

  Future<String?> _restoreFromZipPath(String zipPath) async {
    try {
      await Hive.close();
      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);
      if (appDirInstance.existsSync()) {
        final entities = appDirInstance.listSync();
        for (var entity in entities) {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {}
        }
      }
      await compute(_restoreBackupInternal, [zipPath, appDir.path]);
      return 'SUCCESS_RESTORE';
    } catch (e) {
      return '❌ فشل فك الضغط: $e';
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'backup_service',
        channelName: 'Smart Sheet Backup',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        allowWakeLock: true,
        allowWifiLock: true,
        eventAction: ForegroundTaskEventAction.nothing(),
      ),
    );
  }

  Future<void> _startService() async {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'بدء العملية',
      notificationText: 'يرجى الانتظار...',
      callback: startCallback,
    );
  }

  Future<void> _stopService() async =>
      await FlutterForegroundTask.stopService();

  void _updateForegroundNotification(
      {required String title, required String content}) {
    FlutterForegroundTask.updateService(
        notificationTitle: title, notificationText: content);
  }

  Future<void> _showNotification(
      {required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('backup_channel', 'النسخ الاحتياطي',
            importance: Importance.max, priority: Priority.high);
    await _notificationsPlugin.show(
        id, title, body, const NotificationDetails(android: androidDetails));
  }

  Future<String?> _createLocalBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, 'temp_backup.zip');
    if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
    await compute(_createBackupInternal, [appDir.path, tempZipPath]);
    return tempZipPath;
  }

  @pragma('vm:entry-point')
  static void _createBackupInternal(List<String> args) {
    final encoder = ZipFileEncoder();
    encoder.create(args[1]);
    final appDir = Directory(args[0]);
    for (final entity in appDir.listSync(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: args[0]);
        encoder.addFile(entity, relativePath.replaceAll('\\', '/'));
      }
    }
    encoder.close();
  }

  @pragma('vm:entry-point')
  static void _restoreBackupInternal(List<String> args) {
    final bytes = File(args[0]).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final outputPath = p.join(args[1], file.name);
      if (file.isFile) {
        File(outputPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outputPath).createSync(recursive: true);
      }
    }
  }
}
