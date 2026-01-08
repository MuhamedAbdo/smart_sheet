// lib/src/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/widgets/theme_toggle_button.dart';
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
          // 🌓 قسم تبديل الثيم
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text(
              themeProvider.isDarkTheme ? 'الوضع النهاري' : 'الوضع الليلي',
            ),
            subtitle: const Text("تفعيل أو تعطيل الوضع الليلي"),
            trailing: Switch(
              value: themeProvider.isDarkTheme,
              onChanged: (value) => themeProvider.toggleTheme(),
              activeTrackColor: Colors.grey[700],
              activeThumbColor: Colors.orange,
            ),
          ),
          const Divider(),

          // 💾 قسم النسخ الاحتياطي والاستعادة
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.blue),
            title: const Text("النسخ الاحتياطي والاستعادة"),
            subtitle: const Text("إدارة النسخ الاحتياطية المحلية والسحابية"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupRestoreScreen(),
                ),
              );
            },
          ),
          const Divider(),

          // 🅰️ قسم التحكم في حجم الخط (الإضافة الجديدة)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size, color: Colors.green),
                  title: const Text("حجم خط التطبيق"),
                  subtitle: Text(
                    "المستوى الحالي: ${(themeProvider.fontScale * 100).toInt()}%",
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: themeProvider.fontScale,
                          min: 0.8, // أصغر حجم (80%)
                          max: 1.5, // أكبر حجم (150%)
                          divisions: 7, // قفزات بمقدار 0.1
                          label: "${(themeProvider.fontScale * 100).toInt()}%",
                          onChanged: (double value) {
                            themeProvider.setFontScale(value);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 28),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "معاينة: سيظهر النص بهذا الحجم في جميع شاشات التطبيق.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // 📸 قسم جودة الكاميرا
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.purple),
            title: const Text("جودة الكاميرا"),
            subtitle: const Text("اختر مستوى الجودة المناسب للصور"),
            onTap: () {
              Navigator.pushNamed(
                  context, CameraQualitySettingsScreen.routeName);
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
