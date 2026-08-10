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
import 'package:smart_sheet/services/push_notification_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
class KillSwitchService {
  // ─── Singleton ─────────────────────────────────────────────────────────────
  static final KillSwitchService instance = KillSwitchService._internal();
  KillSwitchService._internal();

  // ─── حقول داخلية ───────────────────────────────────────────────────────────
  final SupabaseClient _supabase = Supabase.instance.client;
  static const _storage = SafeSecureStorage();

  RealtimeChannel? _workerChannel;
  RealtimeChannel? _factoryChannel;

  // Callback يُستدعى عند اكتشاف الطرد القسري مع سبب الطرد (يُمرَّر من main.dart)
  Function(String message)? _onForcedLogout;

  // ==============================================================================
  // Public API
  // ==============================================================================

  /// بدء الاستماع لتغييرات جهاز العامل المحدد عبر Supabase Realtime.
  ///
  /// [workerId]        : معرّف سجل العامل في جدول workers
  /// [onForcedLogout]  : callback يُستدعى فور اكتشاف فك الارتباط
  Future<void> startListening({
    required String factoryId,
    String? workerId,
    required Function(String message) onForcedLogout,
  }) async {
    await stopListening(); // إغلاق أي قناة سابقة

    _onForcedLogout = onForcedLogout;

    debugPrint('🔒 KillSwitch: بدء الاستماع | factoryId=$factoryId | workerId=$workerId');

    // 1. استماع لجدول المصانع (لكافة المستخدمين)
    _factoryChannel = _supabase
        .channel('kill_switch_factory_$factoryId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'factories',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'factory_id',
            value: factoryId,
          ),
          callback: _handleFactoryUpdate,
        )
        .subscribe();

