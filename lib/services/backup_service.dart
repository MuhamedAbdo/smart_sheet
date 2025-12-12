// lib/services/backup_service.dart

import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// ✅ دالة منفصلة للضغط (ستعمل في Isolate)
Future<String> _createZipInIsolate(List<dynamic> args) async {
  final String tempDirPath = args[0];
  final String appDirPath = args[1];
  final String backupFileName = args[2];

  final tempZipPath = p.join(tempDirPath, backupFileName);
  final encoder = ZipFileEncoder();
  encoder.create(tempZipPath);

  final appDir = Directory(appDirPath);
  await _addDirectoryToZipInIsolate(encoder, appDir, appDirPath);

  await encoder.close();

  return tempZipPath;
}

// ✅ دالة مساعدة للضغط (تدعم جميع المجلدات الفرعية بشكل كامل)
Future<void> _addDirectoryToZipInIsolate(
  ZipFileEncoder encoder,
  Directory dir,
  String basePath,
) async {
  // توحيد basePath ليكون متوافقًا مع النظام
  String cleanBasePath = basePath;
  if (!cleanBasePath.endsWith('/') && !cleanBasePath.endsWith('\\')) {
    cleanBasePath = '$cleanBasePath${Platform.isWindows ? '\\' : '/'}';
  }

  // الحصول على جميع الملفات (بما في ذلك داخل المجلدات الفرعية)
  final allEntities = dir.listSync(recursive: true);

  for (final entity in allEntities) {
    if (entity is File) {
      // حساب المسار النسبي من basePath
      String relativePath =
          entity.path.replaceFirst(RegExp('^$cleanBasePath'), '');
      // توحيد الفواصل إلى / لملفات ZIP
      relativePath = relativePath.replaceAll(RegExp(r'[\\/]'), '/');
      encoder.addFile(entity, relativePath);
    }
  }
}

class BackupService {
  static const String _backupFileName = 'smart_sheet_backup.zip';

  /// 💾 إنشاء نسخة احتياطية مع مؤشر تقدم نشط (يطلب من المستخدم اختيار المجلد دائمًا)
  Future<String?> createBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final appDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();

      // ✅ تشغيل الضغط في خلفية (لا يجمد الواجهة)
      final zipPath = await compute(
        _createZipInIsolate,
        [tempDir.path, appDir.path, _backupFileName],
      );

      // ✅ استخدام FilePicker دومًا لضمان ظهور نافذة الحفظ
      final savedPath = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: await File(zipPath).readAsBytes(),
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
      );

      await File(zipPath).delete();

      if (savedPath == null) return null;

      // ✅ عرض المسار الكامل للمستخدم
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
