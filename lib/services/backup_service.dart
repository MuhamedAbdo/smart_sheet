import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class BackupService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String BUCKET_NAME = 'db_backups';
  static const String _backupFileName = 'smart_sheet_backup.zip';

  StreamController<double>? _uploadProgressController;

  // ==========================================================
  // دوال Supabase Storage
  // ==========================================================

  Future<String?> createCloudBackup() async {
    return uploadToSupabase(onProgress: null);
  }

  Future<String?> uploadToSupabase({
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';

      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null) {
        return '❌ فشل في إنشاء ملف النسخة الاحتياطية المحلية.';
      }

      final backupFile = File(localBackupPath);
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return '❌ يجب تسجيل الدخول أولاً للرفع السحابي.';

      final uniqueFileName =
          '${user.id}/${DateTime.now().toIso8601String().replaceAll(':', '-')}_$_backupFileName';

      final uploadPath = 'manual_backups/$uniqueFileName';

      Completer<void>? progressCompleter;
      Future<void>? progressFuture;

      if (onProgress != null) {
        onProgress(0.0);
        progressCompleter = Completer<void>();
        progressFuture = _simulateProgressWithGuarantee(
          onProgress: onProgress,
          completer: progressCompleter,
        );
      }

      try {
        // 💡 تم رفع المهلة إلى 600 ثانية (10 دقائق) لضمان رفع الملفات الكبيرة (22MB+)
        await _supabaseClient.storage
            .from(BUCKET_NAME)
            .upload(
              uploadPath,
              backupFile,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            )
            .timeout(const Duration(seconds: 600));

        progressCompleter?.complete();
        if (progressFuture != null) await progressFuture;
      } on TimeoutException {
        progressCompleter?.completeError('Upload Timeout');
        return '❌ انتهت مهلة الرفع. الملف كبير جداً أو الإنترنت ضعيف. حاول مرة أخرى.';
      } catch (e) {
        progressCompleter?.completeError(e);
        rethrow;
      }

      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      final double sizeMB = backupFile.lengthSync() / (1024 * 1024);
      return '✅ تم الرفع بنجاح (الحجم: ${sizeMB.toStringAsFixed(2)} MB).';
    } on StorageException catch (e) {
      return '❌ فشل رفع النسخة (خطأ تخزين): ${e.message}';
    } catch (e) {
      return '❌ فشل رفع النسخة السحابية: ${e.toString()}';
    }
  }

  Future<void> _simulateProgressWithGuarantee({
    required void Function(double progress)? onProgress,
    required Completer<void> completer,
  }) async {
    if (onProgress == null) {
      completer.complete();
      return;
    }
    int steps = 0;
    const int maxSteps = 50;
    while (steps < maxSteps && !completer.isCompleted) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!completer.isCompleted) {
        steps++;
        onProgress((steps / maxSteps) * 0.95);
      }
    }
    if (completer.isCompleted) onProgress(1.0);
  }

  Future<String?> downloadAndRestore(String filePath) async {
    try {
      if (kIsWeb) return 'غير مدعوم على الويب.';
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(tempDir.path, 'downloaded_backup.zip');
      final bytes =
          await _supabaseClient.storage.from(BUCKET_NAME).download(filePath);
      await File(tempZipPath).writeAsBytes(bytes);
      final result = await _restoreFromZipPath(tempZipPath);
      await File(tempZipPath).delete();
      return result;
    } catch (e) {
      return '❌ فشل الاستعادة السحابية: ${e.toString()}';
    }
  }

  Future<List<FileObject>> listBackups() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) return [];
      final files = await _supabaseClient.storage.from(BUCKET_NAME).list(
            path: 'manual_backups/${user.id}',
          );
      files.sort((a, b) => (b.createdAt ?? "").compareTo(a.createdAt ?? ""));
      return files.where((f) => f.name.endsWith('.zip')).toList();
    } catch (e) {
      return [];
    }
  }

  // ==========================================================
  // الدوال المساعدة (ضغط وفك شامل وديناميكي)
  // ==========================================================

  Future<String?> _createLocalBackupFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = p.join(tempDir.path, _backupFileName);

    if (await File(tempZipPath).exists()) await File(tempZipPath).delete();

    // 💡 مسح شامل لكل المجلدات والملفات داخل تطبيقك
    await compute(_createBackupInternal, [appDir.path, tempZipPath]);

    if (!await File(tempZipPath).exists()) return null;
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

      // 💡 إصلاح المسارات بشكل ديناميكي لكل الصور
      await _fixImagePathsAfterRestore();

      return '✅ تم استعادة البيانات بنجاح.\nسيتم إغلاق التطبيق، يرجى إعادة فتحه.';
    } catch (e) {
      return '❌ خطأ أثناء الاستعادة: ${e.toString()}';
    }
  }

  // ==========================================================
  // الدوال العامة للنسخ المحلي
  // ==========================================================

  Future<String?> createBackup() async {
    try {
      final localBackupPath = await _createLocalBackupFile();
      if (localBackupPath == null) return '❌ فشل إنشاء ملف النسخة.';
      final bytes = await File(localBackupPath).readAsBytes();
      final savedPath = await FilePicker.platform.saveFile(
        fileName: _backupFileName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      await File(localBackupPath).delete();
      return savedPath != null ? '✅ تم الحفظ بنجاح.' : null;
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }

  Future<String?> restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result?.files.single.path == null) return null;
      return _restoreFromZipPath(result!.files.single.path!);
    } catch (e) {
      return '❌ خطأ: ${e.toString()}';
    }
  }

  // ==========================================================
  // الدوال داخل الـ Isolate (ديناميكية بالكامل)
  // ==========================================================

  @pragma('vm:entry-point')
  static Future<void> _createBackupInternal(List<String> args) async {
    final appDirPath = args[0];
    final tempZipPath = args[1];
    final encoder = ZipFileEncoder();
    encoder.create(tempZipPath);

    final appDir = Directory(appDirPath);
    // 💡 recursive: true يضمن الدخول لكل المجلدات مهما كان عددها
    final allEntities = appDir.listSync(recursive: true);

    for (final entity in allEntities) {
      if (entity is File) {
        if (p.basename(entity.path) == p.basename(tempZipPath)) continue;
        final relativePath = p.relative(entity.path, from: appDirPath);
        encoder.addFile(entity, relativePath.replaceAll('\\', '/'));
      }
    }
    await encoder.close();
  }

  @pragma('vm:entry-point')
  static Future<void> _restoreBackupInternal(List<String> args) async {
    final zipPath = args[0];
    final appDirPath = args[1];
    final archive = ZipDecoder().decodeBuffer(InputFileStream(zipPath));

    for (final file in archive) {
      if (file.isFile) {
        final outputPath = p.join(appDirPath, file.name);
        File(outputPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(file.content as List<int>);
      }
    }
  }

  // ==========================================================
  // دالة إصلاح المسارات الديناميكية (تدعم أي عدد من المجلدات)
  // ==========================================================

  Future<void> _fixImagePathsAfterRestore() async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileNameToPath = <String, String>{};

    // 💡 بدلاً من القائمة الثابتة، نبحث في كل المجلدات داخل التطبيق
    final allEntities = appDir.listSync(recursive: true);
    for (final entity in allEntities) {
      if (entity is File) {
        // نجمع كل ملفات الصور الموجودة في النسخة المستعادة
        final ext = p.extension(entity.path).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
          fileNameToPath[p.basename(entity.path)] = entity.path;
        }
      }
    }

    // قائمة صناديق Hive التي تحتوي على مسارات صور
    final boxNames = [
      'inkReports', 'finished_products', 'savedSheetSizes',
      'savedSheetSizes_production', 'maintenance_records_main',
      'maintenance_staple_v2', 'maintenance_flexo_v2',
      'maintenance_production_v2', 'maintenance_crushing_v2',
      'storeEntries' // أضفت هذا كمثال لمخازنك
    ];

    for (final boxName in boxNames) {
      try {
        if (!await Hive.boxExists(boxName)) continue;
        final box = await Hive.openBox(boxName);
        for (final key in box.keys) {
          final record = box.get(key);
          if (record is Map && record.containsKey('imagePaths')) {
            final List oldPaths = record['imagePaths'];
            final List<String> newPaths = [];
            bool changed = false;

            for (var oldPath in oldPaths) {
              final name = p.basename(oldPath.toString());
              if (fileNameToPath.containsKey(name)) {
                final newPath = fileNameToPath[name]!;
                newPaths.add(newPath);
                if (newPath != oldPath) changed = true;
              } else {
                newPaths.add(oldPath.toString());
              }
            }

            if (changed) {
              final updated = Map<String, dynamic>.from(record);
              updated['imagePaths'] = newPaths;
              await box.put(key, updated);
            }
          }
        }
        await box.close();
      } catch (e) {
        debugPrint('Error fixing $boxName: $e');
      }
    }
  }

  void dispose() {
    _uploadProgressController?.close();
  }
}
