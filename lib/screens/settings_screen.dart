import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/about_screen.dart';
import 'package:smart_sheet/screens/backup_restore_screen.dart';
import 'package:smart_sheet/screens/privacy_policy_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';
import 'package:smart_sheet/widgets/theme_toggle_button.dart';
import 'package:smart_sheet/widgets/factory_schedule_card.dart';

class SettingsScreen extends StatefulWidget {
  static const String routeName = '/settings';

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isAdmin = context.watch<AuthService>().isAdmin;
    final size = MediaQuery.of(context).size;
    final isDesktop = !kIsWeb && Platform.isWindows || size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔧 الإعدادات"),
        centerTitle: true,
        actions: const [
          ThemeToggleButton(), // زر تبديل الثيم في الزاوية
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isDesktop
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── صف أول: المظهر + البيانات + إعدادات المصنع ───────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAppearanceCard(themeProvider)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDataCard(context)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFactorySettingsCard(
                          themeProvider,
                          context,
                          isAdmin: isAdmin,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ─── صف ثانٍ: جدول الوردية (2/3) + معلومات التطبيق (1/3)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(flex: 2, child: FactoryScheduleCard()),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _buildAboutCard(context)),
                    ],
                  ),
                ],
              )
            : Column(
                children: [
                  _buildAppearanceCard(themeProvider),
                  const SizedBox(height: 16),
                  _buildDataCard(context),
                  const SizedBox(height: 16),
                  _buildFactorySettingsCard(
                    themeProvider,
                    context,
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 16),
                  const FactoryScheduleCard(),
                  const SizedBox(height: 16),
                  _buildAboutCard(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFactorySettingsCard(
    ThemeProvider themeProvider,
    BuildContext context, {
    bool isAdmin = false,
  }) {
    final shiftStart = themeProvider.shiftStart;
    final shiftEnd = themeProvider.shiftEnd;

    // حساب إجمالي ساعات الوردية
    double totalHours = shiftEnd.hour +
        shiftEnd.minute / 60.0 -
        (shiftStart.hour + shiftStart.minute / 60.0);
    if (totalHours < 0) totalHours += 24;

    // مساعد: تنسيق TimeOfDay كنص "HH:MM" لرفعه للسيرفر
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "إعدادات المصنع والوردية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // شارة دور الأدمن: مخفية عن بقية المستخدمين
                if (isAdmin)
                  const Tooltip(
                    message: 'أنت مسجّل كمسؤول (Admin)',
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ─── بداية الوردية ──────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.orange),
              title: const Text("بداية الوردية"),
              subtitle: Text(shiftStart.format(context)),
              // قلم التحرير: ظاهر للأدمن فقط
              trailing: isAdmin ? const Icon(Icons.edit, size: 18) : null,
              // تفاعل الضغط: متاح للأدمن فقط
              onTap: isAdmin
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: shiftStart,
                      );
                      if (picked == null) return;

                      // 1️⃣ تحديث محلي (Hive + notifyListeners)
                      await themeProvider.setShiftStart(picked);

                      // 2️⃣ رفع مباشر لـ Supabase → ينشّط Realtime على باقي الأجهزة
                      // ملاحظة: نستخدم update مباشراً بدلاً من pushToQueue لأن جدول
                      // factories يستخدم id كـ PK وليس sync_id,
                      // والطابور يُضيف factory_id تلقائياً مما يتعارض مع هيكل الجدول.
                      final factoryId = await SupabaseManager.getFactoryId();
                      if (factoryId != null) {
                        try {
                          final client = Supabase.instance.client;
                          final payload = {
                            'shift_start_time': fmtTime(picked),
                            'shift_end_time': fmtTime(themeProvider.shiftEnd),
                          };
                          final updatedRows = await client
                              .from('factories')
                              .update(payload)
                              .eq('factory_id', factoryId)
                              .select();
                          if (updatedRows.isEmpty) {
                            payload['factory_id'] = factoryId;
                            await client.from('factories').insert(payload);
                          }
                          debugPrint(
                              '✅ [factories] تم رفع وقت بداية الوردية: ${fmtTime(picked)}');
                        } catch (e) {
                          debugPrint(
                              '❌ [factories] فشل رفع وقت بداية الوردية: $e');
                        }
                      }

                      // 3️⃣ إجبار إعادة بناء فورية للواجهة نفسها — يضمن ظهور القيمة
                      // الجديدة فوراً دون الانتظار لدورة إطار Provider.
                      if (mounted) setState(() {});
                    }
                  : null,
            ),
            const Divider(),

            // ─── نهاية الوردية ───────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.access_time_filled,
                  color: Colors.deepOrange),
              title: const Text("نهاية الوردية"),
              subtitle: Text(shiftEnd.format(context)),
              // قلم التحرير: ظاهر للأدمن فقط
              trailing: isAdmin ? const Icon(Icons.edit, size: 18) : null,
              // تفاعل الضغط: متاح للأدمن فقط
              onTap: isAdmin
                  ? () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: shiftEnd,
                      );
                      if (picked == null) return;

                      // 1️⃣ تحديث محلي (Hive + notifyListeners)
                      await themeProvider.setShiftEnd(picked);

                      // 2️⃣ رفع مباشر لـ Supabase → ينشّط Realtime على باقي الأجهزة
                      final factoryId = await SupabaseManager.getFactoryId();
                      if (factoryId != null) {
                        try {
                          final client = Supabase.instance.client;
                          final payload = {
                            'shift_start_time':
                                fmtTime(themeProvider.shiftStart),
                            'shift_end_time': fmtTime(picked),
                          };
                          final updatedRows = await client
                              .from('factories')
                              .update(payload)
                              .eq('factory_id', factoryId)
                              .select();
                          if (updatedRows.isEmpty) {
                            payload['factory_id'] = factoryId;
                            await client.from('factories').insert(payload);
                          }
                          debugPrint(
                              '✅ [factories] تم رفع وقت نهاية الوردية: ${fmtTime(picked)}');
                        } catch (e) {
                          debugPrint(
                              '❌ [factories] فشل رفع وقت نهاية الوردية: $e');
                        }
                      }

                      // 3️⃣ إجبار إعادة بناء فورية للواجهة نفسها — يضمن ظهور القيمة
                      // الجديدة فوراً دون الانتظار لدورة إطار Provider.
                      if (mounted) setState(() {});
                    }
                  : null,
            ),
            const Divider(),

            // ─── إجمالي ساعات الوردية ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "إجمالي ساعات الوردية: ${totalHours.toStringAsFixed(1)} ساعة",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── بطاقة معلومات التطبيق والخصوصية ────────────────────────────────────
  Widget _buildAboutCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  'معلومات التطبيق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            ListTile(
              leading:
                  const Icon(Icons.apps_outlined, color: Colors.blueAccent),
              title: const Text('عن التطبيق والمطور'),
              subtitle: const Text('Smart Sheet — Version 1.0.0'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.privacy_tip_outlined, color: Colors.teal),
              title: const Text('سياسة الخصوصية'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
