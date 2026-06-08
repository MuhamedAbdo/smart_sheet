import 'dart:async';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_state.dart';
import 'package:flutter/material.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/pairing_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  UserState _state = UserState.unauthenticated();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  UserState get state => _state;
  bool get isAuthenticated => Hive.box('settings').get('is_user_logged_in', defaultValue: false) == true;
  String? get factoryId => _factoryId;
  bool get isAdmin => _state.role?.trim().toLowerCase() == 'admin';
  String? get currentUserEmail => _state.user?.email;
  String? _factoryId;

  AuthService() {
    // 💡 الاستماع إلى تغيرات حالة Supabase
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      _onAuthStateChange(data.event, data.session);
    });

    // تحقق من الجلسة الأولية عند التشغيل
    _checkInitialSession();
    _loadFactoryId();
  }

  Future<void> _loadFactoryId() async {
    const storage = SafeSecureStorage();
    _factoryId = await storage.read(key: 'factory_id');
    notifyListeners();
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    if (event == AuthChangeEvent.passwordRecovery) {
      // التوجه تلقائياً إلى شاشة تحديث كلمة المرور
      navigatorKey.currentState?.pushNamed('/update-password');
    }
    
    if (session != null) {
      // Keep existing role if available to avoid flicker before fetch
      _state = UserState.authenticated(session.user, role: _state.role);
      Hive.box('settings').put('is_user_logged_in', true);
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        _fetchAndStoreUserData(session.user.id);
      }
    } else {
      final isLocalLoggedIn = Hive.box('settings').get('is_user_logged_in', defaultValue: false) == true;
      if (!isLocalLoggedIn) {
        _state = UserState.unauthenticated();
        _clearUserData();
      }
    }
    notifyListeners();
  }

  void _checkInitialSession() {
    final session = _supabaseClient.auth.currentSession;
    final isLocalLoggedIn = Hive.box('settings').get('is_user_logged_in', defaultValue: false) == true;

    if (session != null) {
      _state = UserState.authenticated(session.user, role: _state.role);
      Hive.box('settings').put('is_user_logged_in', true);
      _fetchAndStoreUserData(session.user.id);
    } else if (isLocalLoggedIn) {
      final user = _supabaseClient.auth.currentUser;
      if (user != null) {
        _state = UserState.authenticated(user, role: _state.role);
        _fetchAndStoreUserData(user.id);
      } else {
        _state = UserState.authenticated(
          const User(
            id: 'local_cached_user',
            appMetadata: {},
            userMetadata: {},
            aud: '',
            createdAt: '',
          ),
          role: _state.role,
        );
        _loadCachedRoleAndInitSync();
      }
    } else {
      _state = UserState.unauthenticated();
      _clearUserData();
    }
    notifyListeners();
  }

  Future<void> _loadCachedRoleAndInitSync() async {
    try {
      const storage = SafeSecureStorage();
      final role = await storage.read(key: 'user_role') ?? 'employee';
      _factoryId = await storage.read(key: 'factory_id');
      _state = _state.copyWith(role: role);
      notifyListeners();
      if (_factoryId != null) {
        await SyncService.instance.initialize();
      }
    } catch (e) {
      debugPrint('Error loading cached user data: $e');
    }
  }

  Future<void> _fetchAndStoreUserData(String userId) async {
    try {
      const storage = SafeSecureStorage();
      
      final response = await _supabaseClient
          .from('profiles')
          .select('factory_id, role')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        final role = response['role']?.toString() ?? 'employee';
        await storage.write(key: 'user_role', value: role);
        
        _factoryId = response['factory_id']?.toString();
        if (_factoryId != null) {
          await storage.write(key: 'factory_id', value: _factoryId!);
        } else {
          await storage.delete(key: 'factory_id');
        }
        
        _state = _state.copyWith(role: role);
        notifyListeners();

        // تفعيل Real-time channels والمزامنة المبدئية بعد تخزين factory_id
        await SyncService.instance.initialize();
      } else {
        // Profile not found (could be due to RLS policies blocking the select)
        _state = _state.copyWith(
          errorMessage: 'لم يتم العثور على ملف المستخدم. قد يكون بسبب سياسات الأمان (RLS) في Supabase.',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _clearUserData() async {
    const storage = SafeSecureStorage();
    await storage.delete(key: 'factory_id');
    await storage.delete(key: 'user_role');
    _factoryId = null;
    // إلغاء Real-time channels عند تسجيل الخروج
    unawaited(SyncService.instance.dispose());
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
      const storage = SafeSecureStorage();
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

      if ((oldRole != null && oldRole != newRole) || (oldFactoryId != null && oldFactoryId != newFactoryId)) {
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

  /// 🔗 ربط الموظف بمصنع جديد عبر QR Code أو كود يدوي
  Future<String?> linkToFactory(String inputCode) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      String factoryId = inputCode.trim();

      // إذا كان الكود قصيراً (6 خانات أو أقل)، نتحقق من خدمة الربط
      if (factoryId.length <= 6) {
        final pairingResult = await PairingService().verifyAndLink(factoryId);
        
        if (pairingResult != null && pairingResult['success'] == true) {
          factoryId = pairingResult['factory_id'];
          debugPrint('✅ Resolved pairing code $inputCode to $factoryId');
        } else {
          throw Exception(pairingResult?['error'] ?? 'كود الربط غير صحيح أو منتهي الصلاحية');
        }
      }

      // تحديث أو إنشاء ملف المستخدم في قاعدة البيانات
      await _supabaseClient.from('profiles').upsert({
        'id': user.id,
        'factory_id': factoryId,
        'role': 'employee',
      });

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

  /// �🚪 تسجيل الخروج
  Future<void> signOut() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();
    try {
      await Hive.box('settings').put('is_user_logged_in', false);
      await _supabaseClient.auth.signOut();
      // يتم تحديث الحالة تلقائيًا عبر stream listener
    } catch (e) {
      _state = UserState.unauthenticated()
          .copyWith(errorMessage: 'فشل تسجيل الخروج: $e');
      notifyListeners();
    }
  }

  /// 🔓 فك ارتباط الجهاز بالمصنع الحالي (مسح factory_id محلياً ومن السيرفر)
  Future<void> unlinkFactory() async {
    const storage = SafeSecureStorage();
    await storage.delete(key: 'factory_id');
    _factoryId = null;
    
    // إيقاف القنوات
    unawaited(SyncService.instance.dispose());

    // تحديث قاعدة البيانات لمسح factory_id من حساب المستخدم
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user != null) {
        await _supabaseClient.from('profiles').update({'factory_id': null}).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error clearing factory_id from profiles: $e');
    }
    
    notifyListeners();
  }
}
