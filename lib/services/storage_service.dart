import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final _supabase = Supabase.instance.client;

  /// رفع صورة واحدة
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

  /// ⚡ رفع قائمة صور كاملة بشكل متوازي (أسرع بكثير)
  static Future<List<String>> uploadMultipleImages(
      List<String> localPaths, String bucketName) async {
    // تشغيل جميع عمليات الرفع في وقت واحد
    final uploadTasks = localPaths.map((path) async {
      if (path.startsWith('http')) return path;
      return await uploadImage(path, bucketName);
    }).toList();

    // انتظار انتهاء جميع العمليات معاً
    final results = await Future.wait(uploadTasks);

    // إرجاع الروابط التي نجح رفعها فقط
    return results.whereType<String>().toList();
  }
}
