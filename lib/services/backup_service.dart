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

// ✅ دالة مساعدة للضغط (بدون استخدام Hive أو context)
Future<void> _addDirectoryToZipInIsolate(
  ZipFileEncoder encoder,
  Directory dir,
  String basePath,
) async {
  final entities = dir.listSync(recursive: false);
  for (final entity in entities) {
    if (entity is File) {
      final relativePath = p.relative(entity.path, from: basePath);
      final zipPath = relativePath.replaceAll(RegExp(r'[\\/]'), '/');
      encoder.addFile(entity, zipPath);
    } else if (entity is Directory) {
      await _addDirectoryToZipInIsolate(encoder, entity, basePath);
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

      return '✅ تم استعادة البيانات بنجاح.\nسيتم إغلاق التطبيق خلال 3 ثوانٍ.\nيرجى إعادة فتحه يدويًا لاستكمال التحديث.';
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }
}
