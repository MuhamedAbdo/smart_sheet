import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';

import 'package:smart_sheet/widgets/theme_toggle_button.dart';
import 'package:smart_sheet/screens/backup_restore_screen.dart';
import 'package:smart_sheet/services/sync_service.dart';

class SettingsScreen extends StatelessWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = !kIsWeb && Platform.isWindows || size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 الإعدادات"),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: const [
          ThemeToggleButton(), // زر تبديل الثيم في الزاوية
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildAppearanceCard(themeProvider)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDataCard(context)),
                ],
              )
            : Column(
                children: [
                  _buildAppearanceCard(themeProvider),
                  const SizedBox(height: 16),
                  _buildDataCard(context),
                ],
              ),
      ),
    );
  }

  Widget _buildAppearanceCard(ThemeProvider themeProvider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("المظهر والتخصيص",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.color_lens),
              title: Text(
                  themeProvider.isDarkTheme ? 'الوضع النهاري' : 'الوضع الليلي'),
              subtitle: const Text("تفعيل أو تعطيل الوضع الليلي"),
              trailing: Switch(
                value: themeProvider.isDarkTheme,
                onChanged: (value) => themeProvider.toggleTheme(),
                activeTrackColor: Colors.grey[700],
                activeThumbColor: Colors.orange,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.format_size, color: Colors.green),
              title: const Text("حجم خط التطبيق"),
              subtitle: Text(
                  "المستوى الحالي: ${(themeProvider.fontScale * 100).toInt()}%"),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.text_fields, size: 16),
                  Expanded(
                    child: Slider(
                      value: themeProvider.fontScale,
                      min: 0.8,
                      max: 1.5,
                      divisions: 7,
                      label: "${(themeProvider.fontScale * 100).toInt()}%",
                      onChanged: (double value) =>
                          themeProvider.setFontScale(value),
                    ),
                  ),
                  const Icon(Icons.text_fields, size: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("البيانات والنظام",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.backup, color: Colors.blue),
              title: const Text("النسخ الاحتياطي والاستعادة"),
              subtitle: const Text("إدارة النسخ الاحتياطية المحلية والسحابية"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const BackupRestoreScreen()),
                );
              },
            ),
            const Divider(),
            // ─── زر مسح قائمة المزامنة التالفة ─────────────────
            ListTile(
              leading: const Icon(Icons.cleaning_services_rounded,
                  color: Colors.orange),
              title: const Text("مسح قائمة المزامنة (sync_queue)"),
              subtitle: const Text(
                "استخدم هذا فقط لتنظيف السجلات التالفة بعد تحديث النظام",
                style: TextStyle(color: Colors.orange),
              ),
              trailing: const Icon(Icons.delete_sweep, color: Colors.orange),
              onTap: () => _confirmClearQueue(context),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearQueue(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("تأكيد المسح"),
          ],
        ),
        content: const Text(
          "سيتم حذف جميع العمليات المعلقة في قائمة المزامنة.\n"
          "تأكد أن كل البيانات المهمة قد رُفعت بالفعل قبل المتابعة.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await SyncService.instance.clearSyncQueue();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم مسح قائمة المزامنة بنجاح'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text("مسح القائمة"),
          ),
        ],
      ),
    );
  }
}
