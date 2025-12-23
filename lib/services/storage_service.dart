import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final _supabase = Supabase.instance.client;

  /// رفع صورة واحدة إلى Supabase
  static Future<String?> uploadImage(
      String localPath, String bucketName) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath)}';
      final pathInBucket = 'uploads/$fileName';

      await _supabase.storage.from(bucketName).upload(
            pathInBucket,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return _supabase.storage.from(bucketName).getPublicUrl(pathInBucket);
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  /// رفع الصور الجديدة فقط وتجاهل الروابط الموجودة مسبقاً
  static Future<List<String>> uploadMultipleImages(
      List<String> localPaths, String bucketName) async {
    final uploadTasks = localPaths.map((path) async {
      // إذا كان المسار يبدأ بـ http فهو مرفوع مسبقاً، نعيده كما هو
      if (path.startsWith('http')) return path;

      // إذا كان مسار محلي، نقوم برفعه
      return await uploadImage(path, bucketName);
    }).toList();

    final results = await Future.wait(uploadTasks);

    // تصفية النتائج من أي قيم فارغة (التي فشل رفعها)
    return results.whereType<String>().toList();
  }
}
