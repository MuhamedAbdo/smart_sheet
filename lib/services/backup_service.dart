import 'dart:io';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/utils/data_normalization_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

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
  static const String bucketName = 'backups';

  // قناة الاتصال لإعادة تشغيل التطبيق
  static const _platform = MethodChannel('com.smart_sheet/app_control');


  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  // --- 1. النسخ الاحتياطي المحلي (تم الإصلاح لضمان شمول الصور والملفات) ---
  Future<String?> createBackup() async {
    try {
      // إنشاء الملف المؤقت الذي سيحتوي على كل بيانات التطبيق
      final localPath = await _createLocalBackupFile();
      if (localPath == null) return '❌ فشل إنشاء الملف المؤقت';

      final file = File(localPath);

      // قراءة الملف كـ Bytes (ضروري جداً لأندرويد 11+)
      final Uint8List fileBytes = await file.readAsBytes();

      if (fileBytes.isEmpty) {
        return '❌ فشل: ملف النسخة الاحتياطية فارغ';
      }

      // اختيار مكان الحفظ وتمرير البايتات مباشرة
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName:
            'smart_sheet_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: fileBytes,
      );

      // تنظيف الملف المؤقت
      if (await file.exists()) {
        await file.delete();
      }

      if (outputFile != null) {
        return '✅ تم حفظ النسخة الاحتياطية بنجاح';
      }
      return null;
    } catch (e) {
      debugPrint("Local Backup Error: $e");
      return '❌ فشل الحفظ المحلي: $e';
    }
  }

  // --- 2. الاستعادة المحلية (تم الإصلاح لمنع FormatException) ---
  Future<String?> restoreBackup() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result != null && result.files.single.path != null) {
        final res = await _restoreFromZipPath(result.files.single.path!);
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

      // Session heartbeat - ensure session is still active
      User? user = _supabaseClient.auth.currentUser;
      if (user == null) {
        debugPrint("🔄 Session expired, attempting refresh...");
        // Attempt to refresh session
        await _supabaseClient.auth.refreshSession();
        user = _supabaseClient.auth.currentUser;
        if (user == null) {
          return '❌ جلسة منتهية، يرجى تسجيل الدخول مرة أخرى.';
        }
      }

      debugPrint("✅ User authenticated: ${user.id}");

      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        return '❌ خطأ: لم يتم العثور على معرّف المصنع (factory_id). الرجاء إعادة تسجيل الدخول.';
      }

      // Direct path: Just {factory_id}.zip in bucket (no folders)
      final uploadPath = "$factoryId.zip";
      debugPrint("📁 Upload path: $uploadPath");

      if (Platform.isAndroid) {
        await _requestPermissions();
        _initService();
        await _startService();
      }

      // تنظيف البيانات والتأكد من توافقها قبل أخذ النسخة المحلية (Sanitization Layer)
      await DataNormalizationHelper.normalizeUntypedBoxes();

      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null) {
        if (Platform.isAndroid) await _stopService();
        return '❌ فشل إنشاء ملف النسخ المحلية.';
      }

      final backupFile = File(localBackupPath);

      // Basic internet connection check using socket
      try {
        final socket = await Socket.connect('supabase.com', 443)
            .timeout(const Duration(seconds: 5));
        socket.destroy();
      } catch (e) {
        if (Platform.isAndroid) await _stopService();
        return '❌ لا يوجد اتصال بالإنترنت.';
      }

      // Simple direct upload with no complexity
      final bytes = await backupFile.readAsBytes();
      debugPrint("📊 File size: ${bytes.length} bytes");

      // Auth check: Refresh session before upload to avoid 403 errors
      await _supabaseClient.auth.refreshSession();

      try {
        await _supabaseClient.storage.from('backups').uploadBinary(
              uploadPath,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        if (await backupFile.exists()) await backupFile.delete();
        if (Platform.isAndroid) await _stopService();
        await _showNotification(
            id: 1,
            title: 'النسخ السحابي',
            body: '✅ تم حفظ النسخة الاحتياطية بنجاح');

        return '✅ تم حفظ النسخة الاحتياطية بنجاح';
      } catch (e) {
        if (Platform.isAndroid) await _stopService();
        debugPrint("❌ Upload error: $e");
        return '❌ فشل الرفع: ${e.toString()}';
      }
    } catch (e) {
      if (Platform.isAndroid) await _stopService();
      debugPrint("❌ Upload error: $e");
      return '❌ فشل الرفع: ${e.toString()}';
    }
  }

  // --- 4. الاستعادة من السحاب ---
  Future<String?> downloadAndRestore(String fullPath) async {
    try {
      if (Platform.isAndroid) {
        _initService();
        await _startService();
        _updateForegroundNotification(
            title: 'جاري الاستعادة', content: 'يتم الآن التحميل...');
      }
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');

      final Uint8List bytes =
          await _supabaseClient.storage.from('backups').download(fullPath);
      await File(tempZipPath).writeAsBytes(bytes);

      final result = await _restoreFromZipPath(tempZipPath);

      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
      if (Platform.isAndroid) await _stopService();

      return result;
    } catch (e) {
      if (Platform.isAndroid) await _stopService();
      return '❌ فشل الاستعادة: $e';
    }
  }

  // --- وظائف المساعدة والعمليات الداخلية ---

  Future<void> restartApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (Platform.isWindows) {
        // إعادة تشغيل على ويندوز
        await Process.start(Platform.resolvedExecutable, []);
        exit(0);
      } else {
        await _platform.invokeMethod('restartApp');
      }
    } catch (e) {
      debugPrint("Restart failed: $e");
      if (Platform.isAndroid) {
        SystemNavigator.pop();
        await Future.delayed(const Duration(milliseconds: 500));
        exit(0);
      }
    }
  }

  Future<List<FileObject>> listBackups() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) return [];
      // List backups from backups bucket (direct path)
      final files = await _supabaseClient.storage.from('backups').list(
        searchOptions: SearchOptions(search: factoryId),
      );
      return files.where((file) => file.name == '$factoryId.zip').toList();
    } catch (e) {
      return [];
    }
  }

  static void _cleanTablesDirectory(Directory dir) {
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync(recursive: false)) {
      final name = p.basename(entity.path);
      // حماية مطلقة لصندوق الارتباط وتجاوز البوابة pairing_vault
      if (name.startsWith('pairing_vault')) {
        continue;
      }
      if (entity is Directory) {
        if (name == 'SmartSheet_Data') {
          _cleanTablesDirectory(entity);
        } else {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            debugPrint('Error deleting dir $name: $e');
          }
        }
      } else if (entity is File) {
        try {
          entity.deleteSync();
        } catch (e) {
          debugPrint('Error deleting file $name: $e');
        }
      }
    }
  }

  Future<String?> _restoreFromZipPath(String zipPath) async {
    try {
      // ─── 1. أخذ لقطة شاملة وحماية فورية لكافة بيانات المصادقة وتجاوز البوابة ───
      final prefs = await SharedPreferences.getInstance();
      const storage = SafeSecureStorage();

      Map<dynamic, dynamic> vaultMap = {};
      if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
        vaultMap = Map<dynamic, dynamic>.from(
            Hive.box(SafeSecureStorage.pairingVaultBoxName).toMap());
      }

      Map<dynamic, dynamic> settingsMap = {};
      if (Hive.isBoxOpen('settings')) {
        settingsMap =
            Map<dynamic, dynamic>.from(Hive.box('settings').toMap());
      }

      final bool isUnlocked = prefs.getBool('is_device_unlocked') == true ||
          prefs.getBool('has_valid_code') == true ||
          prefs.getBool('is_device_unlocked_temp') == true ||
          vaultMap['is_device_unlocked'] == true ||
          vaultMap['has_valid_code'] == true ||
          settingsMap['is_device_unlocked'] == true;

      final bool isDeviceLinked = prefs.getBool('is_device_linked') == true ||
          vaultMap['is_device_linked'] == true ||
          settingsMap['is_device_linked'] == true;

      final String? factoryId = vaultMap['factory_id']?.toString() ??
          settingsMap['factory_id']?.toString() ??
          prefs.getString('factory_id');

      final String? deviceId = vaultMap['device_id']?.toString() ??
          settingsMap['device_id']?.toString() ??
          prefs.getString('device_id');

      final String? userRole = vaultMap['user_role']?.toString() ??
          settingsMap['user_role']?.toString() ??
          prefs.getString('user_role');

      final String? linkedWorkerId =
          vaultMap['linked_worker_id']?.toString() ??
              settingsMap['linked_worker_id']?.toString() ??
              prefs.getString('linked_worker_id');

      final bool isUserLoggedIn = settingsMap['is_user_logged_in'] == true ||
          prefs.getBool('is_user_logged_in') == true;

      // ─── 2. الحفظ الإلزامي في SharedPreferences و SafeSecureStorage ───
      if (isUnlocked) {
        await prefs.setBool('is_device_unlocked', true);
        await prefs.setBool('has_valid_code', true);
        await storage.write(key: 'is_device_unlocked', value: 'true');
        await storage.write(key: 'has_valid_code', value: 'true');
      }
      if (isDeviceLinked) {
        await prefs.setBool('is_device_linked', true);
        await storage.write(key: 'is_device_linked', value: 'true');
      }
      if (factoryId != null && factoryId.isNotEmpty) {
        await prefs.setString('factory_id', factoryId);
        await storage.write(key: 'factory_id', value: factoryId);
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        await prefs.setString('device_id', deviceId);
        await storage.write(key: 'device_id', value: deviceId);
      }
      if (userRole != null && userRole.isNotEmpty) {
        await prefs.setString('user_role', userRole);
        await storage.write(key: 'user_role', value: userRole);
      }
      if (linkedWorkerId != null && linkedWorkerId.isNotEmpty) {
        await prefs.setString('linked_worker_id', linkedWorkerId);
        await storage.write(key: 'linked_worker_id', value: linkedWorkerId);
      }
      if (isUserLoggedIn) {
        await prefs.setBool('is_user_logged_in', true);
      }

      await Hive.close();
      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);

      // حذف البيانات الحالية لاستبدالها بالنسخة المستعادة (الجداول فقط)
      if (appDirInstance.existsSync()) {
        _cleanTablesDirectory(appDirInstance);
      }

      // ─── 4. فك ضغط النسخة الاحتياطية (مع استثناء pairing_vault) ───
      await compute(_restoreBackupInternal, [zipPath, appDir.path]);

      // ─── 5. إعادة فتح Hive وتثبيت بيانات المصادقة والارتباط الدائمة ───
      if (Platform.isWindows) {
        await Hive.initFlutter('SmartSheet_Data');
      } else {
        await Hive.initFlutter();
      }

      final vaultBox =
          await Hive.openBox(SafeSecureStorage.pairingVaultBoxName);
      if (vaultMap.isNotEmpty) {
        await vaultBox.putAll(vaultMap);
      }
      if (isUnlocked) {
        await vaultBox.put('is_device_unlocked', true);
        await vaultBox.put('has_valid_code', true);
      }
      if (isDeviceLinked) {
        await vaultBox.put('is_device_linked', true);
      }
      if (factoryId != null && factoryId.isNotEmpty) {
        await vaultBox.put('factory_id', factoryId);
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        await vaultBox.put('device_id', deviceId);
      }
      if (userRole != null && userRole.isNotEmpty) {
        await vaultBox.put('user_role', userRole);
      }
      if (linkedWorkerId != null && linkedWorkerId.isNotEmpty) {
        await vaultBox.put('linked_worker_id', linkedWorkerId);
      }

      final settingsBox = await Hive.openBox('settings');
      if (settingsMap.isNotEmpty) {
        await settingsBox.putAll(settingsMap);
      }
      if (isUserLoggedIn) {
        await settingsBox.put('is_user_logged_in', true);
      }
      if (isUnlocked) {
        await settingsBox.put('is_device_unlocked', true);
        await settingsBox.put('has_valid_code', true);
      }
      if (isDeviceLinked) {
        await settingsBox.put('is_device_linked', true);
      }
      if (factoryId != null && factoryId.isNotEmpty) {
        await settingsBox.put('factory_id', factoryId);
      }
      if (deviceId != null && deviceId.isNotEmpty) {
        await settingsBox.put('device_id', deviceId);
      }
      if (userRole != null && userRole.isNotEmpty) {
        await settingsBox.put('user_role', userRole);
      }
      if (linkedWorkerId != null && linkedWorkerId.isNotEmpty) {
        await settingsBox.put('linked_worker_id', linkedWorkerId);
      }

      debugPrint('✅ _restoreFromZipPath: تم استرجاع البيانات بنجاح مع صون حالة المصادقة والـ Gatekeeper.');
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
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'temp_backup.zip');

      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();

      // تمرير مسار مجلد التطبيق بالكامل ليشمل القواعد والصور
      await compute(_createBackupInternal, [appDir.path, tempZipPath]);

      final resultFile = File(tempZipPath);
      if (await resultFile.exists() && await resultFile.length() > 0) {
        return tempZipPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @pragma('vm:entry-point')
  static void _createBackupInternal(List<String> args) {
    final String sourceDir = args[0];
    final String zipPath = args[1];

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final dir = Directory(sourceDir);
    if (dir.existsSync()) {
      // البحث بشكل تعامدي (recursive) لضمان الوصول لجميع الملفات والصور
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          // استثناء ملفات القفل أو الملفات المؤقتة لتجنب الأخطاء
          if (entity.path.endsWith('.lock') ||
              entity.path.contains('temp_backup') ||
              p.basename(entity.path).startsWith('pairing_vault')) {
            continue;
          }

          final relativePath = p.relative(entity.path, from: sourceDir);
          encoder.addFile(entity, relativePath.replaceAll('\\', '/'));
        }
      }
    }
    encoder.close(); // إغلاق الـ encoder ضروري جداً لسلامة ملف الـ Zip
  }

  @pragma('vm:entry-point')
  static void _restoreBackupInternal(List<String> args) {
    final File zipFile = File(args[0]);
    if (!zipFile.existsSync()) return;

    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      // حماية مطلقة: عدم استخراج أو استبدال pairing_vault من ملف النسخة الاحتياطية
      if (file.name.contains('pairing_vault')) {
        continue;
      }
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
