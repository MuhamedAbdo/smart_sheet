import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_state.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  UserState _state = UserState.unauthenticated();

  UserState get state => _state;

  AuthService() {
    // 💡 الاستماع إلى تغيرات حالة Supabase
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      _onAuthStateChange(data.event, data.session);
    });

    // تحقق من الجلسة الأولية عند التشغيل
    _checkInitialSession();
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    if (session != null) {
      _state = UserState.authenticated(session.user);
    } else {
      _state = UserState.unauthenticated();
    }
    notifyListeners();
  }

  void _checkInitialSession() {
    final session = _supabaseClient.auth.currentSession;
    if (session != null) {
      _state = UserState.authenticated(session.user);
    } else {
      _state = UserState.unauthenticated();
    }
    notifyListeners();
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
}
