// lib/src/widgets/drawers/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/auth_provider.dart';
import 'package:smart_sheet/screens/login_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isLoggedIn = authProvider.isLoggedIn;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Container(
            height: 250,
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
                const SizedBox(height: 12),
                const Text(
                  'Smart Sheet',
                  style: TextStyle(
                    color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFFBBDEFB),
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
              leading: const Icon(Icons.login),
              title: const Text('تسجيل الدخول'),
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
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
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
            leading: const Icon(Icons.backup),
            title: const Text('رفع نسخة احتياطية'),
            enabled: isLoggedIn,
            onTap: isLoggedIn
                ? () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جاري رفع النسخة...')),
                    );
                  }
                : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة نسخة احتياطية'),
            enabled: isLoggedIn,
            onTap: isLoggedIn
                ? () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جاري الاستعادة...')),
                    );
                  }
                : null,
            trailing: !isLoggedIn
                ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                : null,
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('الإعدادات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('عن التطبيق'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Smart Sheet v0.1.0\nلإدارة مصانع الكرتون'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('سياسة الخصوصية'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('عرض سياسة الخصوصية')),
              );
            },
          ),
        ],
      ),
    );
  }
}
