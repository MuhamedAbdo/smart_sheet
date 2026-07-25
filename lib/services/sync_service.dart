// lib/services/sync_service.dart
//
// نظام المزامنة المركزي – Offline-First + Supabase Real-time
//
// الجداول المُزامَنة:
//   customers          ↔ savedSheetSizes        (Box)          → [CustomerSync]
//   customer_products  ↔ finished_products       (Box)          → [CustomerSync]
//   production_reports ↔ inkReports              (Box)          → [ProductionSync]
//   live_sessions      ↔ flexo_live_sessions     (Box)          → [ProductionSync]
//   workers            ↔ workers_flexo           (Box<Worker>)  → هنا
//   machines           ↔ flexo_machines          (Box<FlexoMachine>) → هنا
//   worker_actions     ↔ worker_actions          (Box<WorkerAction>) → هنا
//   machine_reports    ↔ maintenance_records_main (Box)         → هنا
//
// المعمارية:
//   SyncServiceBase (abstract) ← الحقول المشتركة بين الـ Mixins
//   mixin CustomerSync  on SyncServiceBase  ← lib/services/sync/customer_sync.dart
//   mixin ProductionSync on SyncServiceBase ← lib/services/sync/production_sync.dart
//   class SyncService extends SyncServiceBase with CustomerSync, ProductionSync

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
// import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/services/server_time_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/services/kill_switch_service.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:uuid/uuid.dart';

// 🔑 part files — جزء من نفس الـ library، ترى جميع التعريفات الـ private.
part 'sync/customer_sync.dart';
part 'sync/production_sync.dart';
part 'sync/machines_sync.dart';
part 'sync/workers_sync.dart';
part 'sync/factory_sync.dart';
part 'sync/die_cutting_forms_sync.dart';

// ==============================================================
// SyncServiceBase — الحقول المشتركة بين Mixins و SyncService
// ==============================================================
// يُمكِّن الـ Mixins من الوصول لـ _supabase و _scheduleReconnect
// و _reconnectAttempts دون circular dependency.

abstract class SyncServiceBase {
  /// عميل Supabase المشترك بين جميع الـ Mixins
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─── Auto-Reconnect State ─────────────────────────────────────
  final Map<String, int> _reconnectAttempts = {};
  static const int _maxReconnectAttempts = 6;
  final Map<String, Timer> _reconnectTimers = {};
  bool _isDisposed = false;
  String? _currentFactoryId;

  /// جدولة إعادة الاتصال لقناة معينة لتفادي تدمير القنوات الأخرى الناجحة
  void _scheduleReconnect(
      String channelName, Future<void> Function() reconnectAction);
}

// ==============================================================
// SyncService — نقطة الدخول المركزية للتطبيق
// ==============================================================

