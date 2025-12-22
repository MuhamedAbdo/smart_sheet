import 'dart:io';
import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String BUCKET_NAME = 'backups';
  static const String _backupFileName = 'smart_sheet_backup.zip';

  // ---------------------------------------------------------
  // ☁️ العمليات السحابية (Cloud Operations)
  // ---------------------------------------------------------

  Future<String?> uploadToSupabase() async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final localBackupPath = await _createLocalBackupFile().timeout(
          const Duration(seconds: 60),
          onTimeout: () =>
              throw TimeoutException('عملية الضغط استغرقت وقتاً طويلاً'));

      if (localBackupPath == null) return '❌ فشل إنشاء ملف النسخة المحلية.';

      final backupFile = File(localBackupPath);
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return '❌ يجب تسجيل الدخول للرفع السحابي.';

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
          .timeout(const Duration(minutes: 3), onTimeout: () {
        throw TimeoutException('اتصال الإنترنت ضعيف، فشل الرفع.');
      });

      if (await backupFile.exists()) await backupFile.delete();
      return '✅ تم الرفع بنجاح.';
    } catch (e) {
      if (e is TimeoutException) return '⚠️ ${e.message}';
      return '❌ فشل الرفع: ${e.toString()}';
    }
  }

  Future<String?> downloadAndRestore(String fullPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');
      final Uint8List bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(fullPath);
      await File(tempZipPath).writeAsBytes(bytes);
      final result = await _restoreFromZipPath(tempZipPath);
      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
      return result;
    } catch (e) {
      return '❌ فشل الاستعادة: ${e.toString()}';
    }
  }

  Future<List<FileObject>> listBackups() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return [];
      return await _supabaseClient.storage.from(BUCKET_NAME).list(
            path: 'manual_backups/${user.id}',
          );
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------
  // 📱 العمليات المحلية (Local Operations) - المطلوبة للـ AppDrawer
  // ---------------------------------------------------------

  Future<String?> createBackup() async {
    try {
      final localPath = await _createLocalBackupFile();
      if (localPath == null) return '❌ فشل إنشاء الملف';

      final bytes = await File(localPath).readAsBytes();
      final String? saved = await FilePicker.platform.saveFile(
          fileName: _backupFileName,
          bytes: bytes,
          type: FileType.custom,
          allowedExtensions: ['zip']);

      if (await File(localPath).exists()) await File(localPath).delete();
      return saved != null ? '✅ تم حفظ النسخة بنجاح' : null;
    } catch (e) {
      return '❌ خطأ محلي: $e';
    }
  }

  Future<String?> restoreBackup() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (result?.files.single.path == null) return null;
      return await _restoreFromZipPath(result!.files.single.path!);
    } catch (e) {
      return '❌ فشل اختيار الملف: $e';
    }
  }

  // ---------------------------------------------------------
  // ⚙️ المساعدات الداخلية (Internal Helpers)
  // ---------------------------------------------------------

  Future<String?> _createLocalBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, 'temp_backup.zip');
    if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
    await compute(_createBackupInternal, [appDir.path, tempZipPath]);
    return tempZipPath;
  }

  Future<String?> _restoreFromZipPath(String zipPath) async {
    try {
      await Hive.close();
      final appDir = await getApplicationDocumentsDirectory();
      final appDirInstance = Directory(appDir.path);
      if (appDirInstance.existsSync()) {
        appDirInstance.listSync().forEach((e) => e.deleteSync(recursive: true));
      }
      await appDirInstance.create(recursive: true);
      await compute(_restoreBackupInternal, [zipPath, appDir.path]);
      return 'SUCCESS_RESTORE';
    } catch (e) {
      return '❌ فشل فك الضغط: $e';
    }
  }

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
