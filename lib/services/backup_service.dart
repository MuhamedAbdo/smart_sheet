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

  /// 💾 إنشاء نسخة احتياطية (يطلب من المستخدم اختيار مجلد)
  Future<String?> createBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      // 1. الحصول على مجلد التطبيق (حيث توجد Hive + الصور)
      final appDir = await getApplicationDocumentsDirectory();

      // 2. إنشاء ZIP مؤقت
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, _backupFileName);
      final encoder = ZipFileEncoder();
      encoder.create(tempZipPath);

      // 3. إضافة جميع ملفات التطبيق (hive + الصور)
      await _addDirectoryToZip(encoder, appDir, appDir.path);

      await encoder.close();

      // 4. حفظ الملف إلى مكان يختاره المستخدم
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
      return '✅ تم الحفظ بنجاح.';
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }

  /// 🔄 استعادة النسخة الاحتياطية
  Future<String?> restoreBackup() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      // 1. اختيار ملف ZIP
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
      );

      if (result?.files.single.path == null) return null;
      final zipPath = result!.files.single.path!;

      // 2. إغلاق Hive
      await Hive.close();

      // 3. حذف البيانات الحالية
      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);
      if (appDirInstance.existsSync()) {
        await appDirInstance.delete(recursive: true);
      }

      // 4. فك ضغط الملف إلى مجلد التطبيق
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

      // ✅ رسالة توضح أن التطبيق سيُغلق تلقائيًا
      return '✅ تم استعادة البيانات بنجاح.\nسيتم إغلاق التطبيق خلال 3 ثوانٍ.\nيرجى إعادة فتحه يدويًا لاستكمال التحديث.';
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }

  /// دالة مساعدة: إضافة مجلد كامل إلى ZIP (مع الحفاظ على الهيكل)
  Future<void> _addDirectoryToZip(
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
        await _addDirectoryToZip(encoder, entity, basePath);
      }
    }
  }
}
