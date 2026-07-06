// lib/services/server_time_service.dart
//
// خدمة الوقت الخادمي الموثوق (Server Time Service)
// المسؤولية: معالجة مشاكل التوقيت الصيفي (DST) وتلاعب العمال بساعات الهواتف
// عن طريق حساب وحفظ أوفست (Offset) للفرق بين التوقيت المحلي للجهاز وتوقيت خادم Supabase.
//

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/config/constants.dart';

class ServerTimeService {
  static final ServerTimeService instance = ServerTimeService._init();
  ServerTimeService._init();

  static const _storage = SafeSecureStorage();
  static const _offsetKey = 'server_time_offset_seconds';

  Duration _offset = Duration.zero;
  bool _isInitialized = false;

  /// الحصول على الوقت الحالي بالسحابة (UTC موثوق ودقيق ومقاوم لاختلاف التوقيت الصيفي وتلاعب الهواتف)
  static DateTime get nowUtc {
    return DateTime.now().toUtc().add(instance._offset);
  }

  /// الحصول على الوقت الحالي المحلي (المعوض عن فروقات أو أخطاء التوقيت الصيفي)
  static DateTime get nowLocal {
    return nowUtc.toLocal();
  }

  /// التهيئة الأولية واسترجاع الأوفست المحفوظ
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final savedOffsetStr = await _storage.read(key: _offsetKey);
      if (savedOffsetStr != null) {
        final seconds = int.tryParse(savedOffsetStr) ?? 0;
        _offset = Duration(seconds: seconds);
        debugPrint('⏱️ ServerTimeService: تم استرجاع Offset محفوظ = ${_offset.inSeconds} ثانية.');
      }
    } catch (e) {
      debugPrint('⚠️ ServerTimeService.init error: $e');
    }
    _isInitialized = true;
  }

  /// مزامنة وحساب الأوفست مع السحابة (عبر Supabase HTTP Header أو RPC)
  Future<void> syncServerTime() async {
    try {
      final before = DateTime.now().toUtc();
      DateTime? serverUtc;

      // 1. المحاولة الأولى: عبر REST API header لـ Supabase (سريع جداً ولا يحتاج RPC مخصص)
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final request = await client.headUrl(Uri.parse('$supabaseUrl/rest/v1/'));
        final response = await request.close();
        final dateHeader = response.headers.value(HttpHeaders.dateHeader);
        if (dateHeader != null && dateHeader.isNotEmpty) {
          serverUtc = HttpDate.parse(dateHeader).toUtc();
          debugPrint('🌐 ServerTimeService: تم جلب الوقت من Supabase HTTP Header: $serverUtc');
        }
      } catch (e) {
        debugPrint('⚠️ ServerTimeService HTTP header attempt failed: $e');
      }

      // 2. المحاولة الثانية: استعلام Supabase مباشر (RPC get_server_time إن وجد)
      if (serverUtc == null) {
        try {
          final res = await Supabase.instance.client.rpc('get_server_time');
          if (res != null) {
            serverUtc = DateTime.tryParse(res.toString())?.toUtc();
            debugPrint('🌐 ServerTimeService: تم جلب الوقت من RPC get_server_time: $serverUtc');
          }
        } catch (e) {
          // RPC might not exist, ignore
        }
      }

      // إذا نجحنا في الحصول على وقت الخادم
      if (serverUtc != null) {
        final after = DateTime.now().toUtc();
        final latency = after.difference(before) ~/ 2;
        final exactServerUtc = serverUtc.add(latency);

        _offset = exactServerUtc.difference(after);
        await _storage.write(key: _offsetKey, value: _offset.inSeconds.toString());
        debugPrint('✅ ServerTimeService: تم التحديث بنجاح! Offset = ${_offset.inSeconds} ثانية (فارق: ${_offset.inMinutes} دقيقة).');
      } else {
        debugPrint('⚠️ ServerTimeService: تعذر جلب وقت الخادم، الاعتماد على التوقيت الحالي أو الأوفست المحفوظ.');
      }
    } catch (e) {
      debugPrint('❌ ServerTimeService.syncServerTime error: $e');
    }
  }
}
