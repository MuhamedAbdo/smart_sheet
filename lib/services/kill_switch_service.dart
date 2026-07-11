// lib/services/kill_switch_service.dart
//
// خدمة التحكم المركزي في أجهزة العمال (Remote Kill Switch)
//
// المسؤوليات:
//   1. startListening() — يستمع لتغييرات سجل العامل الحالي في Supabase Realtime
//      ويُشغّل الطرد القسري عند اكتشاف فك الارتباط من الـ Admin.
//   2. stopListening() — يُغلق القناة عند تسجيل الخروج.
//   3. unlinkDevice(workerId) — للـ Admin: يُحدّث device_id=null و is_device_linked=false.
//   4. registerDevice(email, deviceId) — يُسجّل جهاز العامل في Supabase عند الربط.
//
// الاستخدام:
//   - بدء الاستماع: KillSwitchService.instance.startListening(...)
//   - إيقافه:       KillSwitchService.instance.stopListening()
//   - فك الارتباط:  KillSwitchService.instance.unlinkDevice(workerId)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/utils/device_manager.dart';

class KillSwitchService {
  // ─── Singleton ─────────────────────────────────────────────────────────────
  static final KillSwitchService instance = KillSwitchService._internal();
  KillSwitchService._internal();

  // ─── حقول داخلية ───────────────────────────────────────────────────────────
  final SupabaseClient _supabase = Supabase.instance.client;
  static const _storage = SafeSecureStorage();

  RealtimeChannel? _channel;
  String? _watchedWorkerId; // معرّف العامل المراقَب
  bool _isListening = false;

  // Callback يُستدعى عند اكتشاف الطرد القسري (يُمرَّر من main.dart)
  VoidCallback? _onForcedLogout;

  // ==============================================================================
  // Public API
  // ==============================================================================

