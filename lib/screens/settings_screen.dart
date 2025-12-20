// lib/src/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/widgets/theme_toggle_button.dart';
// 🆕 الاستيراد الجديد: افترض أن المسار هو هذا بناءً على بنية ملفك
import 'package:smart_sheet/screens/backup_restore_screen.dart';

class SettingsScreen extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 الإعدادات"),
        centerTitle: true,
        actions: const [
          ThemeToggleButton(), // زر تبديل الثيم في الزاوية
        ],
      ),
      body: ListView(
        children: [
          // 🌓 تبديل الثيم
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(
              themeProvider.isDarkTheme ? 'الوضع النهاري' : 'الوضع الليلي',
              style: TextStyle(
                color: themeProvider.isDarkTheme ? Colors.white : Colors.black,
              ),
            ),
            subtitle: const Text("تفعيل أو تعطيل الوضع الليلي"),
            trailing: Switch(
              value: themeProvider.isDarkTheme,
              onChanged: (value) => themeProvider.toggleTheme(),
              activeTrackColor: Colors.grey[700],
              activeThumbColor: Colors.orange,
            ),
            onTap: () {},
          ),
          const Divider(),

          // 💾 النسخ الاحتياطي والاستعادة (الخيار الجديد)
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text("النسخ الاحتياطي والاستعادة"),
            subtitle: const Text("إدارة النسخ الاحتياطية المحلية والسحابية"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // ➡️ الانتقال المباشر (MaterialPageRoute)
              Navigator.of(context).push(
                // <--- استخدم MaterialPageRoute
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // 📸 جودة الكاميرا
          ListTile(
            leading: const Icon(Icons.camera),
            title: const Text("جودة الكاميرا"),
            subtitle: const Text("اختر مستوى الجودة المناسب للصور"),
            onTap: () {
              Navigator.pushNamed(
                  context, CameraQualitySettingsScreen.routeName);
            },
          ),

          const Divider(),

          // يمكن إضافة المزيد من الخيارات لاحقًا
        ],
      ),
    );
  }
}
