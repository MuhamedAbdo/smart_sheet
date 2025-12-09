// lib/src/widgets/drawers/app_drawer.dart

import 'dart:io' show exit;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/about_screen.dart';
import 'package:smart_sheet/screens/privacy_policy_screen.dart';
import 'package:smart_sheet/services/backup_service.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _showMessage(String message, {bool isError = false}) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 180,
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

          // 💾 زر النسخ الاحتياطي
          ListTile(
            leading:
                Icon(Icons.archive, color: isDarkMode ? Colors.white : null),
            title: Text('نسخة احتياطية',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            onTap: () async {
              Navigator.pop(context);
              _showMessage('جاري إنشاء النسخة الاحتياطية...', isError: false);
              final result = await BackupService().createBackup();
              if (result != null) {
                _showMessage(result, isError: result.contains('❌'));
              }
            },
          ),

          // 🔁 زر استعادة البيانات
          ListTile(
            leading:
                Icon(Icons.restore, color: isDarkMode ? Colors.white : null),
            title: Text('استعادة البيانات',
                style: TextStyle(color: isDarkMode ? Colors.white : null)),
            onTap: () async {
              Navigator.pop(context);
              _showMessage('جاري استعادة البيانات...', isError: false);
              final result = await BackupService().restoreBackup();

              if (result != null) {
                final isError = result.contains('❌');
                _showMessage(result, isError: isError);

                // ✅ إذا كانت الاستعادة ناجحة، أغلق التطبيق بعد 3 ثوانٍ
                if (!isError && result.contains('سيتم إغلاق')) {
                  // انتظر 3 ثوانٍ لإظهار الرسالة للمستخدم
                  await Future.delayed(const Duration(seconds: 3));

                  if (kIsWeb) {
                    // على الويب: لا يمكن استخدام exit، لذا نعيد التوجيه للشاشة الرئيسية
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    // على الموبايل: إغلاق التطبيق تمامًا
                    exit(0);
                  }
                }
              }
            },
          ),

          const Divider(),

          // ⚙️ الإعدادات
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

          // ℹ️ عن التطبيق
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

          // 📜 سياسة الخصوصية
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
