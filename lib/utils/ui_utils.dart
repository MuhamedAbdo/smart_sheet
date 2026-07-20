import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';
import 'package:smart_sheet/globals.dart';

class UIUtils {
  /// يعرض نافذة تأكيد الحذف
  static void showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
    String confirmLabel = "حذف",
    Color confirmColor = Colors.red,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// يعرض شريط تنفيذ (SnackBar) مع خيار التراجع مدته 4 ثوانٍ بالضبط
  /// يستخدم BuildContext لضمان الارتباط الموثوق بالشاشة الحالية
  static void showUndoSnackBar({
    required BuildContext context,
    required String message,
    required VoidCallback onUndo,
    VoidCallback? onDismissed,
  }) {
    final messenger = ScaffoldMessenger.of(context);

    // 1️⃣ تنظيف مضاعف (Double Cleaning): إخفاء أي شريط حالي فوراً ومسح الطابور
    messenger.hideCurrentSnackBar();
    messenger.clearSnackBars();

    // 2️⃣ عرض الشريط الجديد
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4), // المدة الأساسية: 4 ثوانٍ
        behavior: SnackBarBehavior.floating, // سلوك عائم لتجنب تغطية الأزرار
        elevation: 6,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF2C2C2C), // لون داكن بتباين ممتاز في كل الأوضاع
        action: SnackBarAction(
          label: 'تراجع',
          textColor: Colors.yellowAccent,
          onPressed: () {
            // مسح فوري عند الضغط على تراجع لضمان اختفاء الرسالة
            messenger.clearSnackBars();
            onUndo();
          },
        ),
      ),
    );

    // 3️⃣ صمام أمان (Safety Timer): التأكد من الإزالة بعد 4.5 ثوانٍ مهما كانت الظروف
    // نستخدم 4.5 ثوانٍ لإعطاء فرصة لمؤقت Flutter الأصلي أولاً لمنع الوميض
    Future.delayed(const Duration(milliseconds: 4500), () {
      try {
        messenger.clearSnackBars();
      } catch (_) {
        // تجاهل الأخطاء إذا كانت الشاشة قد أغلقت بالفعل
      }
    });

    snackBar.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        if (onDismissed != null) onDismissed();
      }
    });
  }

  /// يعرض شريط معلومات بسيط (بدون تراجع) لمدة 3 ثوانٍ
  static void showInfoSnackBar({
    required String message,
    Color? backgroundColor,
    IconData icon = Icons.info_outline,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo', // فرض الخط يدوياً
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? const Color(0xFF323232),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  /// يعرض شريط تقدم (Progress) لعمليات الاستعادة
  static void showProgressSnackBar({
    required String message,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Cairo', color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 30),
      ),
    );
  }

  /// يعرض شريط نجاح مع رسالة إعادة التشغيل
  static void showRestartSnackBar({
    required String message,
    required String subMessage,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subMessage,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// يعرض شريط إشعارات من أعلى الشاشة (In-App Overlay Alert) متوافق مع الديسكتوب
  static void showTopOverlay({
    required String title,
    required String message,
    VoidCallback? onTap,
    Color backgroundColor = Colors.green,
    IconData icon = Icons.notifications_active,
  }) {
    final messenger = scaffoldMessengerKey.currentState;
    final context = scaffoldMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    
    final mediaQuery = MediaQuery.of(context);
    
    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: InkWell(
          onTap: () {
            messenger.hideCurrentSnackBar();
            if (onTap != null) onTap();
          },
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      message,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: mediaQuery.size.height - 130, // دفعه لأعلى الشاشة
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static bool _isLocalNotifierSetup = false;
  static bool _isSetupInProgress = false;

  /// تأكيد تهيئة localNotifier من main.dart
  static void markLocalNotifierReady() {
    _isLocalNotifierSetup = true;
  }

  /// دالة مساعدة لعرض إشعار سطح المكتب (Windows Native Notification)
  /// تظهر في شريط إشعارات الويندوز حتى لو كان التطبيق مصغراً (Minimized) في شريط المهام
  static void showDesktopNotification({
    required String title,
    required String body,
    VoidCallback? onClick,
  }) async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      if (!_isLocalNotifierSetup) {
        if (_isSetupInProgress) {
          for (int i = 0; i < 20 && _isSetupInProgress; i++) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
        if (!_isLocalNotifierSetup) {
          _isSetupInProgress = true;
          try {
            await localNotifier.setup(
              appName: 'Smart Sheet',
              shortcutPolicy: ShortcutPolicy.requireCreate,
            );
            _isLocalNotifierSetup = true;
          } catch (e) {
            debugPrint('⚠️ [showDesktopNotification] localNotifier auto-setup failed: $e');
          } finally {
            _isSetupInProgress = false;
          }
        }
      }

      if (!_isLocalNotifierSetup) {
        debugPrint('⚠️ [showDesktopNotification] تم إلغاء عرض الإشعار لأن تهيئة local_notifier لم تنجح (تأكد من إعادة بناء التطبيق بالكامل بالـ C++ وليس Hot Reload).');
        return;
      }

      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.onClick = () async {
        try {
          // إعادة التركيز على النافذة وإظهارها عند الضغط على الإشعار من شريط المهام
          await windowManager.show();
          await windowManager.focus();
        } catch (e) {
          debugPrint('⚠️ [showDesktopNotification] Window focus error: $e');
        }
        if (onClick != null) {
          onClick();
        }
      };
      await notification.show();
      _isLocalNotifierSetup = true;
      debugPrint('🔔 [Windows Native Notification] Displayed: $title | $body');
    } catch (e) {
      debugPrint('⚠️ [Windows Native Notification] Error showing notification: $e');
    }
  }
}
