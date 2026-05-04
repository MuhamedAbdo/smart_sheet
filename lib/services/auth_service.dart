import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smart_sheet/services/sync_service.dart';
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

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    if (event == AuthChangeEvent.passwordRecovery) {
      // التوجه تلقائياً إلى شاشة تحديث كلمة المرور
      navigatorKey.currentState?.pushNamed('/update-password');
    }
    
    if (session != null) {
      // Keep existing role if available to avoid flicker before fetch
      _state = UserState.authenticated(session.user, role: _state.role);
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        _fetchAndStoreUserData(session.user.id);
      }
    } else {
      _state = UserState.unauthenticated();
      _clearUserData();
    }
    notifyListeners();
  }

  void _checkInitialSession() {
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

  Future<void> _fetchAndStoreUserData(String userId) async {
    try {
      const storage = FlutterSecureStorage();
      
      final response = await _supabaseClient
          .from('profiles')
          .select('factory_id, role')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        if (response['factory_id'] != null) {
          await storage.write(key: 'factory_id', value: response['factory_id'].toString());
        }
        
        final role = response['role']?.toString() ?? 'employee';
        await storage.write(key: 'user_role', value: role);
        
        _state = _state.copyWith(role: role);
        notifyListeners();

        // تفعيل Real-time channels بعد تخزين factory_id
        unawaited(SyncService.instance.initialize());
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
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'factory_id');
    await storage.delete(key: 'user_role');
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

  /// 🔗 ربط الموظف بمصنع جديد عبر QR Code
  Future<String?> linkToFactory(String factoryId) async {
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
      await _supabaseClient.auth.signOut();
      // يتم تحديث الحالة تلقائيًا عبر stream listener
    } catch (e) {
      _state = UserState.unauthenticated()
          .copyWith(errorMessage: 'فشل تسجيل الخروج: $e');
      notifyListeners();
    }
  }
}
