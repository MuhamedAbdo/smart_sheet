// lib/screens/privacy_policy_screen.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/widgets/app_drawer.dart'; // استيراد الـ Drawer

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سياسة الخصوصية',
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
          children: const [
            // اسم التطبيق
            Text(
              'Smart Sheet',
              textAlign: TextAlign.center, // ✅ يبقى في المنتصف
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            // عنوان سياسة الخصوصية
            Text(
              'سياسة خصوصية تطبيق Smart Sheet',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            // مقدمة
            Text(
              'في تطبيق "Smart Sheet"، نحن نهتم بخصوصيتك. توضح هذه الوثيقة كيفية جمعنا واستخدام وحماية المعلومات التي تزودونا بها عند استخدامكم لهذا التطبيق.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            // أقسام سياسة الخصوصية
            Text(
              '1. المعلومات التي نجمعها:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• لا نقوم بجمع أي معلومات شخصية عنك عند استخدامك للتطبيق.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '• لا يتم تتبعك أو مراقبة أنشطتك داخل التطبيق.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '2. البيانات المحلية:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• يقوم التطبيق بتخزين البيانات (مثل المقاسات، تقارير الأحبار، سجلات الصيانة...) محليًا على جهازك فقط باستخدام قاعدة بيانات Hive.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '• لا تُرسل هذه البيانات إلى أي خوادم خارجية إلا إذا اخترت استخدام ميزة النسخ الاحتياطي عبر Supabase، والتي تتطلب تسجيل الدخول.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '3. الاتصال بالإنترنت:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• لا يتطلب التطبيق الاتصال بالإنترنت للعمل في معظم ميزاته.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '• يتم استخدام الإنترنت فقط عند تسجيل الدخول أو استخدام ميزة النسخ الاحتياطي والاستعادة.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '4. مشاركة البيانات:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• لا نشارك معلوماتك مع أي طرف ثالث.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '• يتم حفظ ومشاركة البيانات فقط داخل مساحة عملك وحسابك الشخصي (في حالة استخدام النسخ الاحتياطي).',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '5. أمن البيانات:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• نحن نتخذ خطوات مناسبة لحماية معلوماتك من الفقد أو سوء الاستخدام أو التغيير غير المصرح به.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              '6. التغييرات على سياسة الخصوصية:',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• نحتفظ بالحق في تعديل سياسة الخصوصية هذه في أي وقت. سيتم نشر أي تغييرات هنا.',
              textAlign: TextAlign.right, // ✅ محاذاة من اليمين
              textDirection: TextDirection.rtl, // ✅ اتجاه النص من اليمين لليسار
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),
            // معلومات المطور (اختياري)
            Text(
              'لأي استفسارات حول سياسة الخصوصية، يرجى التواصل مع المطور : \n Muhamed Abdelaal\nالبريد الإلكتروني : \n mohamedabdo9999933@gmail.com  ',
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
