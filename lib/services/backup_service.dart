// lib/src/services/backup_service.dart

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupService {
  // ✅ إضافة عميل Supabase
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String BUCKET_NAME = 'db_backups'; // اسم الـ Bucket
  static const String _backupFileName = 'smart_sheet_backup.zip';

  // ==========================================================
  // دوال Supabase Storage
  // ==========================================================

  /// 📤 رفع النسخة الاحتياطية المحلية إلى Supabase Storage
  Future<String?> uploadToSupabase() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      // 1. إنشاء ملف النسخة الاحتياطية محلياً
      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null)
        return '❌ فشل في إنشاء ملف النسخة الاحتياطية المحلية.';

      final backupFile = File(localBackupPath);
      final uniqueFileName =
          '${DateTime.now().toIso8601String()}_$_backupFileName';

      // 2. الرفع إلى Supabase
      final uploadPath = 'manual_backups/$uniqueFileName';

      await _supabaseClient.storage.from(BUCKET_NAME).upload(
            uploadPath,
            backupFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // 3. حذف الملف المحلي المؤقت
      await backupFile.delete();

      return '✅ تم رفع النسخة الاحتياطية بنجاح إلى السحابة.';
    } catch (e) {
      debugPrint('Supabase Upload Error: $e');
      return '❌ فشل رفع النسخة الاحتياطية السحابية: ${e.toString()}';
    }
  }

  /// ⬇️ تنزيل النسخة الاحتياطية من Supabase Storage
  Future<String?> downloadAndRestore(String filePath) async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      // 1. تحديد المسار المؤقت للتنزيل
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');
      final downloadedFile = File(tempZipPath);

      // 2. تنزيل الملف
      final bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(filePath);

      await downloadedFile.writeAsBytes(bytes);

      // 3. استعادة النسخة الاحتياطية من المسار المؤقت
      final result = await _restoreFromZipPath(tempZipPath);

      // 4. حذف الملف المؤقت بعد الاستعادة
      await downloadedFile.delete();

      return result;
    } catch (e) {
      debugPrint('Supabase Download Error: $e');
      return '❌ فشل تنزيل واستعادة النسخة السحابية: ${e.toString()}';
    }
  }

  /// 📄 جلب قائمة بالنسخ الاحتياطية المتاحة (للاختيار من بينها)
  Future<List<FileObject>> listBackups() async {
    try {
      // ✅ التصحيح: إزالة جميع المعلمات المتقدمة (options/sortBy) لتجنب أخطاء التسمية
      // الاعتماد على الإعدادات الافتراضية، والفرز يدويًا في Dart بعد الجلب.
      final files = await _supabaseClient.storage.from(BUCKET_NAME).list(
            path: 'manual_backups', // تصفية لـ manual_backups فقط
            // limit: 100, // يمكن إضافة هذا إذا كان لديك عدد كبير من النسخ الاحتياطية
            // search: '', // يمكن إضافة هذا إذا كنت تبحث عن ملفات معينة
          );

      // تصفية إضافية لإزالة المجلدات أو الملفات غير المرغوب فيها
      final zipFiles =
          files.where((file) => file.name.endsWith('.zip')).toList();

      // ✅ فرز الملفات يدويًا حسب created_at بترتيب تنازلي (الأحدث أولاً)
      zipFiles.sort((a, b) {
        final dateA = a.createdAt;
        final dateB = b.createdAt;
        // إذا كان أحد التواريخ غير موجود، نعتبره أقدم
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1; // نعتبر A أقدم
        if (dateB == null) return -1; // نعتبر B أقدم
        return dateB.compareTo(dateA); // الترتيب التنازلي
      });

      return zipFiles;
    } catch (e) {
      debugPrint('Error listing backups: $e');
      return [];
    }
  }

  // ==========================================================
  // دوال مساعدة مُعاد تنظيمها
  // ==========================================================

  /// دالة مُعاد تنظيمها لإنشاء ملف النسخة الاحتياطية المحلي وارجاع مساره
  Future<String?> _createLocalBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, _backupFileName);
    final appDirPath = appDir.path;

    if (await File(tempZipPath).exists()) {
      await File(tempZipPath).delete();
    }

    // نقل عملية الضغط إلى Isolate
    await compute(_createBackupInternal, [appDirPath, tempZipPath]);

    if (!await File(tempZipPath).exists()) return null;
    return tempZipPath;
  }

  /// دالة مُعاد تنظيمها لتنفيذ الاستعادة من مسار ZIP محدد
  Future<String?> _restoreFromZipPath(String zipPath) async {
    try {
      // ⚠️ يجب إغلاق جميع الصناديق قبل الاستعادة لضمان عدم وجود قفل على الملفات
      await Hive.close();

      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);
      final appDirPath = appDir.path;

      // حذف مجلد البيانات الحالي بالكامل
      if (appDirInstance.existsSync()) {
        await appDirInstance.delete(recursive: true);
      }

      // إعادة إنشاء المجلد قبل فك الضغط إليه
      await appDirInstance.create(recursive: true);

      // نقل عملية فك الضغط والكتابة إلى Isolate
      await compute(_restoreBackupInternal, [zipPath, appDirPath]);

      // إصلاح مسارات الصور بعد الاستعادة
      await _fixImagePathsAfterRestore();

      // بما أننا قمنا بـ Hive.close، يجب أن نطلب إعادة تشغيل التطبيق ليعيد فتح الصناديق
      return '✅ تم استعادة البيانات بنجاح.\nسيتم إغلاق التطبيق خلال 3 ثوانٍ.\nيرجى إعادة فتحه يدويًا لاستكمال التحديث.';
    } catch (e) {
      debugPrint('Restore failed: $e');
      return '❌ خطأ أثناء الاستعادة: ${e.toString()}';
    }
  }

  // ==========================================================
  // الدوال العامة والداخلية (مع تحديث طفيف)
  // ==========================================================

  /// 💾 إنشاء نسخة احتياطية محلية (للتوافق مع دالتك الأصلية)
  Future<String?> createBackup() async {
    try {
      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null)
        return '❌ فشل في إنشاء ملف النسخة الاحتياطية المحلية.';

      final bytes = await File(localBackupPath).readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
      );

      // تنظيف الملف المؤقت
      await File(localBackupPath).delete();

      if (savedPath == null) return null;
      return '✅ تم الحفظ بنجاح في:\n$savedPath';
    } catch (e) {
      return '❌ خطأ في النسخ الاحتياطي المحلي: ${e.toString()}';
    }
  }

  /// 🔄 استعادة النسخة الاحتياطية المحلية
  Future<String?> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
      );

      if (result?.files.single.path == null) return null;
      final zipPath = result!.files.single.path!;

      return _restoreFromZipPath(zipPath);
    } catch (e) {
      return '❌ خطأ في استعادة النسخة الاحتياطية المحلية: ${e.toString()}';
    }
  }

  // ==========================================================
  // الدوال الداخلية لـ Isolate وإصلاح المسارات (من الكود الأصلي)
  // ==========================================================

  // ✅ دالة مساعدة ثابتة (static) لعملية الضغط في Isolate
  @pragma('vm:entry-point')
  static Future<void> _createBackupInternal(List<String> args) async {
    final appDirPath = args[0];
    final tempZipPath = args[1];

    final appDir = Directory(appDirPath);

    final encoder = ZipFileEncoder();
    encoder.create(tempZipPath);

    final allEntities = appDir.listSync(recursive: true);
    final allFiles = allEntities.whereType<File>().toList();

    final basePath = appDirPath;

    for (final file in allFiles) {
      try {
        // تأكد من عدم ضم ملف الـ zip نفسه إلى الأرشيف
        if (p.basename(file.path) == p.basename(tempZipPath)) {
          continue;
        }

        final relativePath = file.path
            .replaceFirst(RegExp('^${p.normalize(basePath)}[/\\\\]?'), '');
        final zipPath = relativePath.replaceAll(RegExp(r'[\\/]'), '/');
        encoder.addFile(file, zipPath);
      } catch (e) {
        // لا نستخدم debugPrint في الـ isolate بشكل عام، لكن لا بأس هنا للتتبع
        // debugPrint('فشل إضافة الملف في Isolate: ${file.path} - $e');
      }
    }

    await encoder.close();
  }

  // ✅ دالة مساعدة ثابتة (static) لعملية فك الضغط والكتابة في Isolate
  @pragma('vm:entry-point')
  static Future<void> _restoreBackupInternal(List<String> args) async {
    final zipPath = args[0];
    final appDirPath = args[1];

    try {
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final file in archive) {
        if (file.isFile) {
          final outputPath = p.join(appDirPath, file.name);
          final outputFile = File(outputPath);

          try {
            await outputFile.create(recursive: true);

            if (file.content is List<int>) {
              await outputFile.writeAsBytes(file.content as List<int>);
            } else if (file.content is InputStream) {
              final outputStream = OutputFileStream(outputPath);
              await file.content.copyTo(outputStream);
              outputStream.close();
            }
          } catch (e) {
            // debugPrint('ERROR: Failed to write file ${file.name}: $e');
          }
        }
      }
      inputStream.close();
    } catch (e) {
      // debugPrint('CRITICAL ERROR in _restoreBackupInternal: $e');
      throw Exception('Failed to decompress backup file: $e');
    }
  }

  // ✅ دالة لإصلاح مسارات الصور بعد الاستعادة
  Future<void> _fixImagePathsAfterRestore() async {
    final appDir = await getApplicationDocumentsDirectory();
    final appDirPath = appDir.path;

    // جمع جميع أسماء الملفات الموجودة في مجلدات الصور
    final fileNameToPath = <String, String>{};
    final imageFolders = [
      'app_images',
      'maintenance_images',
      'sheet_size_images',
      'finished_product_images'
    ];

    for (final folder in imageFolders) {
      final dir = Directory('$appDirPath/$folder');
      if (dir.existsSync()) {
        final files = dir.listSync();
        for (final entity in files) {
          if (entity is File) {
            // استخدام p.basename لتوحيد استخراج اسم الملف
            final fileName = p.basename(entity.path);
            fileNameToPath[fileName] = entity.path;
          }
        }
      }
    }

    // تحديث المسارات في جميع صناديق Hive
    final boxNames = [
      'inkReports',
      'finished_products',
      'savedSheetSizes',
      'savedSheetSizes_production',
      'maintenance_records_main',
      'maintenance_staple_v2',
      'maintenance_flexo_v2',
      'maintenance_production_v2',
      'maintenance_crushing_v2',
    ];

    for (final boxName in boxNames) {
      try {
        // يجب استخدام Hive.openBox هنا لضمان فتح الصندوق بعد Hive.close()
        final box = await Hive.openBox(boxName);
        final keys = box.keys.toList();

        for (final key in keys) {
          final record = box.get(key);
          // يجب التعامل مع أنواع مختلفة من السجلات التي قد لا تكون Maps
          if (record is Map && record.containsKey('imagePaths')) {
            final oldPaths = record['imagePaths'] as List;
            final newPaths = <String>[];

            for (final oldPath in oldPaths) {
              if (oldPath is String) {
                // استخدام p.basename لتوحيد استخراج اسم الملف
                final fileName = p.basename(oldPath);
                if (fileNameToPath.containsKey(fileName)) {
                  newPaths.add(fileNameToPath[fileName]!);
                } else {
                  newPaths
                      .add(oldPath); // الحفاظ على المسار الأصلي إذا لم يُوجد
                }
              }
            }

            final updatedRecord = Map<String, dynamic>.from(record);
            updatedRecord['imagePaths'] = newPaths;
            await box.put(key, updatedRecord);
          }
        }
        // يجب إغلاق الصندوق هنا إذا كنا نخطط لإعادة تشغيل التطبيق بعد فترة وجيزة
        await box.close();
      } catch (e) {
        debugPrint('فشل تحديث $boxName: $e');
      }
    }
  }
}
