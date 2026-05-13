// lib/services/sync_service.dart
//
// نظام المزامنة المركزي – Offline-First + Supabase Real-time
//
// الجداول المُزامَنة:
//   customers          ↔ savedSheetSizes  (Box)
//   production_reports ↔ inkReports       (Box)
//   workers            ↔ workers          (Box<Worker>)

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/realtime_sync_manager.dart';

class SyncService {
  static SyncService? _instance;

  // ✅ متغير static يبقى حتى بعد reset() لمنع إعادة التهيئة عن طريق الحدث النظام
  static bool _wasUnlinked = false;

  factory SyncService() {
    _instance ??= SyncService._internal();
    return _instance!;
  }
  SyncService._internal();

  // ✅ آمن: لا يرمي Null error بعد reset()
  static SyncService? get instanceOrNull => _instance;

  // احتفظنا به للتوافقية مع الكود القديم لكن بشكل آمن
  static SyncService get instance {
    if (_instance == null) {
      throw StateError('SyncService has been reset. Call SyncService() to create a new instance.');
    }
    return _instance!;
  }

  static void reset() {
    _instance = null;
    // ❗ لا نعيد _wasUnlinked إلى false هنا، سيتم إعادة تعيينه فقط عند الربط بمصنع جديد
  }

  // ✅ إعادة ضبط كامل (isUnlinked + instance) عند الربط بمصنع جديد
  static void resetForNewLink() {
    _wasUnlinked = false;
    _instance = null;
  }

  // صحيح: يمنع أي تهيئة حتى بعد reset()
  static bool get isUnlinked => _wasUnlinked || (_instance?._isUnlinked ?? false);

  /// Safe method to mark as unlinked without throwing errors
  static Future<void> safeMarkAsUnlinked() async {
    _wasUnlinked = true; // ✅ تسجيل على المستوى الثابت أولاً
    if (_instance != null) {
      try {
        await _instance!.markAsUnlinked();
      } catch (e) {
        debugPrint('⚠️ Error in safeMarkAsUnlinked: $e');
      }
    }
  }

  bool _isUnlinked = false;

  // Store all subscriptions to cancel them properly
  StreamSubscription? _authSubscription;
  final List<StreamSubscription> _additionalSubscriptions = [];

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeSyncManager? _realtimeManager;

  Box? _queueBox;
  bool _isProcessingQueue = false;

  // ==============================================================
  // Public API
  // ==============================================================

