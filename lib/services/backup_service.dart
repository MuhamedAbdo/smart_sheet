import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // لتضمين compute
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  static const String _backupFileName = 'smart_sheet_backup.zip';

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

  // ✅ دالة مساعدة ثابتة (static) لعملية فك الضغط والكتابة في Isolate
  @pragma('vm:entry-point')
  static Future<void> _restoreBackupInternal(List<String> args) async {
    final zipPath = args[0];
    final appDirPath = args[1];

    // 🛑 التعديل الرئيسي: استخدام فك الضغط التدريجي (Streaming)
    // لتقليل الضغط على الذاكرة والكتابة بشكل أكثر كفاءة.
    try {
      // فتح ملف ZIP كـ Input Stream بدلاً من تحميله بالكامل كـ Bytes
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      for (final file in archive) {
        if (file.isFile) {
          final outputPath = p.join(appDirPath, file.name);
          final outputFile = File(outputPath);

          try {
            await outputFile.create(recursive: true);

            // كتابة المحتوى على القرص
            if (file.content is List<int>) {
              // يتم استخدام هذا المسار للملفات الصغيرة بعد فك الضغط
              await outputFile.writeAsBytes(file.content as List<int>);
            } else if (file.content is InputStream) {
              // هذا المسار غير شائع مع decodeBuffer لكن يضمن التعامل مع التدفق إذا حدث
              final outputStream = OutputFileStream(outputPath);
              await file.content.copyTo(outputStream);
              outputStream.close();
            }
          } catch (e) {
            debugPrint('ERROR: Failed to write file ${file.name}: $e');
          }
        }
      }
      // إغلاق التدفق بعد الانتهاء
      inputStream.close();
    } catch (e) {
      debugPrint('CRITICAL ERROR in _restoreBackupInternal: $e');
      // يمكن إلقاء خطأ هنا ليمسكه FutureBuilder
      throw Exception('Failed to decompress backup file: $e');
    }
  }

  /// 💾 إنشاء نسخة احتياطية
  Future<String?> createBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, _backupFileName);
      final appDirPath = appDir.path;

      if (await File(tempZipPath).exists()) {
        await File(tempZipPath).delete();
      }

      await compute(_createBackupInternal, [appDirPath, tempZipPath]);

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

  /// 🔄 استعادة النسخة الاحتياطية
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
      final appDirPath = appDir.path;

      // حذف مجلد البيانات الحالي بالكامل
      if (appDirInstance.existsSync()) {
        await appDirInstance.delete(recursive: true);
      }

      // إعادة إنشاء المجلد قبل فك الضغط إليه
      await appDirInstance.create(recursive: true);

      // ✅ نقل عملية فك الضغط والكتابة إلى Isolate
      await compute(_restoreBackupInternal, [zipPath, appDirPath]);

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
        final box = await Hive.openBox(boxName);
        final keys = box.keys.toList();

        for (final key in keys) {
          final record = box.get(key);
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
      } catch (e) {
        debugPrint('فشل تحديث $boxName: $e');
      }
    }
  }
}
