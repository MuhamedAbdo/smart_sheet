// lib/src/services/backup_service.dart

import 'dart:io';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- رفع النسخة للسحاب ---
  Future<String?> uploadToSupabase() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      await _requestPermissions();
      _initService();
      await _startService();

      final localBackupPath = await _createLocalBackupFile().timeout(
          const Duration(seconds: 120),
          onTimeout: () =>
              throw TimeoutException('عملية الضغط استغرقت وقتاً طويلاً'));

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

      await _supabaseClient.storage
          .from(BUCKET_NAME)
          .upload(
            uploadPath,
            backupFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          )
          .timeout(const Duration(minutes: 20));

      if (await backupFile.exists()) await backupFile.delete();

      await _stopService();
      await _showNotification(
          id: 1,
          title: 'النسخ السحابي',
          body: '✅ اكتمل رفع النسخة الاحتياطية بنجاح.');

      return '✅ تم الرفع بنجاح.';
    } catch (e) {
      await _stopService();
      await _showNotification(
          id: 2,
          title: 'النسخ السحابي',
          body: '❌ فشل الرفع: تحقق من استقرار الإنترنت.');
      return '❌ فشل الرفع: ${e.toString()}';
    }
  }

  // --- جلب قائمة النسخ المتاحة ---
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

  // --- تحميل واستعادة من السحاب ---
  Future<String?> downloadAndRestore(String fullPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');

      final Uint8List bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(fullPath);

      await File(tempZipPath).writeAsBytes(bytes);

      // تنفيذ الاستعادة
      final result = await _restoreFromZipPath(tempZipPath);

      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
      return result;
    } catch (e) {
      return '❌ فشل الاستعادة: $e';
    }
  }

  // --- إنشاء نسخة محلياً وحفظها في ملف ---
  Future<String?> createBackup() async {
    try {
      final localPath = await _createLocalBackupFile();
      if (localPath == null) return '❌ فشل إنشاء الملف';
      final bytes = await File(localPath).readAsBytes();
      final String? saved = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (await File(localPath).exists()) await File(localPath).delete();
      return saved != null ? '✅ تم حفظ النسخة بنجاح' : null;
    } catch (e) {
      return '❌ خطأ محلي: $e';
    }
  }

  // --- استعادة من ملف محلي ---
  Future<String?> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result?.files.single.path == null) return null;
      return await _restoreFromZipPath(result!.files.single.path!);
    } catch (e) {
      return '❌ فشل اختيار الملف: $e';
    }
  }

  // --- المنطق الجوهري للاستعادة (تم تعديله) ---
  Future<String?> _restoreFromZipPath(String zipPath) async {
    try {
      // 1. إغلاق Hive تماماً لتحرير الملفات من الذاكرة (هام جداً للمحاكي)
      await Hive.close();

      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);

      // 2. مسح ملفات قاعدة البيانات الحالية لفتح المجال للجديدة
      if (appDirInstance.existsSync()) {
        final entities = appDirInstance.listSync();
        for (var entity in entities) {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            debugPrint("تعذر حذف ملف: ${entity.path}");
          }
        }
      }

      // 3. فك الضغط في مجلد التطبيق
      await compute(_restoreBackupInternal, [zipPath, appDir.path]);

      // نرجع رمز النجاح لكي تقوم الواجهة بعمل إغلاق للتطبيق أو إعادة تشغيل
      return 'SUCCESS_RESTORE';
    } catch (e) {
      return '❌ فشل فك الضغط: $e';
    }
  }

  // --- الدوال المساعدة والخدمات الخلفية ---
  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'backup_service',
        channelName: 'Smart Sheet Backup',
        channelDescription: 'تأمين عملية رفع البيانات في الخلفية',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  Future<void> _startService() async {
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'جاري النسخ الاحتياطي',
      notificationText: 'يرجى عدم إغلاق التطبيق حتى ينتهي الرفع...',
      callback: startCallback,
    );
  }

  Future<void> _stopService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> _showNotification(
      {required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails('backup_channel', 'النسخ الاحتياطي',
            importance: Importance.max, priority: Priority.high);
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(id, title, body, platformDetails);
  }

  Future<String?> _createLocalBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, 'temp_backup.zip');
    if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
    await compute(_createBackupInternal, [appDir.path, tempZipPath]);
    return tempZipPath;
  }

  // --- العمليات في الخلفية (Isolates) ---
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
