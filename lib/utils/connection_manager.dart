import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/config/constants.dart';
import 'dart:async';

/// مدير الاتصال للخطأ 7
class ConnectionManager {
  static Timer? _heartbeatTimer;
  static bool _isConnected = false;
  static int _retryCount = 0;

  /// تهيئة مدير الاتصال
  static void initialize() {
    debugPrint("🔗 Initializing Connection Manager...");
    _startHeartbeat();
    _monitorConnection();
  }

  /// بدء مراقبة نبضات القلب للاتصال
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkConnection();
    });
  }

  /// التحقق من حالة الاتصال
  static Future<void> _checkConnection() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      
      if (user == null) {
        _handleConnectionLost();
        return;
      }

      // محاولة عملية بسيطة للتحقق من الاتصال
      await client.from('profiles').select('id').limit(1).maybeSingle();
      
      if (!_isConnected) {
        _handleConnectionRestored();
      }
      
      _isConnected = true;
      _retryCount = 0;
      
    } catch (e) {
      debugPrint("❌ Connection check failed: $e");
      _handleConnectionLost();
    }
  }

  /// معالجة فقدان الاتصال
  static void _handleConnectionLost() {
    if (_isConnected) {
      debugPrint("⚠️ Connection lost");
      _isConnected = false;
    }
    
    _retryCount++;
    if (_retryCount <= maxRetries) {
      debugPrint("🔄 Attempting to reconnect... ($_retryCount/$maxRetries)");
      _attemptReconnection();
    } else {
      debugPrint("❌ Max retries reached. Connection failed.");
    }
  }

  /// معالجة استعادة الاتصال
  static void _handleConnectionRestored() {
    debugPrint("✅ Connection restored");
    _isConnected = true;
    _retryCount = 0;
  }

  /// محاولة إعادة الاتصال
  static Future<void> _attemptReconnection() async {
    try {
      await Future.delayed(Duration(seconds: _retryCount * 2));
      
      // محاولة إعادة تهيئة Supabase
      final client = Supabase.instance.client;
      await client.auth.refreshSession();
      
      debugPrint("✅ Reconnection successful");
      _handleConnectionRestored();
      
    } catch (e) {
      debugPrint("❌ Reconnection failed: $e");
    }
  }

  /// مراقبة حالة الاتصال بشكل مستمر
  static void _monitorConnection() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      if (event == AuthChangeEvent.tokenRefreshed) {
        debugPrint("🔄 Token refreshed");
        _handleConnectionRestored();
      } else if (event == AuthChangeEvent.signedOut) {
        debugPrint("👋 User signed out");
        _handleConnectionLost();
      }
    });
  }

  /// التحقق من الاتصال الحالي
  static bool get isConnected => _isConnected;

  /// الحصول على عدد محاولات إعادة الاتصال
  static int get retryCount => _retryCount;

  /// إيقاف مدير الاتصال
  static void dispose() {
    _heartbeatTimer?.cancel();
    debugPrint("🛑 Connection Manager disposed");
  }

  /// معالجة خطأ "Connection terminated during handshake"
  static Future<bool> handleHandshakeError() async {
    debugPrint("🤝 Handling handshake error...");
    
    try {
      // انتظار قصير قبل محاولة إعادة الاتصال
      await Future.delayed(const Duration(seconds: 2));
      
      // محاولة إعادة تهيئة الجلسة
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      
      if (user != null) {
        await client.auth.refreshSession();
        debugPrint("✅ Handshake error resolved");
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint("❌ Failed to resolve handshake error: $e");
      return false;
    }
  }
}
