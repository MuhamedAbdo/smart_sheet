// lib/src/widgets/drawers/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/auth_provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/backup_restore_screen.dart';
import 'package:smart_sheet/screens/login_screen.dart';
import 'package:smart_sheet/screens/screens/about_screen.dart';
import 'package:smart_sheet/screens/screens/privacy_policy_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;
    final isLoggedIn = authProvider.isLoggedIn;
    final isDarkMode = themeProvider.isDarkTheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Container(
            height: 250,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(
                    isDarkMode
                        ? 'assets/images/logo_dark.jpg'
                        : 'assets/images/logo_light.jpg',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Smart Sheet',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(start: 2),
                    child: Text(
                      isLoggedIn ? user?.email ?? 'مستخدم' : 'الوضع الضيف',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[300]
                            : const Color(0xFFBBDEFB),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // زر تسجيل دخول أو خروج
          if (!isLoggedIn)
            ListTile(
              leading:
                  Icon(Icons.login, color: isDarkMode ? Colors.white : null),
              title: Text('تسجيل الدخول',
                  style: TextStyle(color: isDarkMode ? Colors.white : null)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            )
          else
            ListTile(
              leading:
                  Icon(Icons.logout, color: isDarkMode ? Colors.white : null),
              title: Text('تسجيل الخروج',
                  style: TextStyle(color: isDarkMode ? Colors.white : null)),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                await authProvider.signOut();
                messenger.showSnackBar(
                  const SnackBar(content: Text('تم تسجيل الخروج')),
                );
              },
            ),

          // القائمة
          ListTile(
            leading:
                Icon(Icons.backup, color: isDarkMode ? Colors.white : null),
            title: Text('النسخ الاحتياطي',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            enabled: isLoggedIn,
            onTap: isLoggedIn
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BackupRestoreScreen()),
                    );
                  }
                : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading:
                Icon(Icons.restore, color: isDarkMode ? Colors.white : null),
            title: Text('استعادة نسخة احتياطية',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            enabled: isLoggedIn,
            onTap: isLoggedIn
                ? () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BackupRestoreScreen()),
                    );
                  }
                : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading:
                Icon(Icons.settings, color: isDarkMode ? Colors.white : null),
            title: Text('الإعدادات',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.info, color: isDarkMode ? Colors.white : null),
            title: Text('عن التطبيق',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            onTap: () {
              Navigator.pop(context); // ✅ إغلاق الـ Drawer
              // ✅ الانتقال إلى شاشة "عن التطبيق"
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          ListTile(
            leading:
                Icon(Icons.policy, color: isDarkMode ? Colors.white : null),
            title: Text('سياسة الخصوصية',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            onTap: () {
              Navigator.pop(context); // ✅ إغلاق الـ Drawer
              // ✅ الانتقال إلى شاشة "سياسة الخصوصية"
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
