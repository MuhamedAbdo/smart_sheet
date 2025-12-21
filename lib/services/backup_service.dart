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

  // ☁️ رفع النسخة للسحابة
  Future<String?> uploadToSupabase(
      {void Function(double progress)? onProgress}) async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';
      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null) return '❌ فشل إنشاء ملف النسخة المحلية.';

      final backupFile = File(localBackupPath);
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return '❌ يجب تسجيل الدخول للرفع السحابي.';

      final uniqueFileName =
          '${DateTime.now().toIso8601String().replaceAll(':', '-')}_$_backupFileName';
      // المسار المعتمد: manual_backups/USER_ID/FILE_NAME
      final uploadPath = 'manual_backups/${user.id}/$uniqueFileName';

      if (onProgress != null) _simulateProgress(onProgress);

      await _supabaseClient.storage.from(BUCKET_NAME).upload(
            uploadPath,
            backupFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      if (await backupFile.exists()) await backupFile.delete();
      return '✅ تم الرفع بنجاح.';
    } catch (e) {
      return '❌ فشل الرفع: ${e.toString()}';
    }
  }

  // 📥 تنزيل واستعادة (الإصلاح الجوهري لمسار 404)
  Future<String?> downloadAndRestore(String fullPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');

      // تنزيل باستخدام المسار الكامل المستلم من الواجهة
      final Uint8List bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(fullPath);

      await File(tempZipPath).writeAsBytes(bytes);
      final result = await _restoreFromZipPath(tempZipPath);

      if (await File(tempZipPath).exists()) await File(tempZipPath).delete();
      return result == 'SUCCESS_RESTORE'
          ? '✅ تم استعادة البيانات بنجاح.'
          : result;
    } on StorageException catch (e) {
      return '❌ خطأ 404: الملف غير موجود في المسار السحابي المحدد.';
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

  // ⚙️ العمليات الداخلية
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
      await _fixImagePathsAfterRestore();
      return 'SUCCESS_RESTORE';
    } catch (e) {
      return '❌ فشل فك الضغط: $e';
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _createBackupInternal(List<String> args) async {
    final encoder = ZipFileEncoder();
    encoder.create(args[1]);
    final appDir = Directory(args[0]);
    for (final entity in appDir.listSync(recursive: true)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: args[0]);
        encoder.addFile(entity, relativePath.replaceAll('\\', '/'));
      }
    }
    await encoder.close();
  }

  @pragma('vm:entry-point')
  static Future<void> _restoreBackupInternal(List<String> args) async {
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

  Future<void> _fixImagePathsAfterRestore() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileNameToPath = <String, String>{};
    for (final e in appDir.listSync(recursive: true)) {
      if (e is File) fileNameToPath[p.basename(e.path)] = e.path;
    }
    final boxes = [
      'inkReports',
      'finished_products',
      'savedSheetSizes',
      'maintenance_records_main'
    ];
    for (final b in boxes) {
      if (await Hive.boxExists(b)) {
        final box = await Hive.openBox(b);
        for (final key in box.keys) {
          final record = box.get(key);
          if (record is Map && record.containsKey('imagePaths')) {
            final List<String> newPaths = (record['imagePaths'] as List)
                .map((pOld) =>
                    fileNameToPath[p.basename(pOld.toString())] ??
                    pOld.toString())
                .toList();
            final updated = Map<String, dynamic>.from(record)
              ..['imagePaths'] = newPaths;
            await box.put(key, updated);
          }
        }
        await box.close();
      }
    }
  }

  void _simulateProgress(void Function(double) onProgress) {
    double pVal = 0.0;
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      pVal += 0.05;
      if (pVal >= 0.9) {
        onProgress(0.9);
        timer.cancel();
      } else {
        onProgress(pVal);
      }
    });
  }

  Future<String?> createBackup() async {
    final localPath = await _createLocalBackupFile();
    if (localPath == null) return null;
    final bytes = await File(localPath).readAsBytes();
    final saved = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip']);
    return saved != null ? '✅ تم الحفظ محلياً' : null;
  }

  Future<String?> restoreBackup() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result?.files.single.path == null) return null;
    return await _restoreFromZipPath(result!.files.single.path!);
  }

  void dispose() {}
}
