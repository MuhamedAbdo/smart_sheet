// lib/utils/image_utils.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// يحفظ الصورة في مجلد دائم داخل التطبيق (قابل للنسخ الاحتياطي)
Future<String> saveImagePermanently(File imageFile) async {
  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory(p.join(appDir.path, 'app_images'));
  await imageDir.create(recursive: true);

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final ext = p.extension(imageFile.path);
  final newFileName = 'img_$timestamp$ext';
  final newPath = p.join(imageDir.path, newFileName);

  final newFile = await imageFile.copy(newPath);
  return newFile.path;
}
