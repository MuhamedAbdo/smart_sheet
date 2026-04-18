import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/flexo_archive_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/services/backup_service.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/globals.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  static const MethodChannel _platformChannel =
      MethodChannel('com.smart_sheet/app_control');

  void _showMsg(
    String msg, {
    bool isError = false,
  }) {
    UIUtils.showInfoSnackBar(
      message: msg,
      backgroundColor: isError ? Colors.red : Colors.green,
      icon: isError ? Icons.error_outline : Icons.check_circle_outline,
    );
  }

  void _showProgress(String message) {
    UIUtils.showProgressSnackBar(message: message);
  }

  void _hideSnack() {
    scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
  }

  /// 🔄 رسالة نجاح ثم إعادة تشغيل التطبيق
  Future<void> _restartApp() async {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    UIUtils.showRestartSnackBar(
      message: 'تم استعادة البيانات بنجاح',
      subMessage: 'سيتم إعادة تشغيل التطبيق لتطبيق التغييرات',
    );

    await Future.delayed(const Duration(seconds: 3));

    try {
      await _platformChannel.invokeMethod('restartApp');
    } catch (e) {
      debugPrint('Error restarting app: $e');
      _showMsg('❌ فشل إعادة تشغيل التطبيق', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // مراقبة الثيم الحالي لتحديد الصورة المناسبة
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkTheme;
    
    final auth = context.watch<AuthService>().state;
    final backupService = BackupService();

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.blue,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              // التبديل التلقائي باستخدام الأسماء الجديدة التي طلبتها
              backgroundImage: AssetImage(
                isDarkMode
                    ? 'assets/images/appdrawer_dark.jpg'
                    : 'assets/images/appdrawer_light.jpg',
              ),
            ),
            accountName: const Text(
              'Smart Sheet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(auth.user?.email ?? 'الوضع المحلي'),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const ListTile(
                  title: Text(
                    'النسخ المحلي (ذاكرة الهاتف)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.save_alt, color: Colors.green),
                  title: const Text('إنشاء نسخة احتياطية محلية'),
                  subtitle: const Text('حفظ ملف Zip على الهاتف'),
                  onTap: () async {
                    Navigator.pop(context);
                    _showProgress('جاري إنشاء النسخة...');
                    try {
                      final result = await backupService.createBackup();
                      _hideSnack();
                      if (result != null) {
                        _showMsg(result);
                      }
                    } catch (e) {
                      _hideSnack();
                      _showMsg('❌ فشل النسخ: $e', isError: true);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.orange),
                  title: const Text('استعادة نسخة محلية'),
                  subtitle: const Text('اختيار ملف Zip من الهاتف'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      final result = await backupService.restoreBackup();
                      _hideSnack();

                      if (result != null &&
                          result.contains('SUCCESS_RESTORE')) {
                        await _restartApp();
                      } else if (result != null && result.isNotEmpty) {
                        _showMsg(result, isError: true);
                      } else {
                        _showMsg(
                          'تم إلغاء الاستعادة أو لم يتم اختيار ملف',
                          isError: true,
                        );
                      }
                    } catch (e) {
                      _hideSnack();
                      _showMsg('❌ فشل الاستعادة: $e', isError: true);
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading:
                      const Icon(Icons.inventory_2_outlined, color: Colors.blueGrey),
                  title: const Text('أرشيف الفلكسو (تقارير سابقة)'),
                  subtitle: const Text('عرض التقارير والملفات المؤرشفة'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FlexoArchiveScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('الإعدادات والنسخ السحابي'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, SettingsScreen.routeName);
                  },
                ),
                const Divider(),
                if (!auth.isAuthenticated)
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined,
                        color: Colors.blue),
                    title: const Text('تسجيل الدخول / إنشاء حساب'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AuthScreen.routeName);
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('تسجيل الخروج'),
                    onTap: () async {
                      Navigator.pop(context);
                      await context.read<AuthService>().signOut();
                    },
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}