  /// بدء الاستماع لتغييرات جهاز العامل المحدد عبر Supabase Realtime.
  ///
  /// [workerId]        : معرّف سجل العامل في جدول workers
  /// [onForcedLogout]  : callback يُستدعى فور اكتشاف فك الارتباط
  Future<void> startListening({
    required String workerId,
    required VoidCallback onForcedLogout,
  }) async {
    // تفادي الاشتراك المزدوج
    if (_isListening && _watchedWorkerId == workerId) {
      debugPrint('🔒 KillSwitch: الاستماع نشط بالفعل للعامل $workerId');
      return;
    }

    await stopListening(); // إغلاق أي قناة سابقة

    _watchedWorkerId = workerId;
    _onForcedLogout = onForcedLogout;
    _isListening = true;

    // جلب device_id المحلي للمقارنة
    final localDeviceId = await DeviceManager.getDeviceId();
    debugPrint('🔒 KillSwitch: بدء الاستماع | workerId=$workerId | localDevice=$localDeviceId');

    _channel = _supabase
        .channel('kill_switch_worker_$workerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'workers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: workerId,
          ),
          callback: (payload) {
            _handleWorkerUpdate(payload, localDeviceId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ KillSwitch: مُشترك في قناة مراقبة العامل $workerId');
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⚠️ KillSwitch: خطأ في القناة ($status): $error');
            // إعادة المحاولة بعد 10 ثوانٍ
            Future.delayed(const Duration(seconds: 10), () {
              if (_isListening && _watchedWorkerId == workerId) {
                debugPrint('🔄 KillSwitch: إعادة الاتصال...');
                startListening(
                  workerId: workerId,
                  onForcedLogout: onForcedLogout,
                );
              }
            });
          }
        });
  }

  /// إيقاف الاستماع وإغلاق القناة.
  Future<void> stopListening() async {
    if (_channel != null) {
      try {
        await _supabase.removeChannel(_channel!);
        debugPrint('🔒 KillSwitch: تم إغلاق قناة المراقبة');
      } catch (e) {
        debugPrint('⚠️ KillSwitch: خطأ عند إغلاق القناة: $e');
      }
      _channel = null;
    }
    _isListening = false;
    _watchedWorkerId = null;
    _onForcedLogout = null;
  }

  /// للـ Admin: فك ارتباط جهاز العامل عن بُعد.
  ///
  /// يُعيِّن device_id = null و is_device_linked = false في Supabase سواء عبر id أو email.
  Future<void> unlinkDevice(String workerId, {String? email}) async {
    debugPrint('🔓 KillSwitch: فك ارتباط الجهاز للعامل $workerId (email: $email)');
    try {
      await _supabase.from('workers').update({
        'device_id': null,
        'is_device_linked': false,
      }).eq('id', workerId);
    } catch (e) {
      debugPrint('⚠️ KillSwitch.unlinkDevice by id failed: $e');
    }
    if (email != null && email.isNotEmpty) {
      try {
        await _supabase.from('workers').update({
          'device_id': null,
          'is_device_linked': false,
        }).eq('email', email);
      } catch (e) {
        debugPrint('⚠️ KillSwitch.unlinkDevice by email failed: $e');
      }
    }
    try {
      await _supabase.from('profiles').update({
        'factory_id': null,
      }).eq('id', workerId);
    } catch (e) {
      debugPrint('⚠️ KillSwitch profiles clear by id: $e');
    }
    debugPrint('✅ KillSwitch: تم فك الارتباط بنجاح للعامل $workerId');
  }

  /// تسجيل جهاز العامل عند الربط الأول بالمصنع.
  ///
  /// يُعيِّن device_id و is_device_linked = true في سجل العامل المحدَّد بـ email.
  Future<void> registerDevice({
    required String email,
    required String factoryId,
  }) async {
    try {
      final deviceId = await DeviceManager.getDeviceId();
      debugPrint('📱 KillSwitch: تسجيل الجهاز | email=$email | device=$deviceId');

      await _supabase
          .from('workers')
          .update({
            'device_id': deviceId,
            'is_device_linked': true,
          })
          .eq('email', email);

      // حفظ معرّف العامل محلياً للرجوع إليه لاحقاً بدون استعلام إضافي
      final workerRes = await _supabase
          .from('workers')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (workerRes != null && workerRes['id'] != null) {
        await _storage.write(
            key: 'linked_worker_id', value: workerRes['id'].toString());
        debugPrint('✅ KillSwitch: تم تسجيل الجهاز وحفظ worker_id=${workerRes['id']}');
      } else {
        debugPrint('⚠️ KillSwitch: لم يُعثر على سجل العامل بالـ email=$email في المصنع $factoryId');
      }
    } catch (e) {
      debugPrint('❌ KillSwitch.registerDevice: $e');
    }
  }

  /// قراءة معرّف العامل المحفوظ محلياً (بعد الربط الأول).
  Future<String?> getLinkedWorkerId() async {
    return await _storage.read(key: 'linked_worker_id');
  }

  /// مسح معرّف العامل المحلي عند تسجيل الخروج أو فك الارتباط.
  Future<void> clearLinkedWorkerId() async {
    await _storage.delete(key: 'linked_worker_id');
  }

  /// فحص مباشر لحالة ارتباط الجهاز من Supabase (عند بدء أو استئناف التطبيق).
  Future<bool> checkAndEnforceKillSwitch({VoidCallback? onForcedLogout}) async {
    try {
      final userRole = await _storage.read(key: 'user_role');
      final factoryId = await _storage.read(key: 'factory_id');
      if (userRole == 'admin' || factoryId == null) return false;

      final linkedWorkerId = await getLinkedWorkerId();
      final currentUserEmail = _supabase.auth.currentUser?.email;
      if ((linkedWorkerId == null || linkedWorkerId.isEmpty) &&
          (currentUserEmail == null || currentUserEmail.isEmpty)) {
        return false;
      }

      Map<String, dynamic>? record;
      if (linkedWorkerId != null && linkedWorkerId.isNotEmpty) {
        record = await _supabase
            .from('workers')
            .select('id, is_device_linked, device_id')
            .eq('id', linkedWorkerId)
            .maybeSingle();
      }
      if (record == null && currentUserEmail != null && currentUserEmail.isNotEmpty) {
        record = await _supabase
            .from('workers')
            .select('id, is_device_linked, device_id')
            .eq('email', currentUserEmail)
            .maybeSingle();
      }

      if (record != null) {
        final recordId = record['id']?.toString();
        if (linkedWorkerId == null && recordId != null) {
          await _storage.write(key: 'linked_worker_id', value: recordId);
        }
        final bool isLinked = record['is_device_linked'] as bool? ?? false;
        final String? remoteDeviceId = record['device_id']?.toString();
        final localDeviceId = await DeviceManager.getDeviceId();

        if (!isLinked || remoteDeviceId == null || remoteDeviceId != localDeviceId) {
          debugPrint('🚨 KillSwitch: تم اكتشاف فك ارتباط الجهاز من الفحص المباشر! تنفيذ الطرد القسري...');
          await _executeForcedLogout(onForcedLogout);
          return true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ KillSwitch.checkAndEnforceKillSwitch: $e');
    }
    return false;
  }

  /// معالجة أي تحديث يصل من WorkersSync لجدول workers وتنفيذ الطرد فوراً إذا كان يخص هذا الجهاز.
  Future<void> handleRealtimeWorkerRecord(Map<String, dynamic> record, {VoidCallback? onForcedLogout}) async {
    try {
      final userRole = await _storage.read(key: 'user_role');
      final factoryId = await _storage.read(key: 'factory_id');
      if (userRole == 'admin' || factoryId == null) return;

      final linkedWorkerId = await getLinkedWorkerId();
      final currentUserEmail = _supabase.auth.currentUser?.email;
      final recordId = record['id']?.toString();
      final recordEmail = record['email']?.toString();

      final matchesById = (linkedWorkerId != null && linkedWorkerId.isNotEmpty && recordId == linkedWorkerId);
      final matchesByEmail = (currentUserEmail != null &&
          currentUserEmail.isNotEmpty &&
          recordEmail != null &&
          recordEmail.trim().toLowerCase() == currentUserEmail.trim().toLowerCase());

      if (!matchesById && !matchesByEmail) return;

      if (linkedWorkerId == null && recordId != null) {
        await _storage.write(key: 'linked_worker_id', value: recordId);
      }

      final bool isLinked = record['is_device_linked'] as bool? ?? false;
      final String? remoteDeviceId = record['device_id']?.toString();
      final localDeviceId = await DeviceManager.getDeviceId();

      if (!isLinked || remoteDeviceId == null || remoteDeviceId != localDeviceId) {
        debugPrint('🚨 KillSwitch: استلام تحديث فوري بفك ارتباط جهازي! تنفيذ الطرد القسري...');
        await _executeForcedLogout(onForcedLogout);
      }
    } catch (e) {
      debugPrint('⚠️ KillSwitch.handleRealtimeWorkerRecord: $e');
    }
  }

  // ==============================================================================
  // Private: معالجة تغييرات Realtime
  // ==============================================================================

  void _handleWorkerUpdate(
      PostgresChangePayload payload, String localDeviceId) {
    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;

      final bool isDeviceLinked = newRecord['is_device_linked'] as bool? ?? true;
      final String? remoteDeviceId = newRecord['device_id']?.toString();

      debugPrint(
          '🔒 KillSwitch: تغيير مُكتشَف | is_device_linked=$isDeviceLinked | remote=$remoteDeviceId | local=$localDeviceId');

      // حالتا الطرد القسري:
      // 1. is_device_linked أصبحت false (فك الارتباط من الـ Admin)
      // 2. device_id لم يعد يطابق الجهاز الحالي (نُقل لجهاز آخر)
      final bool shouldForceLogout =
          !isDeviceLinked || (remoteDeviceId != null && remoteDeviceId != localDeviceId);

      if (shouldForceLogout) {
        debugPrint('🚨 KillSwitch: اكتُشف طرد قسري! تنفيذ الإجراءات...');
        _executeForcedLogout();
      }
    } catch (e) {
      debugPrint('❌ KillSwitch._handleWorkerUpdate: $e');
    }
  }

  Future<void> _executeForcedLogout([VoidCallback? onForcedLogout]) async {
    try {
      // 0. تصفير factory_id في السحاب (profiles) للمستخدم الحالي لمنع إعادة ربطه تلقائياً عند تسجيل الدخول مجدداً
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        try {
          await _supabase.from('profiles').update({
            'factory_id': null,
          }).eq('id', currentUser.id);
          debugPrint('✅ KillSwitch: تم تصفير factory_id في profiles سحابياً');
        } catch (e) {
          debugPrint('⚠️ KillSwitch profiles clear: $e');
        }
      }

      // 1. مسح بيانات الارتباط من التخزين المحلي
      await _storage.delete(key: 'factory_id');
      await _storage.delete(key: 'user_role');
      await clearLinkedWorkerId();

      // 1b. مسح جميع صناديق Hive (سجل العمال، العملاء، الإنتاج، الفلكسو، إلخ) حتى لا يحتفظ الهاتف بأي بيانات
      final hiveBoxesToClear = [
        'workers',
        'workers_flexo',
        'workers_production',
        'workers_staple',
        'worker_actions',
        'finished_products',
        'flexo_live_sessions',
        'savedSheetSizes',
        'inkReports',
        'flexoArchive',
        'lineArchive',
        'store_flexo',
        'maintenance_records_main',
        'flexo_machines',
      ];
      for (final boxName in hiveBoxesToClear) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).clear();
          }
        } catch (e) {
          debugPrint('⚠️ KillSwitch clear box $boxName error: $e');
        }
      }

      // 2. مسح is_user_logged_in من Hive
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('is_user_logged_in', false);
      }

      // 3. تسجيل الخروج من Supabase Auth
      try {
        await _supabase.auth.signOut();
      } catch (_) {}

      debugPrint('✅ KillSwitch: تم مسح بيانات الجهاز المحلية وتصفير الجلسة');

      // 4. إيقاف الاستماع (لتفادي الحلقات)
      await stopListening();

      // 5. استدعاء الـ callback للطرد من الـ UI
      final callback = onForcedLogout ?? _onForcedLogout;
      callback?.call();
    } catch (e) {
      debugPrint('❌ KillSwitch._executeForcedLogout: $e');
    }
  }
}
