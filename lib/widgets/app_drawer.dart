import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

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