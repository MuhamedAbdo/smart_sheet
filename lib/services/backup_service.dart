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
import 'package:window_manager/window_manager.dart';

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
      if (!kIsWeb && Platform.isWindows) {
        // إعادة تشغيل على ويندوز
        await Process.start(Platform.resolvedExecutable, []);
        try {
          if (await windowManager.isPreventClose()) {
            await windowManager.setPreventClose(false);
          }
          await windowManager.destroy();
        } catch (_) {}
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

  /// تنظيف مسارات الصور بعد الاستعادة:
  /// - الاحتفاظ بروابط Cloudinary وروابط Supabase والروابط الصالحة للعرض المباشر من السحابة.
  /// - تنظيف أي مسار صورة محلي مفقود فعلياً على الجهاز لمنع ظهور الصور المكسورة (broken image).
  static Future<void> sanitizeRestoredImagePaths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');

      final box = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');

      if (box.isEmpty) return;

      int cleanedCount = 0;
      for (final key in box.keys) {
        final item = box.get(key);
        if (item is! Map) continue;

        final record = Map<String, dynamic>.from(item);
        dynamic rawImages = record['image_paths'];
        if (rawImages == null || (rawImages is List && rawImages.isEmpty)) {
          rawImages = record['imagePaths'];
        }
        if (rawImages is! List || rawImages.isEmpty) continue;

        final List<String> validImages = [];
        bool modified = false;

        for (final rawPath in rawImages) {
          final path = rawPath.toString().trim();
          if (path.isEmpty) {
            modified = true;
            continue;
          }

          final lower = path.toLowerCase();
          // 1. روابط Cloudinary و Supabase وكافة روابط الويب الصالحة:
          // الحفاظ التام عليها للعرض المباشر من السحابة وعدم اعتبارها مسارات محلية أبداً
          final bool isWebUrl = path.startsWith('http://') ||
              path.startsWith('https://') ||
              lower.contains('supabase.co') ||
              lower.contains('res.cloudinary.com') ||
              lower.contains('cloudinary.com');

          if (isWebUrl) {
            validImages.add(path);
            continue;
          }

          // 2. مسارات الصور المحلية: التأكد من وجود الملف فعلياً على هذا الجهاز
          final directFile = File(path);
          if (directFile.existsSync()) {
            validImages.add(path);
            continue;
          }

          final fileName = p.basename(path);
          final localFile = File('${imagesDir.path}/$fileName');
          if (localFile.existsSync()) {
            validImages.add(localFile.path);
            continue;
          }

          // ملف محلي مفقود فعلياً من الجهاز -> نحذفه لمنع ظهور broken image
          modified = true;
          cleanedCount++;
          debugPrint(
              '🧹 [Restore Cleanup] إزالة مسار صورة محلي مفقود: $path من السجل: ${record['clientName'] ?? record['client_name'] ?? ''}');
        }

        if (modified ||
            record['image_paths'] != validImages ||
            record['imagePaths'] != validImages) {
          record['imagePaths'] = validImages;
          record['image_paths'] = validImages;
          await box.put(key, record);
        }
      }

      debugPrint(
          '✅ [Restore Cleanup] تم تنظيف مسارات الصور بنجاح. أزيل $cleanedCount مساراً محلياً مفقوداً.');
    } catch (e) {
      debugPrint('⚠️ [Restore Cleanup] خطأ أثناء تنظيف مسارات الصور: $e');
    }
  }

  /// حماية وتحديث روابط الصور المستعادة في جدول customers بقاعدة بيانات Supabase:
  /// - تقرأ كافة السجلات من صندوق savedSheetSizes التي تحتوي على image_paths (أو imagePaths) غير فارغة.
  /// - تقوم بتحديث عمود image_paths في جدول customers فوراً بمطابقة id أو sync_id مع factory_id.
  /// - هذا الإجراء يمنع SyncService من مسح الروابط المستعادة عند إعادة تشغيل التطبيق.
  static Future<int> pushRestoredImagePathsToSupabase({String? factoryId}) async {
    try {
      final client = Supabase.instance.client;

      // تحديد معرّف المصنع factoryId من عدة مصادر موثوقة
      String? resolvedFactoryId = factoryId?.trim();
      if (resolvedFactoryId == null || resolvedFactoryId.isEmpty) {
        resolvedFactoryId = await SupabaseManager.getFactoryId();
      }
      if (resolvedFactoryId == null || resolvedFactoryId.isEmpty) {
        if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
          resolvedFactoryId = Hive.box(SafeSecureStorage.pairingVaultBoxName)
              .get('factory_id')
              ?.toString();
        }
      }
      if (resolvedFactoryId == null || resolvedFactoryId.isEmpty) {
        if (Hive.isBoxOpen('settings')) {
          resolvedFactoryId =
              Hive.box('settings').get('factory_id')?.toString();
        }
      }
      if (resolvedFactoryId == null || resolvedFactoryId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        resolvedFactoryId = prefs.getString('factory_id');
      }

      if (resolvedFactoryId == null || resolvedFactoryId.trim().isEmpty) {
        debugPrint(
            '⚠️ [pushRestoredImagePathsToSupabase] لم يتم العثور على factory_id، تعذر التحديث في Supabase.');
        return 0;
      }
      resolvedFactoryId = resolvedFactoryId.trim();

      final box = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');

      if (box.isEmpty) {
        debugPrint(
            'ℹ️ [pushRestoredImagePathsToSupabase] صندوق savedSheetSizes فارغ.');
        return 0;
      }

      int updateCount = 0;
      final List<Future<void>> updateTasks = [];

      for (final key in box.keys) {
        final item = box.get(key);
        if (item is! Map) continue;

        dynamic rawImages = item['image_paths'];
        if (rawImages == null || (rawImages is List && rawImages.isEmpty)) {
          rawImages = item['imagePaths'];
        }
        if (rawImages is! List || rawImages.isEmpty) continue;

        final List<String> paths = rawImages
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (paths.isEmpty) continue;

        final dynamic rawSyncId = item['sync_id'] ?? item['syncId'];
        final String? syncId = rawSyncId?.toString().trim();
        final dynamic rawId = item['id'];
        final String? id = rawId?.toString().trim();

        if ((syncId == null || syncId.isEmpty) && (id == null || id.isEmpty)) {
          continue;
        }

        updateTasks.add(() async {
          try {
            bool updated = false;

            // 1. المطابقة بـ sync_id مع factory_id
            if (syncId != null && syncId.isNotEmpty) {
              try {
                final res = await client
                    .from('customers')
                    .update({'image_paths': paths})
                    .eq('factory_id', resolvedFactoryId!)
                    .eq('sync_id', syncId)
                    .select('id');
                if (res.isNotEmpty) {
                  updated = true;
                  updateCount++;
                }
              } catch (e) {
                debugPrint(
                    '⚠️ [pushRestoredImagePathsToSupabase] محاولة sync_id ($syncId): $e');
              }
            }

            // 2. إذا لم تتطابق أو لم تنجح المطابقة بـ sync_id، المطابقة بـ id مع factory_id
            if (!updated && id != null && id.isNotEmpty) {
              try {
                final res = await client
                    .from('customers')
                    .update({'image_paths': paths})
                    .eq('factory_id', resolvedFactoryId!)
                    .eq('id', rawId)
                    .select('id');
                if (res.isNotEmpty) {
                  updated = true;
                  updateCount++;
                }
              } catch (e) {
                debugPrint(
                    '⚠️ [pushRestoredImagePathsToSupabase] محاولة id ($id): $e');
              }
            }

            // 3. مطابقة احتياطية متبادلة (إذا كان id في Hive مخزناً كـ sync_id في Supabase أو العكس)
            if (!updated) {
              if (id != null && id.isNotEmpty) {
                try {
                  final res = await client
                      .from('customers')
                      .update({'image_paths': paths})
                      .eq('factory_id', resolvedFactoryId!)
                      .eq('sync_id', id)
                      .select('id');
                  if (res.isNotEmpty) {
                    updated = true;
                    updateCount++;
                  }
                } catch (_) {}
              }
              if (!updated && syncId != null && syncId.isNotEmpty) {
                try {
                  final res = await client
                      .from('customers')
                      .update({'image_paths': paths})
                      .eq('factory_id', resolvedFactoryId!)
                      .eq('id', syncId)
                      .select('id');
                  if (res.isNotEmpty) {
                    updated = true;
                    updateCount++;
                  }
                } catch (_) {}
              }
            }
          } catch (e) {
            debugPrint(
                '❌ [pushRestoredImagePathsToSupabase] فشل تحديث السجل ($syncId / $id): $e');
          }
        }());
      }

      // تنفيذ التحديثات بالتوازي على دفعات لتجنب الضغط على الشبكة
      for (var i = 0; i < updateTasks.length; i += 20) {
        final chunk = updateTasks.sublist(
          i,
          i + 20 > updateTasks.length ? updateTasks.length : i + 20,
        );
        await Future.wait(chunk);
      }

      debugPrint(
          '✅ [pushRestoredImagePathsToSupabase] تم تحديث روابط الصور لـ $updateCount سجل في Supabase بنجاح.');
      return updateCount;
    } catch (e) {
      debugPrint(
          '❌ [pushRestoredImagePathsToSupabase] خطأ عام أثناء تحديث روابط الصور في Supabase: $e');
      return 0;
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

      // ─── 6. تنظيف مسارات الصور المحلية المفقودة والاحتفاظ بروابط Cloudinary و Supabase ───
      await sanitizeRestoredImagePaths();

      // ─── 7. حماية ورفع روابط الصور المستعادة إلى جدول customers في Supabase فوراً ───
      await pushRestoredImagePathsToSupabase(factoryId: factoryId);

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
