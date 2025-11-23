// lib/src/widgets/drawers/app_drawer.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/about_screen.dart';
import 'package:smart_sheet/screens/privacy_policy_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          Container(
            height: 180, // ← تقليل الارتفاع قليلاً
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
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
                const Text(
                  'Smart Sheet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // ✅ منع تجاوز النص باستخدام Flexible + overflow
                Flexible(
                  child: Text(
                    'الوضع المحلي',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey[300]
                          : const Color(0xFFBBDEFB),
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // القائمة
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
              Navigator.pop(context);
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
              Navigator.pop(context);
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
