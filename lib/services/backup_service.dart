// lib/services/backup_service.dart

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  static const String _backupFileName = 'smart_sheet_backup.zip';

  /// 💾 إنشاء نسخة احتياطية (بدون Isolate لضمان اكتمال الضغط مع الملفات الكبيرة)
  Future<String?> createBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, _backupFileName);

      final encoder = ZipFileEncoder();
      encoder.create(tempZipPath);

      // ✅ إضافة جميع الملفات (بما في ذلك الصور) بشكل متسلسل
      await _addDirectoryToZip(encoder, appDir, appDir.path);

      await encoder.close();

      final bytes = await File(tempZipPath).readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
      );

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
      if (appDirInstance.existsSync()) {
        await appDirInstance.delete(recursive: true);
      }

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

  // ✅ دالة مساعدة: إضافة مجلد كامل إلى ZIP (مع دعم كامل للتكرار)
  Future<void> _addDirectoryToZip(
    ZipFileEncoder encoder,
    Directory dir,
    String basePath,
  ) async {
    // جمع جميع الملفات بشكل متكرر
    final allFiles = <File>[];
    void collectFiles(Directory currentDir) {
      try {
        final entities = currentDir.listSync(recursive: false);
        for (final entity in entities) {
          if (entity is File) {
            allFiles.add(entity);
          } else if (entity is Directory) {
            collectFiles(entity);
          }
        }
      } catch (e) {
        debugPrint('لا يمكن قراءة المجلد: ${currentDir.path} - $e');
      }
    }

    collectFiles(dir);

    // إضافة كل ملف واحدًا تلو الآخر
    for (final file in allFiles) {
      try {
        final relativePath = file.path
            .replaceFirst(RegExp('^${p.normalize(basePath)}[/\\\\]?'), '');
        final zipPath = relativePath.replaceAll(RegExp(r'[\\/]'), '/');
        encoder.addFile(file, zipPath);
      } catch (e) {
        debugPrint('فشل إضافة الملف: ${file.path} - $e');
      }
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
