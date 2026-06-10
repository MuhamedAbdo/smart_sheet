import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CacheHelper {
  static String? _cacheDirPath;
  static final Map<String, Future<File?>> _activeDownloads = {};

  // ─── تهيئة عند بدء التطبيق ──────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await _getCacheDirectory();
      // استخدام print بدلاً من debugPrint لضمان الظهور في logcat دائماً
      // ignore: avoid_print
      print('✅✅✅ [CacheHelper] INIT OK → dir: $_cacheDirPath');
    } catch (e) {
      // ignore: avoid_print
      print('❌❌❌ [CacheHelper] INIT FAILED: $e');
    }
  }

  // ─── توليد اسم الملف (DJB2 hash مستقر) ─────────────────────

  static String _generateFileName(String url) {
    final urlWithoutQuery = url.split('?').first;

    int hash = 5381;
    for (int i = 0; i < urlWithoutQuery.length; i++) {
      hash = ((hash << 5) + hash) + urlWithoutQuery.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF;
    }
    final hashStr = hash.toRadixString(16);

    final bytes = utf8.encode(urlWithoutQuery);
    final base64Str = base64Url.encode(bytes).replaceAll('=', '');
    final safeBase64 =
        base64Str.length > 80 ? base64Str.substring(base64Str.length - 80) : base64Str;
    final extension = p.extension(urlWithoutQuery);

    return '${hashStr}_$safeBase64${extension.isEmpty ? '.jpg' : extension}';
  }

  // ─── مجلد الكاش (مخزَّن في الذاكرة بعد أول استدعاء) ─────────

  static Future<Directory> _getCacheDirectory() async {
    if (_cacheDirPath != null) return Directory(_cacheDirPath!);
    // getApplicationDocumentsDirectory يُرجع Context.getFilesDir() على أندرويد
    // ← نفس المسار الذي كانت تعمل به النسخ السابقة
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(appDir.path, 'smart_sheet_cache'));
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    _cacheDirPath = cacheDir.path;
    return cacheDir;
  }

  // ─── فحص متزامن فوري (0ms) ──────────────────────────────────

  static File? getLocalCachedImageSync(String url) {
    if (kIsWeb || _cacheDirPath == null) return null;
    final file = File(p.join(_cacheDirPath!, _generateFileName(url)));
    if (file.existsSync() && file.lengthSync() > 1024) {
      // ignore: avoid_print
      print('🎯🎯🎯 [CacheHelper] CACHE HIT (sync): ${file.path}');
      return file;
    }
    return null;
  }

  // ─── تحميل + كاش (مع منع التكرار المتوازي) ─────────────────

  static Future<File?> getLocalCachedImage(String url) {
    if (kIsWeb) return Future.value(null);
    if (_activeDownloads.containsKey(url)) return _activeDownloads[url]!;
    final future = _downloadAndCache(url);
    _activeDownloads[url] = future;
    future.whenComplete(() => _activeDownloads.remove(url));
    return future;
  }

  /// التحميل الفعلي والحفظ على القرص
  ///
  /// يستخدم http.Client().send() بدلاً من http.get() لأنه:
  /// - يُبث البيانات chunk-by-chunk (لا يُحمّل RAM)
  /// - يتبع الـ redirects تلقائياً (مهم لـ Supabase signed URLs)
  /// - يتعامل مع SSL بشكل صحيح
  ///
  /// يكتب مباشرةً للملف النهائي بـ IOSink بدون rename()
  static Future<File?> _downloadAndCache(String url) async {
    final cacheDir = await _getCacheDirectory();
    final fileName = _generateFileName(url);
    final file = File(p.join(cacheDir.path, fileName));

    // فحص الكاش الموجود
    if (file.existsSync() && file.lengthSync() > 1024) {
      // ignore: avoid_print
      print('🎯🎯🎯 [CacheHelper] CACHE HIT (async): $fileName');
      return file;
    }

    // حذف أي ملف تالف
    if (file.existsSync()) await file.delete();

    final sw = Stopwatch()..start();
    http.Client? client;
    IOSink? sink;

    try {
      // ignore: avoid_print
      print('📥📥📥 [CacheHelper] START DOWNLOAD: $url');

      client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      // ignore: avoid_print
      print('📥📥📥 [CacheHelper] HTTP ${streamedResponse.statusCode} | '
          'Content-Length: ${streamedResponse.contentLength}');

      if (streamedResponse.statusCode != 200) {
        // ignore: avoid_print
        print('❌❌❌ [CacheHelper] HTTP ERROR: ${streamedResponse.statusCode}');
        client.close();
        return null;
      }

      // كتابة streaming مباشرةً للملف النهائي بدون rename()
      sink = file.openWrite();
      int totalBytes = 0;

      await for (final List<int> chunk in streamedResponse.stream) {
        sink.add(chunk); // non-blocking: يُضاف للـ buffer الداخلي
        totalBytes += chunk.length;
      }

      await sink.flush();
      await sink.close();
      sink = null;
      client.close();
      client = null;

      sw.stop();

      // تحقق من نجاح الحفظ
      final savedLen = file.existsSync() ? file.lengthSync() : 0;
      if (savedLen < 1024) {
        // ignore: avoid_print
        print('❌❌❌ [CacheHelper] SAVE FAILED: file too small ($savedLen bytes)');
        if (file.existsSync()) await file.delete();
        return null;
      }

      // ignore: avoid_print
      print('✅✅✅ [CacheHelper] SAVED OK: $totalBytes bytes in '
          '${sw.elapsedMilliseconds}ms → $fileName');
      return file;
    } catch (e, st) {
      // ignore: avoid_print
      print('❌❌❌ [CacheHelper] EXCEPTION: $e\n$st');
      try {
        await sink?.close();
        client?.close();
        if (file.existsSync() && file.lengthSync() < 1024) await file.delete();
      } catch (_) {}
      return null;
    }
  }

  // ─── حذف من الكاش عند حذف الملف ────────────────────────────

  static Future<void> deleteImageCache(String url) async {
    if (kIsWeb) return;
    try {
      final cacheDir = await _getCacheDirectory();
      final file = File(p.join(cacheDir.path, _generateFileName(url)));
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ [CacheHelper] Deleted: ${file.path}');
      }
    } catch (e) {
      debugPrint('❌ [CacheHelper] Delete error: $e');
    }
  }
}
