import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // لتضمين compute
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  static const String _backupFileName = 'smart_sheet_backup.zip';

  // ✅ دالة مساعدة ثابتة (static) للتشغيل داخل Isolate
  // تقوم بالضغط وتجميع الملفات في الخلفية
  @pragma('vm:entry-point') // لضمان عملها بشكل صحيح في Isolate
  static Future<void> _createBackupInternal(List<String> args) async {
    final appDirPath = args[0];
    final tempZipPath = args[1];

    final appDir = Directory(appDirPath);

    final encoder = ZipFileEncoder();
    encoder.create(tempZipPath);

    // جمع جميع الملفات بشكل تكراري باستخدام listSync(recursive: true)
    final allEntities = appDir.listSync(recursive: true);
    final allFiles = allEntities.whereType<File>().toList();

    final basePath = appDirPath;

    // إضافة كل ملف واحدًا تلو الآخر
    for (final file in allFiles) {
      try {
        final relativePath = file.path
            .replaceFirst(RegExp('^${p.normalize(basePath)}[/\\\\]?'), '');
        final zipPath = relativePath.replaceAll(RegExp(r'[\\/]'), '/');
        encoder.addFile(file, zipPath);
      } catch (e) {
        debugPrint('فشل إضافة الملف في Isolate: ${file.path} - $e');
      }
    }

    await encoder.close();
  }

  /// 💾 إنشاء نسخة احتياطية (باستخدام compute لنقل الضغط إلى Isolate)
  Future<String?> createBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, _backupFileName);
      final appDirPath = appDir.path;

      // تأكد من حذف أي ملف مؤقت سابق
      if (await File(tempZipPath).exists()) {
        await File(tempZipPath).delete();
      }

      // ✅ هذا يحل مشكلة التأخير: تنفيذ عملية الضغط في خلفية منفصلة
      await compute(_createBackupInternal, [appDirPath, tempZipPath]);

      // العمليات التالية (الحفظ عبر FilePicker) سريعة وتتم على الخيط الرئيسي

      final bytes = await File(tempZipPath).readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
      );

      // حذف الملف المؤقت بعد الحفظ أو الإلغاء
      await File(tempZipPath).delete();

      if (savedPath == null) return null;
      return '✅ تم الحفظ بنجاح في:\n$savedPath';
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }

  /// 🔄 استعادة النسخة الاحتياطية مع إصلاح مسارات الصور
  Future<String?> restoreBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
      );

      if (result?.files.single.path == null) return null;
      final zipPath = result!.files.single.path!;

      await Hive.close();

      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);

      // حذف مجلد البيانات الحالي بالكامل
      if (appDirInstance.existsSync()) {
        await appDirInstance.delete(recursive: true);
      }

      // إعادة إنشاء المجلد قبل فك الضغط إليه
      await appDirInstance.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.isFile) {
          final outputPath = p.join(appDir.path, file.name);
          final outputFile = File(outputPath);

          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }
      }

      // ✅ إصلاح مسارات الصور بعد الاستعادة
      await _fixImagePathsAfterRestore();

      return '✅ تم استعادة البيانات بنجاح.\nسيتم إغلاق التطبيق خلال 3 ثوانٍ.\nيرجى إعادة فتحه يدويًا لاستكمال التحديث.';
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
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
            final fileName = entity.path.split('/').last;
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
        final box = await Hive.openBox(boxName);
        final keys = box.keys.toList();

        for (final key in keys) {
          final record = box.get(key);
          if (record is Map && record.containsKey('imagePaths')) {
            final oldPaths = record['imagePaths'] as List;
            final newPaths = <String>[];

            for (final oldPath in oldPaths) {
              if (oldPath is String) {
                final fileName = oldPath.split('/').last;
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
      } catch (e) {
        debugPrint('فشل تحديث $boxName: $e');
      }
    }
  }
}
