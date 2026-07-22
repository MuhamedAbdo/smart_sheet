// lib/services/push_notification_service.dart
//
// خدمة Firebase Cloud Messaging (FCM) المركزية
//
// المسؤوليات:
//   1. init()           — تهيئة Firebase + طلب الصلاحيات + تسجيل الـ handlers
//   2. getToken()       — استخراج FCM Token الجهاز الحالي
//   3. uploadToken()    — رفع/تحديث الـ Token في Supabase workers table
//   4. Foreground       — عرض local notification عند وصول إشعار والتطبيق مفتوح
//   5. Background       — handler معزول يعمل حتى عند إغلاق التطبيق
//   6. Token Refresh    — تحديث تلقائي عند تجديد Firebase للـ Token
//
// ⚠️  يعمل على Android فقط — Desktop يستمر على Supabase Realtime
//
// الاستخدام:
//   await PushNotificationService.init();               // في main()
//   await PushNotificationService.uploadToken(email);   // بعد تسجيل الدخول

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Background Handler — يجب أن يكون دالة top-level (خارج أي كلاس) ─────────
// يُستدعى من Flutter Engine معزول عند وصول إشعار والتطبيق مغلق/خلفية
// ⚠️ يجب أن تكون top-level function (خارج أي كلاس) و public
// ⚠️ يجب تسجيلها في main() مباشرةً بعد Firebase.initializeApp() وقبل runApp()
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  // تهيئة Firebase في الـ isolate المعزول
  await Firebase.initializeApp();
  debugPrint('📬 [FCM Background] ${message.notification?.title}: ${message.notification?.body}');
  // نظهر local notification يدوياً في الخلفية
  await _showLocalFromRemote(message);
}

/// عرض إشعار محلي من RemoteMessage — يُستدعى من الـ background handler
Future<void> _showLocalFromRemote(RemoteMessage message) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(const InitializationSettings(android: androidSettings));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'factory_push_channel',
        'إشعارات المصنع',
        channelDescription: 'إشعارات Push الحقيقية من المصنع',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await plugin.show(
      message.hashCode,
      message.notification?.title ?? 'إشعار جديد',
      message.notification?.body ?? '',
      details,
    );
  } catch (e) {
    debugPrint('❌ [FCM] _showLocalFromRemote: $e');
  }
}

class PushNotificationService {
  // Singleton
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ══════════════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════════════

  /// تهيئة كاملة — استدعِها مرة واحدة في main() بعد Firebase.initializeApp()
  static Future<void> init() async {
    // Android فقط — Desktop يعمل بـ Realtime
    if (kIsWeb || !Platform.isAndroid) return;
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. طلب صلاحية الإشعارات من المستخدم
      //    (تسجيل Background Handler يتم من main() مباشرةً قبل runApp)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('📋 [FCM] صلاحية الإشعارات: ${settings.authorizationStatus}');

      // 2. إنشاء وتوثيق قناة الإشعارات في نظام Android (شرط أساسي لـ High Priority في الخلفية)
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'factory_push_channel',
        'إشعارات المصنع',
        description: 'إشعارات Push الحقيقية من المصنع',
        importance: Importance.max,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 3. تهيئة Local Notifications لعرض الإشعارات في Foreground
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidSettings),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // 4. إجبار Android على عرض الإشعارات حتى عندما التطبيق في المقدمة
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. الاستماع للإشعارات عند فتح التطبيق (Foreground)
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // 6. الاستماع عند فتح التطبيق بالضغط على إشعار خلفي
      FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpenedApp);

      // 7. الاستماع لتحديث التوكن
      _messaging.onTokenRefresh.listen(_onTokenRefresh);

      debugPrint('✅ [FCM] PushNotificationService: تمت التهيئة بنجاح.');
    } catch (e) {
      debugPrint('❌ [FCM] init error: $e');
    }
  }

  /// استخراج FCM Token الجهاز الحالي
  static Future<String?> getToken() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final token = await _messaging.getToken();
      debugPrint('🔑 [FCM] Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ [FCM] getToken error: $e');
      return null;
    }
  }

  /// رفع الـ FCM Token إلى Supabase workers table بواسطة email العامل
  /// استدعِها بعد تسجيل الدخول وبعد ربط الجهاز بالمصنع
  static Future<void> uploadToken(String email) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      if (email.isEmpty) return;

      await Supabase.instance.client
          .from('workers')
          .update({'fcm_token': token})
          .eq('email', email);

      debugPrint('✅ [FCM] Token محفوظ في Supabase للعامل: $email');
    } catch (e) {
      debugPrint('❌ [FCM] uploadToken error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Private Handlers
  // ══════════════════════════════════════════════════════════════════════

  /// معالجة الإشعار عندما التطبيق مفتوح (Foreground)
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint('📬 [FCM Foreground] ${message.notification?.title}: ${message.notification?.body}');
    // نعرض إشعاراً محلياً لأن FCM لا يُظهره تلقائياً في Foreground على Android
    await _showLocalFromRemote(message);
  }

  /// معالجة النقر على الإشعار من الخلفية (التطبيق يُفتح به)
  static void _onNotificationOpenedApp(RemoteMessage message) {
    debugPrint('🔔 [FCM] فتح التطبيق عبر الإشعار: ${message.notification?.title}');
    // يمكن إضافة navigation هنا لاحقاً إذا احتجنا
  }

  /// تحديث التوكن تلقائياً عند تجديد Firebase له
  static Future<void> _onTokenRefresh(String newToken) async {
    debugPrint('🔄 [FCM] Token تم تجديده تلقائياً.');
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        await Supabase.instance.client
            .from('workers')
            .update({'fcm_token': newToken})
            .eq('email', email);
        debugPrint('✅ [FCM] Token الجديد محفوظ في Supabase.');
      }
    } catch (e) {
      debugPrint('❌ [FCM] onTokenRefresh upload error: $e');
    }
  }

  /// معالجة النقر على الإشعار المحلي
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 [FCM] تم النقر على الإشعار المحلي: ${response.payload}');
    // يمكن إضافة navigation هنا لاحقاً
  }
}
