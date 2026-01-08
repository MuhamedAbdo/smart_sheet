// lib/src/models/user_state.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// هذا النموذج يستخدم لتتبع حالة المصادقة في التطبيق
class UserState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  UserState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  }) : isAuthenticated = user != null;

  // حالة التحميل
  UserState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  // حالة غير مصادق (Logout)
  factory UserState.unauthenticated() {
    // ✅ الإصلاح: إزالة تمرير isAuthenticated لأنها تحسب تلقائياً في constructor الرئيسي
    return UserState(user: null);
  }

  // حالة تحميل
  factory UserState.loading() {
    // ✅ الإصلاح
    return UserState(user: null, isLoading: true);
  }

  // حالة مصادق
  factory UserState.authenticated(User user) {
    // ✅ الإصلاح
    return UserState(user: user);
  }
}
