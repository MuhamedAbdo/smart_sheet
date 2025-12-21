import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static final _supabase = Supabase.instance.client;

  /// دالة لرفع صورة واحدة وإعادة الرابط المباشر لها
  static Future<String?> uploadImage(
      String localPath, String bucketName) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;

      // إنشاء اسم فريد للملف لتجنب التكرار
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(localPath)}';
      final pathInBucket = 'uploads/$fileName';

      // 1. رفع الملف إلى Supabase Storage
      await _supabase.storage.from(bucketName).upload(
            pathInBucket,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      // 2. الحصول على الرابط العام (Public URL)
      final String publicUrl =
          _supabase.storage.from(bucketName).getPublicUrl(pathInBucket);

      return publicUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  /// دالة لرفع قائمة صور كاملة
  static Future<List<String>> uploadMultipleImages(
      List<String> localPaths, String bucketName) async {
    List<String> uploadedUrls = [];
    for (String path in localPaths) {
      // إذا كان الرابط يبدأ بـ http فهو مرفوع مسبقاً، لا داعي لرفعه ثانية
      if (path.startsWith('http')) {
        uploadedUrls.add(path);
        continue;
      }

      String? url = await uploadImage(path, bucketName);
      if (url != null) uploadedUrls.add(url);
    }
    return uploadedUrls;
  }
}
