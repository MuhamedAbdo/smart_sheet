// lib/src/models/user_state.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// هذا النموذج يستخدم لتتبع حالة المصادقة في التطبيق
class UserState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;
  final String? role;
  final String? factoryId;

  UserState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.role,
    this.factoryId,
  }) : isAuthenticated = user != null;

  // حالة التحميل
  UserState copyWith({
    User? user,
    bool? isLoading,
    String? errorMessage,
    String? role,
    String? factoryId,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      role: role ?? this.role,
      factoryId: factoryId ?? this.factoryId,
    );
  }

  // حالة غير مصادق (Logout)
  factory UserState.unauthenticated() {
    return UserState(user: null);
  }

  // حالة تحميل
  factory UserState.loading() {
    return UserState(user: null, isLoading: true);
  }

  // حالة مصادق
  factory UserState.authenticated(User user, {String? role, String? factoryId}) {
    return UserState(user: user, role: role, factoryId: factoryId);
  }
}