    // 2. استماع لجدول العمال (للعمال المحددين فقط)
    if (workerId != null && workerId.isNotEmpty) {
      final localDeviceId = await DeviceManager.getDeviceId();
      _workerChannel = _supabase
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
          .subscribe();
    }
  }

  /// إيقاف الاستماع وإغلاق القناة.
  Future<void> stopListening() async {
    if (_workerChannel != null) {
      try { await _supabase.removeChannel(_workerChannel!); } catch (_) {}
      _workerChannel = null;
    }
    if (_factoryChannel != null) {
      try { await _supabase.removeChannel(_factoryChannel!); } catch (_) {}
      _factoryChannel = null;
    }
    debugPrint('🔒 KillSwitch: تم إغلاق قنوات المراقبة');

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

      // جلب FCM Token لحفظه مع معرّف الجهاز
      final fcmToken = await PushNotificationService.getToken();

      await _supabase
          .from('workers')
          .update({
            'device_id': deviceId,
            'is_device_linked': true,
            if (fcmToken != null && fcmToken.isNotEmpty) 'fcm_token': fcmToken,
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
  Future<bool> checkAndEnforceKillSwitch({Function(String)? onForcedLogout}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('⏭️ KillSwitch: لا يوجد مستخدم مسجل دخول في Auth.');
        return false;
      }

      // 1. حماية السوبر آدمن
      if (user.email == 'mohamedabdo9999933@gmail.com') {
        debugPrint('⏭️ KillSwitch: تخطي الفحص لحساب Super Admin.');
        return false;
      }

      String? factoryId;

      // 2. جلب factory_id من profiles باستخدام single() الإجبارية
      try {
        debugPrint('⏳ KillSwitch: جاري فحص جدول profiles...');
        final profileData = await _supabase
            .from('profiles')
            .select('factory_id')
            .eq('id', user.id)
            .single(); 
            
        factoryId = profileData['factory_id'] as String?;
        debugPrint('✅ KillSwitch: تم العثور على factory_id: $factoryId');
        
      } on PostgrestException catch (e) {
        // PGRST116 يعني أن RLS منع القراءة = المصنع موقوف!
        if (e.code == 'PGRST116') {
           debugPrint('🚨 KillSwitch: تم حجب البروفايل (RLS Block). المصنع موقوف!');
           await forceLogout(
             onForcedLogout: onForcedLogout,
             clearProfileFactoryId: false,
             reason: 'تم إيقاف اشتراك هذا المصنع. يرجى التواصل مع الإدارة.'
           );
           return true;
        }
        debugPrint('⚠️ KillSwitch: خطأ في الشبكة أو قاعدة البيانات: ${e.message}');
      }

      // إذا لم يجد المصنع في السيرفر، نحاول جلبه من التخزين المحلي كخطة بديلة
      factoryId ??= await _storage.read(key: 'factory_id');

      if (factoryId == null) {
        debugPrint('⏭️ KillSwitch: غير ممكّن (غير مرتبط بمصنع).');
        return false;
      }

      // 3. التأكد من حالة المصنع في جدول factories
      try {
        debugPrint('⏳ KillSwitch: جاري فحص حالة المصنع $factoryId...');
        final factoryRecord = await _supabase
            .from('factories')
            .select('status')
            .eq('factory_id', factoryId)
            .single();

        if (factoryRecord['status'] == 'suspended') {
           debugPrint('🚨 KillSwitch: المصنع موقوف صراحة (status = suspended).');
           await forceLogout(
             onForcedLogout: onForcedLogout,
             clearProfileFactoryId: false,
             reason: 'تم إيقاف اشتراك هذا المصنع. يرجى التواصل مع الإدارة.'
           );
           return true;
        }
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST116') {
           debugPrint('🚨 KillSwitch: تم حجب المصنع (RLS Block). المصنع موقوف!');
           await forceLogout(
             onForcedLogout: onForcedLogout,
             clearProfileFactoryId: false,
             reason: 'تم إيقاف اشتراك هذا المصنع. يرجى التواصل مع الإدارة.'
           );
           return true;
        }
        debugPrint('⚠️ KillSwitch: خطأ في فحص المصنع: ${e.message}');
      }

      debugPrint('✅ KillSwitch: المصنع نشط والأمور طبيعية.');
      return false;

    } catch (e) {
      debugPrint('❌ KillSwitch خطأ عام: $e');
      return false;
    }
  }

  /// معالجة أي تحديث يصل من WorkersSync لجدول workers وتنفيذ الطرد فوراً إذا كان يخص هذا الجهاز.
  Future<void> handleRealtimeWorkerRecord(Map<String, dynamic> record, {Function(String)? onForcedLogout}) async {
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

      final bool isLinked = record['is_device_linked'] as bool? ?? true;
      final String? remoteDeviceId = record['device_id']?.toString();
      final localDeviceId = await DeviceManager.getDeviceId();

      // ✅ إصلاح: التمييز بين تحديث الصلاحيات وفك الارتباط الحقيقي
      //
      // حالة الطرد الشرعي:
      //   1. is_device_linked = false  → الأدمن فكّ الارتباط صراحةً
      //   2. device_id موجود ومختلف عن الجهاز الحالي → نُقل لجهاز آخر
      //
      // حالة التحديث الآمن (صلاحيات):
      //   - is_device_linked = true (أو null لم يُرسل) + device_id = null أو مطابق → لا طرد
      //
      // ⚠️ device_id = null مع is_device_linked = true يعني أن الأدمن عدّل الصلاحيات
      // دون إرسال حقل device_id (أرسل فقط can_add, can_edit, ...etc) → لا طرد!
      final bool isExplicitUnlink = !isLinked;
      final bool isDeviceHijacked = (remoteDeviceId != null &&
          remoteDeviceId.isNotEmpty &&
          remoteDeviceId != localDeviceId);

      if (isExplicitUnlink) {
        debugPrint('🚨 KillSwitch: الإدارة قامت بفك ارتباط الجهاز صراحةً! تنفيذ الطرد القسري...');
        await forceLogout(onForcedLogout: onForcedLogout, reason: 'تم فك ارتباط الجهاز بواسطة الإدارة.');
      } else if (isDeviceHijacked) {
        debugPrint('🔧 KillSwitch: اكتشاف تعارض في الـ device_id من Realtime. جاري الإصلاح الذاتي (Self-Healing)...');
        try {
          if (recordId != null) {
            await _supabase.from('workers').update({'device_id': localDeviceId}).eq('id', recordId);
            debugPrint('✅ KillSwitch: تم الإصلاح الذاتي وتحديث device_id في السحابة.');
          }
        } catch(e) {
          debugPrint('⚠️ KillSwitch: فشل الإصلاح الذاتي: $e');
        }
      } else {
        // ✅ تحديث آمن للصلاحيات — لا داعي للطرد
        debugPrint('ℹ️ KillSwitch: تحديث صلاحيات آمن للعامل — لا طرد.');
        debugPrint('  is_device_linked=$isLinked | remote=${remoteDeviceId ?? "(لم يُرسل)"} | local=$localDeviceId');
      }
    } catch (e) {
      debugPrint('⚠️ KillSwitch.handleRealtimeWorkerRecord: $e');
    }
  }

  // ==============================================================================
  // Private: معالجة تغييرات Realtime
  // ==============================================================================

  void _handleFactoryUpdate(PostgresChangePayload payload) {
    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;
      
      if (newRecord['status'] == 'suspended') {
        debugPrint('🚨 KillSwitch (_handleFactoryUpdate): المصنع موقوف مؤقتاً! تنفيذ الطرد القسري...');
        forceLogout(reason: 'تم إيقاف اشتراك هذا المصنع. يرجى التواصل مع الإدارة.');
      }
    } catch (e) {
      debugPrint('❌ KillSwitch._handleFactoryUpdate: $e');
    }
  }

  void _handleWorkerUpdate(
      PostgresChangePayload payload, String localDeviceId) {
    try {
      final newRecord = payload.newRecord;
      if (newRecord.isEmpty) return;

      final bool isDeviceLinked = newRecord['is_device_linked'] as bool? ?? true;
      final String? remoteDeviceId = newRecord['device_id']?.toString();

      debugPrint(
          '🔒 KillSwitch: تغيير مُكتشَف | is_device_linked=$isDeviceLinked | remote=$remoteDeviceId | local=$localDeviceId');

      // ✅ إصلاح: فقط حالتا الطرد الشرعي:
      // 1. is_device_linked = false صراحةً (فك ارتباط من الـ Admin)
      // 2. device_id موجود وغير فارغ ومختلف عن الجهاز الحالي (جهاز آخر)
      //
      // إذا كان device_id = null مع is_device_linked = true → تحديث صلاحيات آمن → لا طرد.
      final bool isExplicitUnlink = !isDeviceLinked;
      final bool isDeviceHijacked = (remoteDeviceId != null &&
          remoteDeviceId.isNotEmpty &&
          remoteDeviceId != localDeviceId);

      if (isExplicitUnlink) {
        debugPrint('🚨 KillSwitch (_handleWorkerUpdate): الإدارة قامت بفك ارتباط الجهاز صراحةً! تنفيذ الطرد القسري...');
        forceLogout(reason: 'تم فك ارتباط الجهاز بواسطة الإدارة.');
      } else if (isDeviceHijacked) {
        final workerId = newRecord['id']?.toString();
        if (workerId != null) {
          debugPrint('🔧 KillSwitch (_handleWorkerUpdate): تعارض device_id. جاري الإصلاح الذاتي (Self-Healing)...');
          try {
            _supabase.from('workers').update({'device_id': localDeviceId}).eq('id', workerId);
          } catch(e) {
            debugPrint('⚠️ KillSwitch: فشل الإصلاح الذاتي عبر التحديث المباشر: $e');
          }
        }
      } else {
        debugPrint('ℹ️ KillSwitch (_handleWorkerUpdate): تحديث صلاحيات آمن — لا طرد.');
      }
    } catch (e) {
      debugPrint('❌ KillSwitch._handleWorkerUpdate: $e');
    }
  }

  Future<void> forceLogout({
    Function(String)? onForcedLogout,
    bool clearProfileFactoryId = true,
    String reason = 'تم إغلاق الجلسة بواسطة الإدارة',
  }) async {
    try {
      // 0. تصفير factory_id في السحاب (profiles) للمستخدم الحالي لمنع إعادة ربطه تلقائياً عند تسجيل الدخول مجدداً
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null && clearProfileFactoryId) {
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

      // 1b. المسح الشامل لجميع بيانات التطبيق المحلية (ويندوز وأندرويد)
      try {
        await Hive.close(); // إغلاق جميع صناديق Hive لتحرير الملفات
        
        final appDir = await getApplicationDocumentsDirectory();
        Directory dataDir;
        if (Platform.isWindows) {
          dataDir = Directory(p.join(appDir.path, 'SmartSheet_Data'));
        } else {
          dataDir = appDir;
        }

        if (dataDir.existsSync()) {
          dataDir.deleteSync(recursive: true);
          debugPrint('✅ KillSwitch: تم مسح مجلد البيانات بالكامل بنجاح!');
        }
      } catch (e) {
        debugPrint('⚠️ KillSwitch: فشل مسح مجلد البيانات: $e');
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
      callback?.call(reason);
    } catch (e) {
      debugPrint('❌ KillSwitch._executeForcedLogout: $e');
    }
  }
}

