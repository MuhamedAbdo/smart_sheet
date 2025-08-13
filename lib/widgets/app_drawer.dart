// lib/src/widgets/drawers/app_drawer.dart

import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final VoidCallback onLoginTap;
  final VoidCallback onBackupTap;
  final VoidCallback onRestoreTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAboutTap;
  final VoidCallback onPrivacyTap;
  final bool isLoggedIn;

  const AppDrawer({
    super.key,
    required this.onLoginTap,
    required this.onBackupTap,
    required this.onRestoreTap,
    required this.onSettingsTap,
    required this.onAboutTap,
    required this.onPrivacyTap,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ✅ استبدل DrawerHeader بـ Container
          Container(
            height: 200, // زيادة الارتفاع لـ 200px
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/images/logo.png'),
                ),
                const SizedBox(height: 10), // مسافة بين الشعار والعنوان
                const Text(
                  'Smart Sheet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8), // مسافة بين العنوان والوضع
                // النص المسبب للمشكلة
                Flexible(
                  child: Text(
                    isLoggedIn ? 'مسجل دخول' : 'الوضع الضيف',
                    style: const TextStyle(
                      color: Color(0xFFBBDEFB),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // القائمة
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('تسجيل الدخول'),
            onTap: onLoginTap,
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('رفع نسخة احتياطية'),
            enabled: isLoggedIn,
            onTap: isLoggedIn ? onBackupTap : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة احتياطية'),
            enabled: isLoggedIn,
            onTap: isLoggedIn ? onRestoreTap : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('الإعدادات'),
            onTap: onSettingsTap,
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('عن التطبيق'),
            onTap: onAboutTap,
          ),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('سياسة الخصوصية'),
            onTap: onPrivacyTap,
          ),
        ],
      ),
    );
  }
}
