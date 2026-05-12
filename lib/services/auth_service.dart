import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  UserState _state = UserState.unauthenticated();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  UserState get state => _state;
  bool get isAdmin => _state.role?.trim().toLowerCase() == 'admin';

  AuthService() {
    // 💡 الاستماع إلى تغيرات حالة Supabase
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      _onAuthStateChange(data.event, data.session);
    });

    // تحقق من الجلسة الأولية عند التشغيل
    _checkInitialSession();
  }

  // ✅ علم يمنع كتابة factory_id خلال عملية فك الارتباط أو بعدها
  static bool _isUnlinking = false;

  /// ✅ مفتاح التخزين بالإصدار 2 (لمنع قراءة قيم قديمة)
  static const _kFactoryIdKey = 'factory_id_v2';
  /// المفتاح القديم (نحذفه عند فك الارتباط لضمان عدم استعادة قيم قديمة)
  static const _kFactoryIdKeyLegacy = 'factory_id';

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    // ✅ إذا كنا بصدد فك الارتباط، تجاهل أي حدث auth
    if (_isUnlinking) {
      debugPrint('🚫 _onAuthStateChange: تجاهل حدث auth خلال فك الارتباط');
      return;
    }

    if (event == AuthChangeEvent.passwordRecovery) {
      // التوجه تلقائياً إلى شاشة تحديث كلمة المرور
      navigatorKey.currentState?.pushNamed('/update-password');
    }

    if (session != null) {
      // Keep existing role if available to avoid flicker before fetch
      _state = UserState.authenticated(session.user, role: _state.role);
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        _fetchAndStoreUserData(session.user.id);
      }
    } else {
      _state = UserState.unauthenticated();
      _clearUserData();
    }
    notifyListeners();
  }

  void _checkInitialSession() {
    // ✅ إذا كنا بصدد فك الارتباط، لا تجلب بيانات
    if (_isUnlinking) {
      debugPrint('🚫 _checkInitialSession: تجاهل خلال فك الارتباط');
      return;
    }
    final session = _supabaseClient.auth.currentSession;
    if (session != null) {
      _state = UserState.authenticated(session.user, role: _state.role);
      _fetchAndStoreUserData(session.user.id);
    } else {
      _state = UserState.unauthenticated();
      _clearUserData();
    }
    notifyListeners();
  }

  // ✅ مخزن موحد: يجب استخدام نفس AndroidOptions في كل مكان حتى يكون المخزن واحداً
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // encryptedSharedPreferences is deprecated and handled automatically by the library now
    ),
  );

  Future<void> _fetchAndStoreUserData(String userId) async {
    // ✅ الحارس الأول: إذا كنا بصدد فك الارتباط أو تم فك الارتباط، لا تكتب factory_id أبداً
    if (_isUnlinking || SyncService.isUnlinked) {
      debugPrint('🚫 _fetchAndStoreUserData: تم حجبه بسبب حالة فك الارتباط');
      return;
    }

    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('factory_id, role')
          .eq('id', userId)
          .maybeSingle();

      // ✅ تحقق مرة ثانية بعد انتظار الشبكة (async قد يتغير الوضع)
      if (_isUnlinking || SyncService.isUnlinked) {
        debugPrint('🚫 _fetchAndStoreUserData: تم حجبه بعد انتظار الشبكة');
        return;
      }

      if (response != null) {
        String? factoryId;
        if (response['factory_id'] != null) {
          factoryId = response['factory_id'].toString();
          // ✅ Key Rotation: نستخدم المفتاح الجديد _v2
          debugPrint('💾 [AUTH-WRITE] كتابة factory_id_v2 = $factoryId لـ userId=$userId');
          await _secureStorage.write(key: _kFactoryIdKey, value: factoryId);
        }

        final role = response['role']?.toString() ?? 'employee';
        debugPrint('💾 [AUTH-WRITE] كتابة user_role = $role');
        await _secureStorage.write(key: 'user_role', value: role);

        _state = _state.copyWith(role: role, factoryId: factoryId);
        notifyListeners();

        // تفعيل Real-time channels بعد تخزين factory_id
        // ✅ فقط إذا كان SyncService لم يُعاد ضبطه (لا نستدعيه بعد reset)
        try {
          if (!SyncService.isUnlinked) {
            unawaited(SyncService.instance.initialize());
          }
        } catch (e) {
          debugPrint('⚠️ Error initializing SyncService: $e');
        }
      } else {
        // Profile not found (could be due to RLS policies blocking the select)
        _state = _state.copyWith(
          errorMessage:
              'لم يتم العثور على ملف المستخدم. قد يكون بسبب سياسات الأمان (RLS) في Supabase.',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _clearUserData() async {
    // ✅ نفس المخزن الموحد - احذف كلا المفتاحين
    await _secureStorage.delete(key: _kFactoryIdKey);
    await _secureStorage.delete(key: _kFactoryIdKeyLegacy);
    await _secureStorage.delete(key: 'user_role');
    _state = _state.copyWith(factoryId: null);
    // ✅ تحقق أن _instance ليس null قبل استدعاء dispose
    try {
      if (!SyncService.isUnlinked) {
        unawaited(SyncService.instance.dispose());
      }
    } catch (e) {
      debugPrint('⚠️ _clearUserData: SyncService already reset: $e');
    }
  }

  /// 📧 تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<String?> signIn(
      {required String email, required String password}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // يتم تحديث الحالة تلقائيًا عبر stream listener
      return null; // نجاح
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// تحديث البيانات من السيرفر (مسح التخزين المؤقت)
  Future<String?> refreshUserData() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return "يرجى تسجيل الدخول أولاً";

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final oldRole = _state.role;
      const storage = FlutterSecureStorage();
      final oldFactoryId = await storage.read(key: 'factory_id');

      // مسح التخزين المحلي لإجبار جلب بيانات جديدة
      await storage.delete(key: 'factory_id');
      await storage.delete(key: 'user_role');

      // جلب البيانات من السيرفر وتحديث الحالة
      await _fetchAndStoreUserData(user.id);

      final newRole = _state.role;
      final newFactoryId = await storage.read(key: 'factory_id');

      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      if ((oldRole != null && oldRole != newRole) ||
          (oldFactoryId != null && oldFactoryId != newFactoryId)) {
        // تم تغيير الصلاحيات أو المصنع، يجب تسجيل الخروج للمزامنة الكاملة
        await signOut();
        return "⚠️ تم اكتشاف تغيير في الصلاحيات أو المصنع.\nتم تسجيل الخروج تلقائياً لضمان سلامة البيانات.";
      }

      return null; // نجاح التحديث بدون تغييرات حرجة
    } catch (e) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return "فشل التحديث: $e";
    }
  }

  /// 🔗 ربط الموظف بمصنع جديد عبر QR Code
  Future<String?> linkToFactory(String factoryId) async {
    // ✅ إعادة تعيين علم فك الارتباط للسماح بالكتابة مرة أخرى
    _isUnlinking = false;
    debugPrint('🟢 linkToFactory: _isUnlinking = false → فتح الكتابة مجدداً');

    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      // تحديث أو إنشاء ملف المستخدم في قاعدة البيانات
      await _supabaseClient.from('profiles').upsert({
        'id': user.id,
        'factory_id': factoryId,
        'role': 'employee',
      });

      // ✅ إعادة ضبط SyncService بالكامل قبل تحميل البيانات الجديدة
      SyncService.resetForNewLink();

      // تحديث الجلسة والبيانات لتفعيل الهوية الجديدة فوراً
      await refreshUserData();

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return null; // نجاح
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: 'فشل الربط: $e');
      notifyListeners();
      return 'فشل الربط: $e';
    }
  }

  /// 📝 إنشاء حساب جديد (تسجيل)
  Future<String?> signUp(
      {required String email, required String password}) async {
    // 1. بدء التحميل
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        // 💡 إضافة رابط إعادة التوجيه لفتح التطبيق عند الضغط على زر التفعيل في الإيميل
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      );

      // 2. إيقاف التحميل فوراً عند استلام رد من السيرفر
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      if (response.session == null) {
        // 💡 رسالة واضحة للمستخدم وتوجيهه للجيميل
        return '✅ تم إنشاء الحساب بنجاح!\n\nيرجى فتح بريدك الإلكتروني (Gmail) الآن والضغط على رابط التفعيل لتتمكن من الدخول إلى التطبيق.';
      }

      return null; // نجاح (في حال كان التفعيل التلقائي مفعلاً في Supabase)
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// � إعادة تعيين كلمة المرور
  Future<String?> resetPassword({required String email}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      return '✅ تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.\n\nيرجى فتح بريدك والضغط على الرابط لتعيين كلمة مرور جديدة.';
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// � تحديث كلمة المرور الجديدة
  Future<String?> updatePassword({required String newPassword}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      return '✅ تم تحديث كلمة المرور بنجاح';
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// 🚪 تسجيل الخروج
  Future<void> signOut() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();
    try {
      await _supabaseClient.auth.signOut();
      // يتم تحديث الحالة تلقائيًا عبر stream listener
    } catch (e) {
      _state = UserState.unauthenticated()
          .copyWith(errorMessage: 'فشل تسجيل الخروج: $e');
      notifyListeners();
    }
  }

  /// 🔓 فك الارتباط بالمصنع
  Future<String?> unlinkFactory() async {
    // ✅ الخطوة 0: أول شيء - رفع العلم لمنع أي كتابة لـ factory_id
    _isUnlinking = true;
    debugPrint('🚩 unlinkFactory: _isUnlinking = true → حجب أي كتابة لـ factory_id');

    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      // ✅ الخطوة 1: إيقاف SyncService أولاً قبل أي عملية حذف
      try {
        await SyncService.safeMarkAsUnlinked();
        SyncService.reset();
        debugPrint('🔄 SyncService stopped before unlink');
      } catch (e) {
        debugPrint('⚠️ Error stopping SyncService: $e');
      }

      // ✅ الخطوة 2: مسح الكاش البرمجي فوراً (قبل أي I/O)
      SupabaseManager.clearAllVariables();
      _state = _state.copyWith(factoryId: null);
      notifyListeners();

      // ✅ الخطوة 3: مسح التخزين الآمن بالكامل (كلا المفتاحين القديم والجديد)
      await _secureStorage.deleteAll(); // يمسح كل شيء
      debugPrint('🗑️ Cleared ALL secure storage data');

      // تحقق فوري أن الحذف نجح
      final checkV1 = await _secureStorage.read(key: _kFactoryIdKeyLegacy);
      final checkV2 = await _secureStorage.read(key: _kFactoryIdKey);
      debugPrint('🔍 [VERIFY-DELETE] factory_id=$checkV1 | factory_id_v2=$checkV2');
      if (checkV1 != null || checkV2 != null) {
        debugPrint('⚠️ [VERIFY-DELETE] القيم لا تزال موجودة! محاولة حذف فردي...');
        await _secureStorage.delete(key: _kFactoryIdKeyLegacy);
        await _secureStorage.delete(key: _kFactoryIdKey);
        await _secureStorage.delete(key: 'current_factory_key');
      }

      // انتظر لإعطاء نظام التشغيل وقتاً لتحديث ملفات التخزين
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ الخطوة 4: حذف أي بيانات مصنع من صندوق الإعدادات
      try {
        if (Hive.isBoxOpen('settings')) {
          final settingsBox = Hive.box('settings');
          await settingsBox.delete('factoryId');
          await settingsBox.delete('linkedFactoryCode');
          await settingsBox.delete('factory_name');
          await settingsBox.delete('factory_linked_at');
          debugPrint('🗑️ Cleared factory data from settings box');
        }
      } catch (e) {
        debugPrint('⚠️ Error clearing settings box: $e');
      }

      // ✅ الخطوة 5: إغلاق وحذف الصناديق المرتبطة بالمصنع
      await _clearFactoryBoxes();

      // ✅ الخطوة 6: تأكيد نهائي أن الحالة صفر
      _state = _state.copyWith(isLoading: false, factoryId: null);
      notifyListeners();

      debugPrint('✅ Factory unlinked successfully');
      return null; // نجاح
    } catch (e) {
      _isUnlinking = false; // إعادة تعيين العلم عند الخطأ
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'فشل فك الارتباط: $e');
      notifyListeners();
      debugPrint('❌ Error unlinking factory: $e');
      return 'فشل فك الارتباط: $e';
    }
    // ملاحظة: _isUnlinking يبقى true بشكل مقصود بعد النجاح
    // لمنع أي استعادة تلقائية. سيتم تصفيره فقط عند الربط بمصنع جديد
  }

  /// تنظيف الصناديق المرتبطة بالمصنع - إغلاق كامل وحذف
  Future<void> _clearFactoryBoxes() async {
    try {
      // إغلاق جميع صناديق Hive أولاً
      debugPrint('🔒 Closing all Hive boxes...');
      await Hive.close();

      // انتظر قليلاً للإغلاق الكامل
      await Future.delayed(const Duration(milliseconds: 100));

      // قائمة جميع الصناديق المرتبطة بالمصنع
      final allFactoryBoxes = [
        'workers',
        'workers_flexo',
        'workers_production',
        'flexo_live_sessions',
        'sync_queue',
        'store_flexo',
        'maintenance_records_main',
        'flexo_machines',
        'savedSheetSizes',
        'inkReports',
        'flexoArchive',
        'worker_actions',
        'finished_products',
      ];

      for (final boxName in allFactoryBoxes) {
        try {
          // حذف الصندوق بالكامل من القرص
          await Hive.deleteBoxFromDisk(boxName);
          debugPrint('🗑️ Deleted box from disk: $boxName');
        } catch (e) {
          debugPrint('⚠️ Failed to delete box $boxName from disk: $e');
        }
      }

      debugPrint('✅ All factory boxes processed successfully');
    } catch (e) {
      debugPrint('❌ Error clearing factory boxes: $e');
    }
  }

  /// 🔍 الحصول على factory_id من التخزين المحلي
  Future<String?> getFactoryId() async {
    try {
      // ✅ قراءة المفتاح الجديد أولاً، مع تراجع للقديم إن لزم
      final v2 = await _secureStorage.read(key: _kFactoryIdKey);
      if (v2 != null) return v2;
      // Fallback للمفتاح القديم (للمستخدمين الذين كان عندهم بيانات قبل التحديث)
      return await _secureStorage.read(key: _kFactoryIdKeyLegacy);
    } catch (e) {
      debugPrint('Error getting factory_id: $e');
      return null;
    }
  }

  /// 🔄 تحديث factory_id (يستخدم عند ربط المصنع)
  void updateFactoryId(String? factoryId) {
    _state = _state.copyWith(factoryId: factoryId);
    notifyListeners();
    debugPrint('🔄 FactoryId updated to: $factoryId');
  }

  /// 🔄 تحديث factory_id من التخزين (يستخدم عند ربط مصنع جديد)
  Future<void> refreshFactoryIdFromStorage() async {
    try {
      // ✅ قراءة المفتاح الجديد أولاً، مع تراجع للقديم
      final factoryId = await getFactoryId();

      // تحديث الحالة بناءً على القيمة الفعلية في التخزين
      _state = _state.copyWith(factoryId: factoryId);
      notifyListeners();

      debugPrint('🔄 FactoryId refreshed from storage: $factoryId');
    } catch (e) {
      debugPrint('❌ Error refreshing factoryId: $e');
    }
  }

  /// مسح المتغيرات البرمجية في AuthService
  void clearGlobalVariables() {
    _state = _state.copyWith(factoryId: null);
    debugPrint('🧹 AuthService: Global variables cleared');
  }
}
