// lib/src/screens/about_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart'; // استيراد الـ Drawer

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'عن التطبيق',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const AppDrawer(), // ✅ إضافة الـ Drawer
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // شعار التطبيق
            Center(
              child: Image(
                image: AssetImage(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/logo_dark.jpg'
                      : 'assets/images/logo_light.jpg',
                ),
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 24),
            // اسم التطبيق
            const Text(
              'Smart Sheet',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start, // ✅ يبقى في المنتصف
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // رقم الإصدار
            const Text(
              'الإصدار: 0.1.0',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            // وصف مفصل
            const Text(
              'تطبيق "Smart Sheet" مخصص لإدارة خطوط إنتاج مصانع الكرتون المموج. يساعد التطبيق في تبسيط ورقمنة العمليات اليومية مثل حسابات المقاسات، إدارة العمال، سجلات الصيانة، تقارير الأحبار، وurd المخزن.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            // مميزات التطبيق
            const Text(
              'المميزات:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• حساب دقيق لمقاسات الشيتات.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '• إدارة شاملة لطاقم العمل.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '• تسجيل تفاصيل الصيانة.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '• تقارير الأحبار مع دعم الصور.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '• نسخ احتياطي واستعادة سحابية.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const Text(
              '• واجهة سهلة الاستخدام باللغة العربية.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            // معلومات المطور (اختياري)
            const Text(
              'المطور :\n Muhamed Abdelaal\nالبريد الإلكتروني : mohamedabdo9999933@gmail.com',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
