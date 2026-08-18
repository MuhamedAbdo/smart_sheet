import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/about_screen.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/privacy_policy_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/super_admin_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// عرض نافذة تأكيد تسجيل الخروج قبل تنفيذ signOut
  Future<void> _confirmSignOut(BuildContext context) async {
    // إغلاق الـ Drawer أولاً
    Navigator.pop(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'تأكيد',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          textDirection: TextDirection.rtl,
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // إغلاق نافذة التأكيد
              Navigator.of(ctx).pop();
              
              // تنفيذ الخروج
              await context.read<AuthService>().signOut();
              
              // التوجيه الإجباري لشاشة الدخول ومسح السجل
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkTheme;
    final auth = context.watch<AuthService>().state;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[900] : Colors.blue,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
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
                // ─── الإعدادات ─────────────────────────────────────────
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('الإعدادات والنسخ السحابي'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, SettingsScreen.routeName);
                  },
                ),
                if (auth.user?.email == 'mohamedabdo9999933@gmail.com')
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings, color: Colors.red[800]),
                    title: Text(
                      'لوحة تحكم النظام (Super Admin)',
                      style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperAdminScreen()));
                    },
                  ),

                // ─── معلومات وقانوني ───────────────────────────────────
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: Colors.blueAccent),
                  title: const Text('عن التطبيق والمطور'),
                  onTap: () =>
                      _navigate(context, const AboutScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: Colors.teal),
                  title: const Text('سياسة الخصوصية'),
                  onTap: () =>
                      _navigate(context, const PrivacyPolicyScreen()),
                ),

                // ─── تسجيل الدخول / الخروج ─────────────────────────────
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
                    onTap: () => _confirmSignOut(context),
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