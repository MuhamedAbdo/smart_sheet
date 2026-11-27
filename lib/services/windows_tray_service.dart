import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// خدمة إدارة أيقونة النظام (System Tray) والتشغيل التلقائي وإدارة النوافذ لنظام Windows فقط.
class WindowsTrayService with TrayListener, WindowListener {
  static final WindowsTrayService instance = WindowsTrayService._internal();
  WindowsTrayService._internal();

  bool _isInitialized = false;

  /// تهيئة الخدمة وإعداد الصينية والتشغيل التلقائي
  Future<void> init({bool isAutoStart = false}) async {
    if (kIsWeb || !Platform.isWindows) return;
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      // 1. تسجيل المستمعين لأحداث الأيقونة والنافذة
      trayManager.addListener(this);
      windowManager.addListener(this);

      // 2. تفعيل منع الإغلاق الفوري ليتم إخفاء النافذة بدلاً من إغلاق التطبيق
      await windowManager.setPreventClose(true);

      // 3. إعداد أيقونة الصينية والتلميح
      // على ويندوز، يبحث tray_manager داخل data/flutter_assets/<iconPath>
      await trayManager.setIcon('assets/images/app_icon.ico');
      await trayManager.setToolTip('Smart Sheet');

      // 4. إعداد القائمة المنبثقة (Context Menu) - خيارين فقط
      final Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'فتح التطبيق',
            onClick: (_) => showAppWindow(),
          ),
          MenuItem(
            key: 'exit_app',
            label: 'إغلاق نهائي (Exit)',
            onClick: (_) => exitApp(),
          ),
        ],
      );
      await trayManager.setContextMenu(menu);

      // 5. إعداد وتفعيل التشغيل التلقائي مع الويندوز بوسيط --autostart
      await _setupLaunchAtStartup();

      debugPrint('✅ [WindowsTrayService] System tray service initialized successfully.');
    } catch (e) {
      debugPrint('⚠️ [WindowsTrayService] Initialization error: $e');
    }
  }

  /// إعداد التشغيل التلقائي مع الويندوز عند بدء التشغيل
  Future<void> _setupLaunchAtStartup() async {
    try {
      PackageInfo? packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (_) {}

      final appName = (packageInfo != null && packageInfo.appName.isNotEmpty)
          ? packageInfo.appName
          : 'Smart Sheet';

      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
        args: const <String>['--autostart'],
      );

      final isEnabled = await launchAtStartup.isEnabled();
      if (!isEnabled) {
        await launchAtStartup.enable();
        debugPrint('✅ [LaunchAtStartup] Enabled successfully with arg --autostart');
      } else {
        debugPrint('ℹ️ [LaunchAtStartup] Already enabled.');
      }
    } catch (e) {
      debugPrint('⚠️ [LaunchAtStartup] Setup error: $e');
    }
  }

  /// إظهار نافذة التطبيق والتركيز عليها
  Future<void> showAppWindow() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final isMinimized = await windowManager.isMinimized();
      if (isMinimized) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
      debugPrint('🪟 [WindowsTrayService] Window restored & focused.');
    } catch (e) {
      debugPrint('⚠️ [WindowsTrayService] Error showing window: $e');
    }
  }

  /// إخفاء نافذة التطبيق إلى الخلفية بجانب الساعة
  Future<void> hideAppWindow() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      await windowManager.hide();
      debugPrint('🪟 [WindowsTrayService] Window hidden to tray.');
    } catch (e) {
      debugPrint('⚠️ [WindowsTrayService] Error hiding window: $e');
    }
  }

  /// إغلاق نهائي فعلي للتطبيق من الخلفية
  Future<void> exitApp() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      debugPrint('🛑 [WindowsTrayService] Truly closing application...');
      await windowManager.setPreventClose(false);
      try {
        await trayManager.destroy();
      } catch (e) {
        debugPrint('⚠️ [WindowsTrayService] Error destroying tray: $e');
      }
      try {
        await windowManager.destroy();
      } catch (e) {
        debugPrint('⚠️ [WindowsTrayService] Error destroying window: $e');
      }
    } catch (e) {
      debugPrint('⚠️ [WindowsTrayService] Error exiting app: $e');
    } finally {
      exit(0);
    }
  }

  // ─── TrayListener أحداث الأيقونة بجانب الساعة ───

  @override
  void onTrayIconMouseDown() {
    // النقر على الأيقونة بالماوس يُظهر النافذة ويعيدها للواجهة
    showAppWindow();
  }

  @override
  void onTrayIconMouseUp() {
    showAppWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // إظهار القائمة المنبثقة فور الضغط بالزر الأيمن
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    // إظهار القائمة المنبثقة عند رفع الزر الأيمن (احتياطي)
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window' || menuItem.label == 'فتح التطبيق') {
      showAppWindow();
    } else if (menuItem.key == 'exit_app' ||
        menuItem.label == 'إغلاق نهائي (Exit)' ||
        menuItem.label == 'خروج نهائي') {
      exitApp();
    }
  }

  // ─── WindowListener أحداث النافذة ───

  @override
  void onWindowClose() async {
    // عند الضغط على زر الإغلاق X في DesktopTitleBar أو إطار النظام
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final bool isPrevent = await windowManager.isPreventClose();
      if (isPrevent) {
        await hideAppWindow();
      }
    } catch (e) {
      debugPrint('⚠️ [WindowsTrayService] Error in onWindowClose: $e');
    }
  }
}