class SyncService extends SyncServiceBase
    with
        CustomerSync,
        ProductionSync,
        MachinesSync,
        WorkersSync,
        FactorySync,
        DieCuttingFormsSync {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  // ─── قنوات الميزات المتبقية ────────────────────────────────────
  // (Machines / MachineReports)
  // مرشحة للعزل في Mixins مستقبلية تدريجياً
  RealtimeChannel? _machineReportsChannel;

  // ─── ThemeProvider Reference ──────────────────────────────────
  // يُسجَّل من main.dart عند بناء SmartSheetApp لتمرير الـ ref
  // للـ FactorySync mixin دون كسر signature الـ initialize().
  ThemeProvider? _themeProvider;

  void setThemeProvider(ThemeProvider tp) {
    final bool isFirstTime = _themeProvider == null;
    _themeProvider = tp;

    if (isFirstTime && _currentFactoryId != null) {
      debugPrint(
          '⚡ SyncService: تم تسجيل ThemeProvider بعد التهيئة. بدء مزامنة المصنع...');
      _initFactorySettings(_currentFactoryId!, tp);
      _setupFactoryChannel(_currentFactoryId!, tp);
    }
  }

  Box? _queueBox;
  bool _isProcessingQueue = false;
  // ✅ حارس منع الاستدعاءات المتوازية لـ initialize() —
  // يحدث عند بدء التطبيق ومن حدث الـ resumed في نفس اللحظة
  bool _isInitializing = false;

  /// يضمن أن _queueBox مفتوح دائماً — يُعيد فتحه إن أُغلق.
  Future<Box> _ensureQueueBox() async {
    if (_queueBox != null && _queueBox!.isOpen) return _queueBox!;
    _queueBox = Hive.isBoxOpen('sync_queue')
        ? Hive.box('sync_queue')
        : await Hive.openBox('sync_queue');
    return _queueBox!;
  }

  // ==============================================================
  // Public API
  // ==============================================================

  Future<void> initialize() async {
    // ─── حارس الاستدعاء المتوازي ───────────────────────────────
    if (_isInitializing) {
      debugPrint('⏭️ SyncService: initialize() تجاهل — تهيئة جارية بالفعل.');
      return;
    }
    _isInitializing = true;
    try {
      _queueBox = Hive.isBoxOpen('sync_queue')
          ? Hive.box('sync_queue')
          : await Hive.openBox('sync_queue');

      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) {
        debugPrint('⏳ SyncService: لا يوجد factory_id، ينتظر تسجيل الدخول.');
        return;
      }

      await _tearDownChannels();

      await ServerTimeService.instance.init();
      unawaited(ServerTimeService.instance.syncServerTime());

      // 1. تنزيل الجلسات الحية النشطة [ProductionSync]
      await _initLiveSessions(factoryId);

      // 2. المزامنة المبدئية لـ customers [CustomerSync]
      await _initCustomers(factoryId);

      // ══════════════════════════════════════════════════════════════════
      // 🔄 Delta Sync — جلب البيانات الفائتة عندما كان التطبيق مغلقاً
      // ══════════════════════════════════════════════════════════════════
      // يعمل بعد _initCustomers لضمان أن الـ UI جاهزة لعرض الـ overlays
      // وقبل إعداد Realtime channels لتفادي أي تكرار في السجلات
      await _performDeltaSync(factoryId);

      // 3. المزامنة المبدئية لـ workers
      await _initWorkers(factoryId);

      // 4. المزامنة المبدئية لـ production_reports و archived_reports [ProductionSync]
      await _initProductionReports(factoryId);
      await _initArchivedReports(factoryId);

      // 5. المزامنة المبدئية لـ machines [MachinesSync]
      await _initMachines(factoryId);

      // 6. المزامنة المبدئية لـ worker_actions (= attendance_logs)
      await _initWorkerActions(factoryId);

      // 9. المزامنة المبدئية لأوقات الوردية [FactorySync]
      if (_themeProvider != null) {
        await _initFactorySettings(factoryId, _themeProvider!);
      }

      // 7. المزامنة المبدئية لـ customer_products [CustomerSync]
      await _initCustomerProducts(factoryId);

      // 8. المزامنة المبدئية لقوالب التكسير [DieCuttingFormsSync]
      await syncDieCuttingForms(factoryId);

      // إعداد قنوات Real-time بعد التحميل المبدئي بنجاح
      _setupChannels(factoryId);
      unawaited(_processQueue());

      // ✅ تحديث طابع آخر مزامنة ناجحة
      _saveLastSyncedAt();

      debugPrint('✅ SyncService: تم التهيئة للمصنع: $factoryId');
    } catch (e) {
      if (e.toString().contains('AuthRetryableFetchException') ||
          e.toString().contains('SocketException')) {
        debugPrint(
            '⚠️ [SyncService] شبكة غير مستقرة أثناء التهيئة المبدئية: $e');
      } else {
        debugPrint('❌ SyncService.initialize: $e');
      }
    } finally {
      // ✅ تحرير الحارس دائماً — حتى لو فشلت التهيئة
      _isInitializing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Delta Sync — جلب السجلات الجديدة منذ آخر مزامنة ناجحة
  // ══════════════════════════════════════════════════════════════════════
  //
  // الفكرة: عند الإقلاع، نقرأ last_synced_at من Hive ثم نجلب فقط السجلات
  // التي تم إنشاؤها بعد هذا التوقيت من Supabase (بدلاً من جلب الكل).
  // السجلات الجديدة تُحقن في Hive مباشرةً وتُطلق إشعارات محلية للمستخدم.
  //
  Future<void> _performDeltaSync(String factoryId) async {
    try {
      final settingsBox =
          Hive.isBoxOpen('settings') ? Hive.box('settings') : null;
      if (settingsBox == null) return;

      final String? lastSyncedAtRaw = settingsBox.get('last_synced_at');
      if (lastSyncedAtRaw == null) {
        debugPrint('🔄 [DeltaSync] أول تشغيل — لا يوجد last_synced_at، تخطي.');
        return;
      }

      // ✅ إضافة هامش أمان 90 ثانية للخلف لتفادي فقدان سجلات أُضيفت
      // في نفس ثانية آخر مزامنة أو بسبب فارق الساعة بين الجهاز والسيرفر.
      final lastSyncedAtParsed = DateTime.tryParse(lastSyncedAtRaw);
      if (lastSyncedAtParsed == null) {
        debugPrint(
            '⚠️ [DeltaSync] تنسيق last_synced_at غير صالح: $lastSyncedAtRaw');
        return;
      }
      final queryFrom = lastSyncedAtParsed
          .subtract(const Duration(seconds: 90))
          .toUtc()
          .toIso8601String();

      debugPrint(
          '🔄 [DeltaSync] جلب السجلات الجديدة منذ: $queryFrom (raw=$lastSyncedAtRaw)');
      int totalNew = 0;
      // قائمة السجلات الجديدة التي ستُعرض في overlay واحد
      final List<Map<String, dynamic>> missedItems = [];

      // ─── جلب العملاء الجدد ────────────────────────────────────────
      try {
        // ✅ جدول customers يستخدم updated_at وليس created_at
        final newCustomers = await _supabase
            .from('customers')
            .select()
            .eq('factory_id', factoryId)
            .gt('updated_at', queryFrom)
            .order('updated_at');

        if (newCustomers.isNotEmpty) {
          debugPrint(
              '📬 [DeltaSync] ${newCustomers.length} عميل/صنف محتمل للمزامنة.');
          final box = Hive.isBoxOpen('savedSheetSizes')
              ? Hive.box('savedSheetSizes')
              : await Hive.openBox('savedSheetSizes');

          for (final row in newCustomers) {
            // حقن في Hive — التحقق من عدم الوجود أولاً
            final syncId = row['sync_id']?.toString() ?? row['id']?.toString();
            if (syncId == null) continue;

            // فحص إذا كان السجل موجوداً مسبقاً
            bool exists = false;
            for (var i = 0; i < box.length; i++) {
              final existing = box.getAt(i);
              if (existing is Map &&
                  (existing['sync_id']?.toString() == syncId)) {
                exists = true;
                break;
              }
            }
            if (exists) continue;

            // بناء السجل المحلي من بيانات Supabase
            final localRecord = <String, dynamic>{
              'sync_id': syncId,
              'clientName': row['client_name']?.toString() ?? '',
              'productName': row['product_name']?.toString() ?? '',
              'productCode': row['product_code']?.toString() ?? '',
              'processType': row['process_type']?.toString() ?? 'تفصيل',
              'length': row['length']?.toString() ?? '',
              'width': row['width']?.toString() ?? '',
              'height': row['height']?.toString() ?? '',
              'isSheet': row['is_sheet'] ?? false,
              'isClientRecord': row['is_client_record'] ?? false,
              'imagePaths': (row['image_paths'] as List?)?.cast<String>() ?? [],
              'date': row['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
            };
            await box.add(localRecord);
            totalNew++;

            // جمع الإشعارات للعرض لاحقاً بعد جاهزية الـ UI
            final clientName = localRecord['clientName'] as String;
            final productName = localRecord['productName'] as String;
            if (clientName.isNotEmpty && productName.isNotEmpty) {
              missedItems.add({
                'isClientRecord': localRecord['isClientRecord'] == true,
                'clientName': clientName,
                'productName': productName,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [DeltaSync] خطأ في جلب العملاء: $e');
      }

      // ─── جلب العمال الجدد ────────────────────────────────────────
      try {
        // ✅ جدول workers يملك created_at (وليس updated_at)
        final newWorkers = await _supabase
            .from('workers')
            .select()
            .eq('factory_id', factoryId)
            .gt('created_at', queryFrom)
            .order('created_at');

        if (newWorkers.isNotEmpty) {
          debugPrint('📬 [DeltaSync] ${newWorkers.length} عامل جديد.');
          // لا نُرسل إشعاراً للعمال الجدد — المدير يعرف بهم بالفعل
          totalNew += newWorkers.length;
        }
      } catch (e) {
        debugPrint('⚠️ [DeltaSync] خطأ في جلب العمال: $e');
      }

      if (totalNew > 0) {
        debugPrint(
            '✅ [DeltaSync] تم استرجاع $totalNew سجل جديد وإرسال الإشعارات.');

        // ─── عرض الإشعارات بعد جاهزية الـ UI ──────────────────────
        if (missedItems.isNotEmpty) {
          final count = missedItems.length;

          if (count == 1) {
            // إشعار مفرد بتفاصيل كاملة
            final item = missedItems.first;
            final isClientRecord = item['isClientRecord'] == true;
            final clientName = item['clientName'] as String;
            final productName = item['productName'] as String;
            final title = isClientRecord
                ? '🆕 عميل جديد أثناء الغياب'
                : '📦 صنف جديد أثناء الغياب';
            final body = isClientRecord
                ? 'تم تسجيل العميل: $clientName'
                : '$clientName — $productName';

            await showLocalNotification(title, body, clientName);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UIUtils.showTopOverlay(title: title, message: body, onTap: () {});
            });
          } else {
            // إشعار ملخص لتفادي الإغراق
            final title = '📋 $count عناصر جديدة أثناء الغياب';
            final body = 'تم إضافة $count عملاء/أصناف — اضغط للتحقق';

            await showLocalNotification(title, body, '');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              UIUtils.showTopOverlay(title: title, message: body, onTap: () {});
            });
          }
        }
      } else {
        debugPrint('✅ [DeltaSync] لا توجد سجلات جديدة منذ آخر مزامنة.');
      }
    } catch (e) {
      // لا نُوقف التطبيق بسبب فشل الـ Delta Sync — المزامنة الكاملة ستتم بعده
      debugPrint('⚠️ [DeltaSync] خطأ عام: $e');
    }
  }

  /// حفظ طابع آخر مزامنة ناجحة في Hive settings
  /// ✅ نحفظ دائماً UTC لتوحيد المقارنة مع Supabase الذي يعمل بـ UTC
  void _saveLastSyncedAt() {
    try {
      if (!Hive.isBoxOpen('settings')) return;
      final box = Hive.box('settings');
      // UTC مضمون — Supabase يحفظ created_at بـ UTC دائماً
      final now = DateTime.now().toUtc().toIso8601String();
      box.put('last_synced_at', now);
      debugPrint('🕐 [SyncService] last_synced_at (UTC) = $now');
    } catch (e) {
      debugPrint('⚠️ [SyncService] تعذّر حفظ last_synced_at: $e');
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    await _tearDownChannels();
    debugPrint('🔄 SyncService: تم الإغلاق.');
  }

  Future<void> clearSyncQueue() async {
    try {
      final box = await _ensureQueueBox();
      final count = box.length;
      await box.clear();
      debugPrint('🧹 SyncService: تم مسح $count عنصر من sync_queue.');
    } catch (e) {
      debugPrint('❌ SyncService.clearSyncQueue: $e');
    }
  }

  Future<String> forcePushAllLocalDataToServer() async {
    try {
      final factoryId = await SupabaseManager.getFactoryId();
      if (factoryId == null) throw Exception('المصنع غير محدد');
      int addedCount = 0;

      final customersBox = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');
      for (var key in customersBox.keys) {
        final data = customersBox.get(key);
        if (data is Map) {
          final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
          mapData['factory_id'] = factoryId;
          mapData.remove('sync_status');
          await pushToQueue('customers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      final workersBox = Hive.isBoxOpen('workers_flexo')
          ? Hive.box<Worker>('workers_flexo')
          : await Hive.openBox<Worker>('workers_flexo');
      for (var key in workersBox.keys) {
        final worker = workersBox.get(key);
        if (worker != null) {
          final mapData = worker.toJson();
          mapData['factory_id'] = factoryId;
          await pushToQueue('workers', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      final reportsBox = Hive.isBoxOpen('inkReports')
          ? Hive.box('inkReports')
          : await Hive.openBox('inkReports');
      for (var key in reportsBox.keys) {
        final data = reportsBox.get(key);
        if (data is Map) {
          final Map<String, dynamic> mapData = Map<String, dynamic>.from(data);
          mapData['factory_id'] = factoryId;
          mapData.remove('sync_status');
          await pushToQueue('production_reports', mapData, operation: 'upsert');
          addedCount++;
        }
      }

      return '✅ تم إضافة $addedCount سجل إلى طابور المزامنة بنجاح. سيتم رفعها للسيرفر تباعاً.';
    } catch (e) {
      debugPrint('❌ forcePushAllLocalDataToServer error: $e');
      return '❌ فشل المزامنة الإجبارية: $e';
    }
  }

  Future<void> pushToQueue(
    String table,
    Map<String, dynamic> data, {
    String operation = 'upsert',
  }) async {
    try {
      final box = await _ensureQueueBox();

      await box.add({
        'table': table,
        'data': Map<String, dynamic>.from(data),
        'operation': operation,
        'timestamp': ServerTimeService.nowUtc.toIso8601String(),
        'retries': 0,
      });

      debugPrint('📤 Queue → $table [$operation]');
      unawaited(_processQueue());
    } catch (e) {
      debugPrint('❌ SyncService.pushToQueue: $e');
    }
  }

  /// حذف مجمّع: يُرسل عملية واحدة للطابور تحذف قائمة من السجلات دفعةً واحدة
  /// بدلاً من عملية حذف منفردة لكل عنصر (يمنع إغراق الطابور بمئات العمليات).
  Future<void> pushBatchDeleteToQueue(
    String table,
    List<String> syncIds,
  ) async {
    if (syncIds.isEmpty) return;
    try {
      final box = await _ensureQueueBox();
      await box.add({
        'table': table,
        'data': {'sync_ids': syncIds},
        'operation': 'batch_delete',
        'timestamp': ServerTimeService.nowUtc.toIso8601String(),
        'retries': 0,
      });
      debugPrint('📤 Queue → $table [batch_delete] (${syncIds.length} عنصر)');
      unawaited(_processQueue());
    } catch (e) {
      debugPrint('❌ SyncService.pushBatchDeleteToQueue: $e');
    }
  }

  // ==============================================================
  // Real-time Channel Setup (Orchestrator)
  // ==============================================================

  void _setupChannels(String factoryId) {
    if (_isDisposed) return;
    _currentFactoryId = factoryId;
    debugPrint('📡 SyncService: إعداد الـ channels لـ factory: $factoryId');

    // ─── [CustomerSync]  customers + customer_products ─────────────
    _setupCustomerChannels(factoryId);

    // ─── [ProductionSync] production_reports + live_sessions ───────
    _setupProductionChannels(factoryId);

    // ─── [WorkersSync] workers + worker_actions ────────────────────
    _setupWorkersChannels(factoryId);

    // ─── [هنا] machines ────────────────────────────────────────────
    _setupMachinesChannel(factoryId);
    _setupDieCuttingFormsChannel(factoryId);

    // ─── [FactorySync] factories (shift times) ──────────────────────
    if (_themeProvider != null) {
      _setupFactoryChannel(factoryId, _themeProvider!);
    }

    // ─── [هنا] machine_reports ─────────────────────────────────────
    // _setupMachineReportsChannel(factoryId); // تم التعطيل لمنع PGRST205
  }

  Future<void> _tearDownChannels() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    try {
      await _tearDownCustomerChannels();
      await _tearDownProductionChannels();
      await _tearDownMachinesChannel();
      await _tearDownWorkersChannels();
      await _tearDownDieCuttingFormsChannel();
      await _tearDownFactoryChannel();

      if (_machineReportsChannel != null) {
        await _supabase.removeChannel(_machineReportsChannel!);
        _machineReportsChannel = null;
      }
      debugPrint('🔄 SyncService: تم إغلاق الـ channels.');
    } catch (e) {
      debugPrint('❌ _tearDownChannels: $e');
    }
  }

  // ==============================================================
  // Channel Setup — Workers / Machines / Attendance / MachineReports
  // ==============================================================

  /*
  void _setupMachineReportsChannel(String factoryId) {
    // ... تم التعطيل ...
  }
  */

  /// إرسال إشعار محلي:
  ///   • Android → push notification عبر flutter_local_notifications
  ///   • Windows/غير Android → لا push (المنصة لا تدعمه)، يكفي UIUtils.showTopOverlay
  Future<void> showLocalNotification(
      String title, String body, String clientName) async {
    if (kIsWeb) return;
    // ─── Android: إشعار push حقيقي ────────────────────────────────
    if (Platform.isAndroid) {
      try {
        final flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        const androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'factory_notifications_channel',
          'Factory Notifications',
          channelDescription: 'إشعارات لحظية للمصنع',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        );
        const platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        await flutterLocalNotificationsPlugin.show(
          DateTime.now().millisecond,
          title,
          body,
          platformChannelSpecifics,
          payload: jsonEncode({'clientName': clientName}),
        );
      } catch (e) {
        debugPrint('❌ showLocalNotification (Android): $e');
      }
    }
    // ─── Windows وغيره: الـ overlay يُعرض من المستدعي مباشرةً ────────
    // (UIUtils.showTopOverlay لا يعمل هنا لأن context غير متاح — يُستدعى
    //  من _onCustomerChange و _performDeltaSync مباشرةً قبل هذه الدالة)
  }

  // ==============================================================
  // Auto-Reconnect Logic — Exponential Backoff
  // ==============================================================

  /// جدولة إعادة الاتصال بعد انتهاء المهلة أو حدوث خطأ:
  /// #1 → 5ث | #2 → 10ث | #3 → 20ث | #4 → 40ث | #5 → 80ث | #6+ → توقف
  /// جدولة إعادة الاتصال لقناة محددة فقط
  @override
  void _scheduleReconnect(
      String channelName, Future<void> Function() reconnectAction) {
    if (_isDisposed || _currentFactoryId == null) return;
    if (_reconnectTimers[channelName]?.isActive == true) return;

    final attempts = _reconnectAttempts[channelName] ?? 0;
    if (attempts >= SyncServiceBase._maxReconnectAttempts) {
      debugPrint(
        '⛔ SyncService: تجاوز الحد الأقصى ($SyncServiceBase._maxReconnectAttempts) للقناة $channelName. '
        'استخدم SyncService.instance.initialize() للإعادة يدوياً.',
      );
      return;
    }

    _reconnectAttempts[channelName] = attempts + 1;
    final delaySeconds = (5 * (1 << attempts)).clamp(5, 80);
    final delay = Duration(seconds: delaySeconds);

    debugPrint(
        '⏳ SyncService [$channelName]: إعادة محاولة #${attempts + 1} خلال ${delay.inSeconds}ث...');

    _reconnectTimers[channelName] = Timer(delay, () async {
      if (_isDisposed || _currentFactoryId == null) return;
      debugPrint('🔄 SyncService [$channelName]: بدء إعادة الاتصال...');
      try {
        await reconnectAction();
      } catch (e) {
        debugPrint('❌ SyncService [$channelName]: فشل إعادة الاتصال: $e');
      }
    });
  }

  // ==============================================================
  // Real-time Callbacks — Workers / Machines / Attendance / MachineReports
  // ==============================================================

  /*
  void _onMachineReportChange(PostgresChangePayload payload, String myFactoryId) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) return;

      if (!Hive.isBoxOpen('maintenance_records_main')) {
        await Hive.openBox<MaintenanceRecord>('maintenance_records_main');
      }
      final box = Hive.box<MaintenanceRecord>('maintenance_records_main');
      final stableKey = record['id']?.toString();
      if (stableKey == null) return;

      if (isDelete) {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null && box.containsKey(existingKey)) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        }
        debugPrint('🗑️ [machine_reports] حُذف: $stableKey');
      } else {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        await box.put(existingKey, MaintenanceRecord.fromJson(record));
        debugPrint('✅ [machine_reports] تم حفظ/تحديث: $stableKey');
      }
    } catch (e) { debugPrint('❌ _onMachineReportChange: $e'); }
  }
  */

  // ==============================================================
  // Offline Queue Processing
  // ==============================================================

  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;

    // ✅ الحارس الأساسي: إعادة فتح الـ box إن أُغلق بعد restart أو teardown
    late Box queueBox;
    try {
      queueBox = await _ensureQueueBox();
    } catch (e) {
      debugPrint('❌ _processQueue: تعذّر فتح sync_queue: $e');
      return;
    }

    if (queueBox.isEmpty) {
      debugPrint('📱 Mobile Queue: القائمة فارغة.');
      return;
    }

    debugPrint('📱 Mobile Queue: محاولة إرسال... (${queueBox.length} عنصر)');
    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      debugPrint('📴 Queue: لا إنترنت.');
      return;
    }
    unawaited(ServerTimeService.instance.syncServerTime());

    _isProcessingQueue = true;
    debugPrint('🔄 Queue: معالجة ${queueBox.length} عنصر...');
    final keysToDelete = <dynamic>[];

    for (int i = 0; i < queueBox.length; i++) {
      // ✅ تحقق عند كل تكرار — قد يُغلق الـ box أثناء المعالجة
      if (!queueBox.isOpen) {
        debugPrint('⚠️ _processQueue: الـ box أُغلق أثناء المعالجة. توقف.');
        break;
      }

      final key = queueBox.keyAt(i);
      final item = queueBox.getAt(i);
      if (item is! Map) continue;

      final table = item['table']?.toString();
      final rawData = item['data'];
      final operation = item['operation']?.toString() ?? 'upsert';
      final retries = (item['retries'] as int?) ?? 0;
      if (table == null || rawData is! Map) continue;

      // ✅ عمليات batch_delete تستخدم sync_ids (قائمة) وليس sync_id مفرداً
      // → تجاوز فحص sync_id لها وإلا ستُحذف كـ "تقارير تالفة" قبل تنفيذها
      if (operation != 'batch_delete') {
        final syncId =
            rawData['sync_id']?.toString() ?? rawData['id']?.toString();
        if (syncId == null || syncId.trim().isEmpty) {
          debugPrint('🗑️ تقرير تالف (sync_id فارغ) → table=$table op=$operation');
          keysToDelete.add(key);
          continue;
        }
        if (RegExp(r'[<>{}\[\]\*\&\^\%\$#@!]').hasMatch(syncId)) {
          debugPrint('🗑️ تقرير تالف (رموز غريبة: $syncId)');
          keysToDelete.add(key);
          continue;
        }
      }
      if (retries >= 5) {
        debugPrint('⚠️ Queue: تجاوز الحد → $table');
        keysToDelete.add(key);
        continue;
      }
      
      final timestampStr = item['timestamp']?.toString();
      if (timestampStr != null) {
        final timestamp = DateTime.tryParse(timestampStr);
        if (timestamp != null && DateTime.now().difference(timestamp).inDays > 3) {
          debugPrint('⚠️ Queue: أمر قديم جداً (أكثر من 3 أيام) تم تجاهله → $table');
          keysToDelete.add(key);
          continue;
        }
      }

      try {
        final factoryId = await SupabaseManager.getFactoryId();
        if (factoryId == null) break;

        final payload = Map<String, dynamic>.from(rawData);
        payload['factory_id'] = factoryId;

        if (operation == 'batch_delete') {
          // ✅ حذف مجمّع: عملية واحدة لحذف قائمة سجلات دفعةً
          final rawIds = rawData['sync_ids'];
          if (rawIds is List && rawIds.isNotEmpty) {
            final ids = rawIds.map((e) => e.toString()).toList();
            if (table == 'die_cutting_forms') {
              await _supabase.from(table).delete().inFilter('id', ids);
            } else {
              await _supabase.from(table).delete().inFilter('sync_id', ids);
            }
            debugPrint('✅ Queue: batch_delete من $table [${ids.length} عنصر]');
          } else {
            debugPrint('⚠️ Queue: batch_delete فارغ — $table');
          }
        } else if (operation == 'delete') {
          final deleteSyncId =
              payload['sync_id']?.toString() ?? payload['id']?.toString();
          if (deleteSyncId != null && deleteSyncId.isNotEmpty) {
            if (table == 'die_cutting_forms') {
              await _supabase.from(table).delete().eq('id', deleteSyncId);
            } else {
              await _supabase.from(table).delete().eq('sync_id', deleteSyncId);
            }
            debugPrint('✅ Queue: حذف من $table [id/sync_id=$deleteSyncId]');
          } else {
            debugPrint('⚠️ Queue: تجاهل delete — لا معرف في $table');
          }
        } else {
          final cleanPayload = _sanitizePayload(payload, table);
          try {
            if (table == 'customers' ||
                table == 'production_reports' ||
                table == 'workers' ||
                table == 'live_sessions' ||
                table == 'archived_reports') {
              await _supabase
                  .from(table)
                  .upsert(cleanPayload, onConflict: 'sync_id');
            } else {
              await _supabase.from(table).upsert(cleanPayload);
            }
          } on PostgrestException catch (e) {
            // ✅ حماية ذكية ضد أخطاء اختلاف هيكل قاعدة البيانات (مثل عدم وجود عمود department أو shift أو technician_id في جدول live_sessions بالسحابة)
            if (e.code == 'PGRST204' ||
                e.code == '42703' ||
                e.message.toLowerCase().contains('column')) {
              final match = RegExp(r"Could not find the '([^']+)' column")
                  .firstMatch(e.message);
              final missingCol = match?.group(1);

              bool modified = false;
              if (missingCol != null && cleanPayload.containsKey(missingCol)) {
                debugPrint(
                    '⚠️ [Queue] حقل $missingCol غير موجود في جدول $table بسحابة Supabase، جاري الرفع بدونه...');
                cleanPayload.remove(missingCol);
                modified = true;
              }
              if (cleanPayload.containsKey('department') &&
                  (missingCol == 'department' ||
                      e.message.contains('department'))) {
                cleanPayload.remove('department');
                modified = true;
              }
              if (cleanPayload.containsKey('shift') &&
                  (missingCol == 'shift' || e.message.contains('shift'))) {
                cleanPayload.remove('shift');
                modified = true;
              }
              if (cleanPayload.containsKey('technician_id') &&
                  (missingCol == 'technician_id' ||
                      e.message.contains('technician_id'))) {
                cleanPayload.remove('technician_id');
                modified = true;
              }
              if ((cleanPayload.containsKey('paper_layers') ||
                      cleanPayload.containsKey('paperLayers')) &&
                  (missingCol == 'paper_layers' ||
                      missingCol == 'paperLayers' ||
                      e.message.contains('paper_layers') ||
                      e.message.contains('paperLayers'))) {
                cleanPayload.remove('paper_layers');
                cleanPayload.remove('paperLayers');
                modified = true;
              }
              if (cleanPayload.containsKey('weight') &&
                  (missingCol == 'weight' || e.message.contains('weight'))) {
                cleanPayload.remove('weight');
                modified = true;
              }


              if (modified) {
                if (table == 'customers' ||
                    table == 'production_reports' ||
                    table == 'workers' ||
                    table == 'live_sessions') {
                  await _supabase
                      .from(table)
                      .upsert(cleanPayload, onConflict: 'sync_id');
                } else {
                  await _supabase.from(table).upsert(cleanPayload);
                }
              } else {
                rethrow;
              }
            } else {
              rethrow;
            }
          }
          debugPrint('✅ Queue: رُفع إلى $table');
        }
        keysToDelete.add(key);
      } catch (e) {
        debugPrint('❌ Queue: فشل → $table [$operation]: $e');
        if (queueBox.isOpen) {
          final updated = Map<String, dynamic>.from(item);
          updated['retries'] = retries + 1;
          await queueBox.put(key, updated);
        }
      }
    }

    if (queueBox.isOpen) {
      for (final key in keysToDelete) {
        await queueBox.delete(key);
      }
      debugPrint('✅ Queue: اكتملت. متبقي: ${queueBox.length}');
    }
    _isProcessingQueue = false;
  }

  // ==============================================================
  // Payload Sanitizer — يمنع خطأ 22P02
  // ==============================================================

  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> raw, String table) {
    const numericFields = {
      'length',
      'width',
      'height',
      'sheet_length',
      'sheet_width'
    };
    const uuidFields = {'sync_id', 'id', 'factory_id'};
    final result = <String, dynamic>{};
    raw.forEach((key, value) {
      if (numericFields.contains(key)) {
        if (value == null ||
            value.toString().trim().isEmpty ||
            value.toString().trim().toLowerCase() == 'null') {
          result[key] = null;
        } else {
          result[key] = double.tryParse(value.toString().trim());
        }
      } else if (uuidFields.contains(key)) {
        final strVal = value?.toString().trim() ?? '';
        if (strVal.isEmpty || strVal.toLowerCase() == 'null') {
          if (key == 'id') {
            // لا نضيف مفتاح id إطلاقاً إذا كان فارغاً لترك السحابة تستخدم Default Value
          } else {
            result[key] = const Uuid().v4();
            debugPrint(
                '⚠️ [sanitize] $key كان فارغاً، تم توليد UUID: ${result[key]}');
          }
        } else {
          result[key] = strVal;
        }
      } else {
        result[key] = value;
      }
    });

    // الحذف القاطع لمفتاح id بدون أي شروط (Unconditional Remove) لتوحيد هيكل الدفعة
    if (table != 'die_cutting_forms') {
      result.remove('id');
    }

    // تنظيف أي قيم null أخرى قد ترفضها السحابة إذا كانت الجداول لا تقبل Null
    result.removeWhere((key, value) =>
        value == null ||
        (value is String && value.trim().toLowerCase() == 'null'));

    return result;
  }

  // ==============================================================
  // Helpers — Connectivity
  // ==============================================================

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect('supabase.com', 443,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