  Future<void> initialize() async {
    try {
      // منع إعادة التهيئة بعد فك الارتباط
      if (_isUnlinked) {
        debugPrint('🚫 SyncService: تم فك الارتباط، لا يمكن إعادة التهيئة');
        return;
      }

      _queueBox = Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');

      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        debugPrint('⏳ SyncService: لا يوجد factory_id، ينتظر تسجيل الدخول.');
        return;
      }

      await _tearDownRealtime();
      _realtimeManager = RealtimeSyncManager(factoryId: factoryId);
      _realtimeManager!.initialize();
      
      unawaited(_processQueue());

      debugPrint('✅ SyncService: تم التهيئة للمصنع: $factoryId');
    } catch (e) {
      debugPrint('❌ SyncService.initialize: $e');
    }
  }

  Future<void> dispose() async {
    // إلغاء جميع الاشتراكات
    await _cancelAllSubscriptions();

    // إغلاق قنوات المزامنة الفورية
    await _tearDownRealtime();

    // إغلاق صندوق قائمة الانتظار
    if (_queueBox != null && _queueBox!.isOpen) {
      await _queueBox!.close();
      _queueBox = null;
    }

    debugPrint('🔄 SyncService: تم الإغلاق الكامل.');
  }

  Future<void> _cancelAllSubscriptions() async {
    try {
      // إلغاء اشتراك المصادقة
      if (_authSubscription != null) {
        await _authSubscription!.cancel();
        _authSubscription = null;
      }

      // إلغاء جميع الاشتراكات الإضافية
      for (final subscription in _additionalSubscriptions) {
        await subscription.cancel();
      }
      _additionalSubscriptions.clear();

      debugPrint('🚫 SyncService: تم إلغاء جميع الاشتراكات');
    } catch (e) {
      debugPrint('❌ Error cancelling subscriptions: $e');
    }
  }

  /// استدعاء هذه الطريقة عند فك الارتباط لمنع إعادة التهيئة
  Future<void> markAsUnlinked() async {
    _isUnlinked = true;

    // إيقاف جميع العمليات
    await dispose();

    debugPrint('🚫 SyncService: تم وضع علامة فك الارتباط وإيقاف جميع العمليات');
  }

  /// إعادة تعيين حالة فك الارتباط (للاستخدام عند إعادة الربط)
  void resetUnlinkStatus() {
    _isUnlinked = false;
    _wasUnlinked = false; // ✅ أيضاً مسح المتغير الثابت
    debugPrint('✅ SyncService: تم إعادة تعيين حالة فك الارتباط');
  }

  Future<void> pushToQueue(
    String table,
    Map<String, dynamic> data, {
    String operation = 'upsert',
  }) async {
    try {
      _queueBox ??= Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');

      await _queueBox!.add({
        'table': table,
        'data': Map<String, dynamic>.from(data),
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String(),
        'retries': 0,
      });

      debugPrint('📤 Queue → $table [$operation]');
      unawaited(_processQueue());
    } catch (e) {
      debugPrint('❌ SyncService.pushToQueue: $e');
    }
  }

  // ==============================================================
  // Real-time Channel Setup
  // ==============================================================

  Future<void> _tearDownRealtime() async {
    try {
      if (_realtimeManager != null) {
        await _realtimeManager!.dispose();
        _realtimeManager = null;
      }
      debugPrint('🔄 SyncService: تم إغلاق الـ RealtimeSyncManager.');
    } catch (e) {
      debugPrint('❌ _tearDownRealtime: $e');
    }
  }

  // ==============================================================
  // Offline Queue Processing
  // ==============================================================

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    if (_queueBox == null || _queueBox!.isEmpty) return;

    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      debugPrint('📴 Queue: لا إنترنت، تأجيل المعالجة.');
      return;
    }

    _isProcessingQueue = true;
    debugPrint('🔄 Queue: معالجة ${_queueBox!.length} عنصر...');

    final keysToDelete = <dynamic>[];

    for (int i = 0; i < _queueBox!.length; i++) {
      final key = _queueBox!.keyAt(i);
      final item = _queueBox!.getAt(i);
      if (item is! Map) continue;

      final table = item['table']?.toString();
      final rawData = item['data'];
      final operation = item['operation']?.toString() ?? 'upsert';
      final retries = (item['retries'] as int?) ?? 0;

      if (table == null || rawData is! Map) continue;
      if (retries >= 5) {
        debugPrint('⚠️ Queue: تجاوز الحد → $table [$operation]');
        keysToDelete.add(key);
        continue;
      }

      try {
        final factoryId = await SupabaseManager.getFactoryId();
        if (factoryId == null) break;

        final payload = Map<String, dynamic>.from(rawData);
        payload['factory_id'] = factoryId;

        if (operation == 'delete') {
          final id = payload['id'] ?? payload['sync_id'];
          if (id != null) {
            try {
              await _supabase.from(table).delete().eq('id', id.toString());
            } catch (e) {
              if (e is PostgrestException && e.code == 'PGRST204') {
                // Fallback to sync_id for deletion if id column fails
                await _supabase.from(table).delete().eq('sync_id', id.toString());
              } else {
                rethrow;
              }
            }
            debugPrint('✅ Queue: حذف من $table [id=$id]');
          }
        } else {
          try {
            await _supabase.from(table).upsert(payload);
            debugPrint('✅ Queue: رُفع إلى $table');
            } catch (e) {
              // Handle specific case where Supabase table doesn't have an 'id' column (PGRST204)
              if (e is PostgrestException &&
                  e.code == 'PGRST204' &&
                  payload.containsKey('id') &&
                  payload.containsKey('sync_id')) {
                debugPrint(
                    '⚠️ Queue: Schema mismatch (PGRST204). Retrying without "id" column...');
                final retryPayload = Map<String, dynamic>.from(payload);
                retryPayload.remove('id');
                await _supabase.from(table).upsert(retryPayload);
                debugPrint('✅ Queue: رُفع إلى $table (Retry success)');
              } else if (e is PostgrestException &&
                  e.code == '22P02' &&
                  payload.containsKey('id')) {
                // 🛠️ إصلاح تلقائي للمعرفات غير الصالحة (UUID Repair)
                final oldId = payload['id'].toString();
                if (!oldId.contains('-')) {
                  debugPrint(
                      '⚠️ Queue: مُعرف غير صالح ($oldId). جارِ إصلاحه...');
                  final newId = _generateV4Uuid();
                  payload['id'] = newId;
                  payload['sync_id'] = newId;

                  // تحديث المعرف في Hive لضمان التطابق
                  final boxName = _getBoxNameForTable(table);
                  if (boxName != null && Hive.isBoxOpen(boxName)) {
                    final box = Hive.box(boxName);
                    // البحث عن السجل القديم وتحديثه
                    for (var key in box.keys) {
                      final val = box.get(key);
                      if (val is HiveObject &&
                          (val as dynamic).id == oldId) {
                        (val as dynamic).id = newId;
                        await val.save();
                        debugPrint(
                            '✨ Queue: تم تحديث المعرف محلياً في $boxName');
                        break;
                      } else if (val is Map && val['id'] == oldId) {
                        val['id'] = newId;
                        await box.put(key, val);
                        debugPrint(
                            '✨ Queue: تم تحديث المعرف محلياً (Map) في $boxName');
                        break;
                      }
                    }
                  }

                  // إعادة محاولة الرفع بالمعرف الجديد
                  await _supabase.from(table).upsert(payload);
                  debugPrint('✅ Queue: رُفع بمُعرف جديد: $newId');
                } else {
                  rethrow;
                }
              } else {
                rethrow;
              }
            }
        }

        keysToDelete.add(key);
      } catch (e) {
        debugPrint('❌ Queue: فشل → $table [$operation]: $e');
        final updated = Map<String, dynamic>.from(item);
        updated['retries'] = retries + 1;
        await _queueBox!.put(key, updated);
      }
    }

    for (final key in keysToDelete) {
      await _queueBox!.delete(key);
    }

    _isProcessingQueue = false;
    debugPrint('✅ Queue: اكتملت. متبقي: ${_queueBox!.length}');
  }

  // ==============================================================
  // Helpers
  // ==============================================================

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect(
        'supabase.com',
        443,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? _getBoxNameForTable(String table) {
    switch (table) {
      case 'customers':
        return 'savedSheetSizes';
      case 'production_reports':
        return 'inkReports';
      case 'workers':
        return 'workers';
      case 'worker_actions':
        return 'worker_actions';
      default:
        return null;
    }
  }

  static String _generateV4Uuid() {
    final Random random = Random();
    final List<int> values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant 10
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
