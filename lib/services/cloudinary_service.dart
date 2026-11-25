import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// كائن يعبر عن حالة وتقدم عملية الترحيل لحظياً
class MigrationProgress {
  final int totalRecords;
  final int processedRecords;
  final int totalImages;
  final int scannedImages;
  final int migratedImages;
  final int skippedImages;
  final int failedImages;
  final String currentStatus;
  final bool isCompleted;
  final String? errorMessage;

  const MigrationProgress({
    this.totalRecords = 0,
    this.processedRecords = 0,
    this.totalImages = 0,
    this.scannedImages = 0,
    this.migratedImages = 0,
    this.skippedImages = 0,
    this.failedImages = 0,
    this.currentStatus = '',
    this.isCompleted = false,
    this.errorMessage,
  });
}

class CloudinaryService {
  static const String _cloudName = 'f0yihpiy';
  static const String _uploadPreset = 'smart_sheet_preset';
  static const String _endpoint =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// ضغط وتحويل الصورة محلياً إلى صيغة WebP بأبعاد وجودة مناسبة
  /// (الحد الأدنى للأبعاد 1080x1080 وجودة 80)
  static Future<File?> compressToWebP(
    File file, {
    int minWidth = 1080,
    int minHeight = 1080,
    int quality = 80,
  }) async {
    try {
      if (!await file.exists()) return null;

      final tempDir = await getTemporaryDirectory();
      final uniqueId = const Uuid().v4();
      final targetPath =
          '${tempDir.path}/webp_${DateTime.now().millisecondsSinceEpoch}_$uniqueId.webp';

      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        format: CompressFormat.webp,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );

      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);
        if (await compressedFile.exists()) {
          debugPrint(
              '🗜️ [Cloudinary] تم ضغط وتحويل الصورة إلى WebP بنجاح: ${compressedFile.path}');
          return compressedFile;
        }
      }
      return null;
    } catch (e) {
      debugPrint(
          '⚠️ [Cloudinary] فشل ضغط الصورة: $e — سيتم استخدام الأصلية كبديل آمن.');
      return null;
    }
  }

  /// رفع صورة واحدة إلى Cloudinary مع عزل مجلدات المصانع (factory_id)
  /// ويقوم بضغطها وتحويلها إلى WebP مسبقاً مع الرجوع للأصلية عند الفشل
  static Future<String?> uploadImage(
    File imageFile, {
    required String factoryId,
    bool compress = true,
  }) async {
    File? tempCompressedFile;
    try {
      if (!await imageFile.exists()) {
        debugPrint('⚠️ [Cloudinary] الملف غير موجود: ${imageFile.path}');
        return null;
      }

      // 1. محاولة ضغط وتحويل الصورة إلى WebP محلياً
      File fileToUpload = imageFile;
      if (compress) {
        final compressed = await compressToWebP(imageFile);
        if (compressed != null && await compressed.exists()) {
          fileToUpload = compressed;
          tempCompressedFile = compressed;
        }
      }

      final safeFactoryId =
          factoryId.trim().isEmpty ? 'default' : factoryId.trim();
      final uri = Uri.parse(_endpoint);
      final request = http.MultipartRequest('POST', uri);

      // الحقول المطلوبة لـ Cloudinary
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smart_sheet/$safeFactoryId';

      // إضافة ملف الصورة
      final multipartFile =
          await http.MultipartFile.fromPath('file', fileToUpload.path);
      request.files.add(multipartFile);

      // إرسال الطلب مع مهلة 30 ثانية
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        debugPrint('✅ [Cloudinary] تم رفع الصورة بنجاح: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
            '❌ [Cloudinary] فشل الرفع (كود ${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [Cloudinary] خطأ أثناء رفع الصورة: $e');
      return null;
    } finally {
      // تنظيف الملف المؤقت
      if (tempCompressedFile != null &&
          tempCompressedFile.path != imageFile.path) {
        try {
          if (await tempCompressedFile.exists()) {
            await tempCompressedFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  /// ميزة للترحيل: سحب صورة من رابط، ضغطها وتحويلها إلى WebP، ثم رفعها إلى Cloudinary
  /// مع الرجوع للسحب المباشر عند فشل التنزيل أو الضغط كبديل آمن
  static Future<String?> uploadImageFromUrl(
    String imageUrl, {
    required String factoryId,
    bool compress = true,
  }) async {
    try {
      if (imageUrl.trim().isEmpty) return null;

      final safeFactoryId =
          factoryId.trim().isEmpty ? 'default' : factoryId.trim();

      // إذا كان الضغط مفعلاً، نقوم بتنزيل الصورة وضغطها إلى WebP أولاً
      if (compress) {
        try {
          final res = await http
              .get(Uri.parse(imageUrl.trim()))
              .timeout(const Duration(seconds: 30));

          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final uniqueId = const Uuid().v4();
            final tempPath =
                '${tempDir.path}/raw_${DateTime.now().millisecondsSinceEpoch}_$uniqueId.jpg';
            final tempFile = File(tempPath);
            await tempFile.writeAsBytes(res.bodyBytes);

            final uploadedUrl = await uploadImage(
              tempFile,
              factoryId: safeFactoryId,
              compress: true,
            );

            try {
              if (await tempFile.exists()) await tempFile.delete();
            } catch (_) {}

            if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
              return uploadedUrl;
            }
          }
        } catch (downloadOrCompressError) {
          debugPrint(
              '⚠️ [Cloudinary] تعذر ضغط الصورة من الرابط محلياً ($downloadOrCompressError) — سيتم الرفع المباشر كبديل آمن.');
        }
      }

      // بديل آمن: إرسال الرابط مباشرة لـ Cloudinary
      final uri = Uri.parse(_endpoint);
      final request = http.MultipartRequest('POST', uri);

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = 'smart_sheet/$safeFactoryId';
      request.fields['file'] = imageUrl.trim();

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final secureUrl = data['secure_url'] as String?;
        debugPrint(
            '✅ [Cloudinary] تم استيراد الصورة من الرابط بنجاح: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
            '❌ [Cloudinary] فشل استيراد الصورة من الرابط (كود ${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [Cloudinary] خطأ أثناء استيراد الصورة من الرابط: $e');
      return null;
    }
  }

  /// دالة مساعدة لرفع عدة صور بالتوازي مع الحفاظ على الروابط الموجودة مسبقاً
  static Future<List<String>> uploadMultipleImages(
    List<dynamic> images, {
    required String factoryId,
  }) async {
    final uploadTasks = images.map((item) async {
      // إذا كان الرابط يبدأ بـ http فهو مرفوع مسبقاً، نحتفظ به كما هو
      if (item is String && item.startsWith('http')) {
        return item;
      }

      File? file;
      if (item is File) {
        file = item;
      } else if (item is String) {
        file = File(item);
      }

      if (file != null && await file.exists()) {
        return await uploadImage(file, factoryId: factoryId, compress: true);
      }

      return null;
    }).toList();

    final results = await Future.wait(uploadTasks);
    return results.whereType<String>().toList();
  }

  /// ترحيل وتحديث صور المصنع الحالي إلى صيغة WebP بأمان
  /// (يسحب الصور من Cloudinary أو Supabase أو الملفات المحلية، يضغطها لـ WebP ويرفعها)
  static Future<void> migrateFactoryImages({
    required String factoryId,
    required void Function(MigrationProgress) onProgress,
  }) async {
    try {
      final safeFactoryId = factoryId.trim();
      if (safeFactoryId.isEmpty) {
        onProgress(const MigrationProgress(
          isCompleted: true,
          errorMessage: 'معرف المصنع (factory_id) غير صالح أو فارغ.',
        ));
        return;
      }

      onProgress(const MigrationProgress(
        currentStatus: 'جاري جلب سجلات العملاء والمنتجات من قاعدة البيانات...',
      ));

      // 1. جلب سجلات جدول customers التابعة لهذا المصنع
      final response = await Supabase.instance.client
          .from('customers')
          .select('id, sync_id, client_name, product_name, image_paths')
          .eq('factory_id', safeFactoryId);

      final List<Map<String, dynamic>> recordsWithImages = [];
      int totalImages = 0;

      for (final raw in response) {
        List<dynamic> imgList = [];
        final rawImg = raw['image_paths'];
        if (rawImg is List) {
          imgList = rawImg;
        } else if (rawImg is String && rawImg.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawImg);
            if (decoded is List) imgList = decoded;
          } catch (_) {
            imgList = [rawImg.trim()];
          }
        }

        if (imgList.isNotEmpty) {
          final recordMap = Map<String, dynamic>.from(raw);
          recordMap['image_paths'] = imgList;
          recordsWithImages.add(recordMap);
          totalImages += imgList.length;
        }
      }

      if (recordsWithImages.isEmpty || totalImages == 0) {
        onProgress(MigrationProgress(
          totalRecords: 0,
          totalImages: 0,
          currentStatus:
              'لا توجد صور بحاجة إلى ترحيل للمصنع الحالي ($safeFactoryId).',
          isCompleted: true,
        ));
        return;
      }

      int scanned = 0;
      int migrated = 0;
      int skipped = 0;
      int failed = 0;
      int processedRecords = 0;

      // تخزين مؤقت للروابط التي تم إعادة رفعها في نفس الجلسة لتجنب تكرار الرفع
      final Map<String, String> reuploadedCache = {};
      // قائمة الروابط الميتة (404) التي تم اكتشافها لتجنب تكرار فحصها
      final Set<String> deadUrls = {};

      Box? savedSheetSizesBox;
      try {
        savedSheetSizesBox = Hive.isBoxOpen('savedSheetSizes')
            ? Hive.box('savedSheetSizes')
            : await Hive.openBox('savedSheetSizes');
      } catch (e) {
        debugPrint('⚠️ [Migration] تعذر فتح Hive box savedSheetSizes: $e');
      }

      for (final record in recordsWithImages) {
        final clientName = record['client_name']?.toString() ?? '';
        final productName = record['product_name']?.toString() ?? '';
        final rawList = record['image_paths'] as List;
        final List<String> currentPaths =
            rawList.map((e) => e.toString()).toList();
        final List<String> updatedPaths = [];
        bool recordChanged = false;

        for (final rawPath in currentPaths) {
          final path = rawPath.trim();
          if (path.isEmpty) continue;
          scanned++;

          // فحص مسار الرابط النظيف (بدون معلمات الاستعلام إن وجدت)
          final cleanPath = path.split('?').first.split('#').first;

          // إذا كان الرابط يبدأ بـ https://res.cloudinary.com/ وينتهي بـ .webp،
          // يتم تخطيه فوراً واحتسابه ضمن الصور الجاهزة (skippedImages++ / WebP مسبقاً) دون إعادة تحميله أو رفعه.
          final isCloudinaryWebp =
              (cleanPath.startsWith('https://res.cloudinary.com/') ||
                      cleanPath.startsWith('http://res.cloudinary.com/')) &&
                  cleanPath.toLowerCase().endsWith('.webp');

          final isCloudinaryUrl = path.contains('res.cloudinary.com');
          final isSupabaseUrl = path.contains('supabase.co');
          final isOtherAlreadyWebp = !isCloudinaryUrl &&
              !isSupabaseUrl &&
              cleanPath.toLowerCase().endsWith('.webp');

          if (isCloudinaryWebp || isOtherAlreadyWebp) {
            // ✅ صورة جاهزة بصيغة WebP مسبقاً (سواء على Cloudinary أو خارجية) ← تخطي واحتفاظ بها دون إعادة تحميل أو رفع
            updatedPaths.add(path);
            skipped++;
            onProgress(MigrationProgress(
              totalRecords: recordsWithImages.length,
              processedRecords: processedRecords,
              totalImages: totalImages,
              scannedImages: scanned,
              migratedImages: migrated,
              skippedImages: skipped,
              failedImages: failed,
              currentStatus: isCloudinaryWebp
                  ? 'تم تخطي صورة WebP تابعة لـ Cloudinary مسبقاً ($clientName)...'
                  : 'تم تخطي صورة بصيغة WebP مسبقاً ($clientName)...',
            ));
          } else if (path.startsWith('http')) {
            // 🔄 صورة موجودة على Cloudinary أو Supabase
            onProgress(MigrationProgress(
              totalRecords: recordsWithImages.length,
              processedRecords: processedRecords,
              totalImages: totalImages,
              scannedImages: scanned,
              migratedImages: migrated,
              skippedImages: skipped,
              failedImages: failed,
              currentStatus: isCloudinaryUrl
                  ? 'جاري فحص وإعادة رفع صورة Cloudinary ($clientName - $productName)...'
                  : 'جاري سحب وضغط الصورة إلى WebP ($clientName - $productName)...',
            ));

            if (isCloudinaryUrl) {
              // 1. إذا كان الرابط معروفاً مسبقاً بأنه يرجع 404 أو تعذر تحميله، نتخطاه ونتركه في السجل دون حذفه
              if (deadUrls.contains(path)) {
                debugPrint(
                    '⚠️ [Migration] رابط Cloudinary فشل سابقاً (404) تم تركه في السجل دون حذف: $path');
                failed++;
                updatedPaths.add(path);
                onProgress(MigrationProgress(
                  totalRecords: recordsWithImages.length,
                  processedRecords: processedRecords,
                  totalImages: totalImages,
                  scannedImages: scanned,
                  migratedImages: migrated,
                  skippedImages: skipped,
                  failedImages: failed,
                  currentStatus:
                      'تعذر تحميل رابط سابقاً (404)، تم تركه في سجل ($clientName - $productName)...',
                ));
                continue;
              }

              // 2. إذا كان الرابط تم إعادة رفعه بالفعل في نفس الجلسة
              if (reuploadedCache.containsKey(path)) {
                final cachedUrl = reuploadedCache[path]!;
                updatedPaths.add(cachedUrl);
                migrated++;
                recordChanged = true;
                continue;
              }

              // 3. فحص الرابط والتأكد مما إذا كان يرجع 404 (Resource not found)
              bool is404 = false;
              http.Response? checkRes;
              try {
                checkRes = await http
                    .get(Uri.parse(path))
                    .timeout(const Duration(seconds: 15));
                if (checkRes.statusCode == 404 ||
                    (checkRes.statusCode >= 400 &&
                        checkRes.body.contains('Resource not found'))) {
                  is404 = true;
                }
              } catch (e) {
                debugPrint('⚠️ [Migration] خطأ أثناء فحص الرابط: $e');
              }

              if (is404) {
                debugPrint(
                    '⚠️ [Migration] رابط Cloudinary يرجع 404 (Resource not found): $path — تم تركه في السجل واحتسابه كفاشل دون حذفه');
                deadUrls.add(path);
                failed++;
                updatedPaths.add(path); // نتركه في السجل كما هو دون حذفه
                onProgress(MigrationProgress(
                  totalRecords: recordsWithImages.length,
                  processedRecords: processedRecords,
                  totalImages: totalImages,
                  scannedImages: scanned,
                  migratedImages: migrated,
                  skippedImages: skipped,
                  failedImages: failed,
                  currentStatus:
                      'فشل رابط (404) وتم تركه في سجل ($clientName - $productName)...',
                ));
                continue; // ننتقل للرابط التالي مع الاحتفاظ بالرابط الحالي في updatedPaths
              }

              // 4. إذا كانت الصورة متوفرة وتم تحميلها بنجاح (كود 200)
              if (checkRes != null &&
                  checkRes.statusCode == 200 &&
                  checkRes.bodyBytes.isNotEmpty) {
                try {
                  final tempDir = await getTemporaryDirectory();
                  final uniqueId = const Uuid().v4();
                  final tempPath =
                      '${tempDir.path}/raw_${DateTime.now().millisecondsSinceEpoch}_$uniqueId.jpg';
                  final tempFile = File(tempPath);
                  await tempFile.writeAsBytes(checkRes.bodyBytes);

                  final newUrl = await uploadImage(
                    tempFile,
                    factoryId: safeFactoryId,
                    compress: true,
                  );

                  try {
                    if (await tempFile.exists()) await tempFile.delete();
                  } catch (_) {}

                  if (newUrl != null && newUrl.isNotEmpty) {
                    reuploadedCache[path] = newUrl;
                    updatedPaths.add(newUrl);
                    migrated++;
                    recordChanged = true;
                  } else {
                    updatedPaths.add(path);
                    failed++;
                  }
                } catch (e) {
                  debugPrint('❌ فشل رفع/تحويل صورة من الرابط: $e');
                  updatedPaths.add(path);
                  failed++;
                }
              } else {
                // فشل التنزيل لسبب آخر غير 404
                try {
                  final newUrl = await uploadImageFromUrl(
                    path,
                    factoryId: safeFactoryId,
                    compress: true,
                  );
                  if (newUrl != null && newUrl.isNotEmpty) {
                    reuploadedCache[path] = newUrl;
                    updatedPaths.add(newUrl);
                    migrated++;
                    recordChanged = true;
                  } else {
                    updatedPaths.add(path);
                    failed++;
                  }
                } catch (e) {
                  debugPrint('❌ فشل تحويل صورة من الرابط: $e');
                  updatedPaths.add(path);
                  failed++;
                }
              }
            } else {
              // رابط خارجي آخر (مثل Supabase Storage)
              try {
                String? newUrl;
                if (reuploadedCache.containsKey(path)) {
                  newUrl = reuploadedCache[path];
                } else {
                  newUrl = await uploadImageFromUrl(
                    path,
                    factoryId: safeFactoryId,
                    compress: true,
                  );
                  if (newUrl != null && newUrl.isNotEmpty) {
                    reuploadedCache[path] = newUrl;
                  }
                }

                if (newUrl != null && newUrl.isNotEmpty) {
                  updatedPaths.add(newUrl);
                  migrated++;
                  recordChanged = true;
                } else {
                  updatedPaths.add(path);
                  failed++;
                }
              } catch (e) {
                debugPrint('❌ فشل تحويل صورة من الرابط: $e');
                updatedPaths.add(path);
                failed++;
              }
            }

            // تأخير 200ms لتجنب الضغط والـ Rate Limit
            await Future.delayed(const Duration(milliseconds: 200));
          } else if (File(path).existsSync()) {
            // 📁 مسار محلي لملف موجود فعلياً على الجهاز
            onProgress(MigrationProgress(
              totalRecords: recordsWithImages.length,
              processedRecords: processedRecords,
              totalImages: totalImages,
              scannedImages: scanned,
              migratedImages: migrated,
              skippedImages: skipped,
              failedImages: failed,
              currentStatus:
                  'جاري ضغط ورفع ملف محلي إلى WebP ($clientName - $productName)...',
            ));

            try {
              final newUrl = await uploadImage(
                File(path),
                factoryId: safeFactoryId,
                compress: true,
              );
              if (newUrl != null && newUrl.isNotEmpty) {
                updatedPaths.add(newUrl);
                migrated++;
                recordChanged = true;
              } else {
                updatedPaths.add(path);
                failed++;
              }
            } catch (e) {
              debugPrint('❌ فشل رفع ملف محلي: $e');
              updatedPaths.add(path);
              failed++;
            }

            await Future.delayed(const Duration(milliseconds: 200));
          } else {
            // مسار مجهول أو غير موجود
            updatedPaths.add(path);
            skipped++;
          }

          onProgress(MigrationProgress(
            totalRecords: recordsWithImages.length,
            processedRecords: processedRecords,
            totalImages: totalImages,
            scannedImages: scanned,
            migratedImages: migrated,
            skippedImages: skipped,
            failedImages: failed,
            currentStatus: 'جاري فحص الصور ($scanned / $totalImages)...',
          ));
        }

        // تحديث Supabase و Hive فوراً إذا تغيرت أي صورة في السجل إلى WebP
        if (recordChanged) {
          final recordId = record['id'];
          final syncId = record['sync_id']?.toString();

          // 1. تحديث Supabase
          try {
            if (recordId != null) {
              await Supabase.instance.client
                  .from('customers')
                  .update({'image_paths': updatedPaths}).eq('id', recordId);
            } else if (syncId != null) {
              await Supabase.instance.client
                  .from('customers')
                  .update({'image_paths': updatedPaths}).eq('sync_id', syncId);
            }
          } catch (e) {
            debugPrint(
                '❌ [Migration] خطأ أثناء تحديث Supabase للسجل $recordId: $e');
          }

          // 2. تحديث Hive محلياً
          if (savedSheetSizesBox != null) {
            try {
              for (var i = 0; i < savedSheetSizesBox.length; i++) {
                final item = savedSheetSizesBox.getAt(i);
                if (item is Map) {
                  final itemSyncId = item['sync_id']?.toString();
                  final itemId = item['id']?.toString();
                  final itemClient = (item['clientName'] ?? item['client_name'])
                      ?.toString()
                      .trim();
                  final itemProduct =
                      (item['productName'] ?? item['product_name'])
                          ?.toString()
                          .trim();

                  final bool idMatch =
                      (syncId != null && itemSyncId == syncId) ||
                          (recordId != null &&
                              (itemId == recordId.toString() ||
                                  itemSyncId == recordId.toString()));
                  final bool nameMatch = clientName.isNotEmpty &&
                      productName.isNotEmpty &&
                      itemClient == clientName.trim() &&
                      itemProduct == productName.trim();

                  if (idMatch || nameMatch) {
                    final updatedMap = Map<String, dynamic>.from(item);
                    updatedMap['imagePaths'] = updatedPaths;
                    updatedMap['image_paths'] = updatedPaths;
                    await savedSheetSizesBox.putAt(i, updatedMap);
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint('❌ [Migration] خطأ أثناء تحديث Hive: $e');
            }
          }
        }

        processedRecords++;
        onProgress(MigrationProgress(
          totalRecords: recordsWithImages.length,
          processedRecords: processedRecords,
          totalImages: totalImages,
          scannedImages: scanned,
          migratedImages: migrated,
          skippedImages: skipped,
          failedImages: failed,
          currentStatus:
              'تمت معالجة سجل $clientName ($processedRecords / ${recordsWithImages.length})',
        ));
      }

      onProgress(MigrationProgress(
        totalRecords: recordsWithImages.length,
        processedRecords: recordsWithImages.length,
        totalImages: totalImages,
        scannedImages: scanned,
        migratedImages: migrated,
        skippedImages: skipped,
        failedImages: failed,
        currentStatus: 'اكتملت عملية ترحيل وتحديث الصور إلى WebP بنجاح!',
        isCompleted: true,
      ));
    } catch (e) {
      debugPrint('❌ [Migration] خطأ عام أثناء الترحيل: $e');
      onProgress(MigrationProgress(
        isCompleted: true,
        errorMessage: 'حدث خطأ أثناء الترحيل: $e',
      ));
    }
  }
}
