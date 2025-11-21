// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
// ✅ أضف هذا السطر
import 'package:smart_sheet/models/finished_product_model.dart'; // <-- ✅ خلي بالك، ده السطر الجديد
import 'package:smart_sheet/providers/auth_provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
// ✅ استيراد الشاشة المُعدّة
import 'package:smart_sheet/screens/maintenance_screen.dart'; // <-- هنا
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ✅ تم إزالة المسافات
const String supabaseUrl = 'https://edytjabmzjtidmtukvxt.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkeXRqYWJtemp0aWRtdHVrdnh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDAyMjAsImV4cCI6MjA3MDY3NjIyMH0.xUmC4xHSP5c3kFK-jg7qZCDhrFw8rBGhZkbNdCk7kKw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Hive.initFlutter();

    // ✅ 1. تسجيل الـ Adapters أولًا
    Hive.registerAdapter(WorkerAdapter());
    Hive.registerAdapter(WorkerActionAdapter());
    // ✅ أضف هذا السطر لتسجيل نموذج_finished_product_model
    Hive.registerAdapter(
        FinishedProductAdapter()); // <-- ✅ خلي بالك، ده السطر الجديد

    // ✅ 2. فتح الصناديق مرة واحدة فقط
    await Hive.openBox('settings');
    await Hive.openBox('measurements');
    await Hive.openBox('serial_setup_state');
    await Hive.openBox('savedSheetSizes');
    await Hive.openBox('savedSheetSizes_production'); // ✅ أضف ده
    await Hive.openBox('inkReports');
    await Hive.openBox('maintenanceRecords');
    await Hive.openBox('storeEntries');

    // ✅ صناديق العمال والإجراءات
    await Hive.openBox<WorkerAction>('worker_actions');
    await Hive.openBox<Worker>('workers');
    // ✅ أضف هذا السطر لفتح صندوق 'workers_flexo'
    await Hive.openBox<Worker>(
        'workers_flexo'); // <-- ✅ خلي بالك، ده السطر الجديد
    // ✅ أضف هذا السطر لفتح صندوق 'workers_production'
    await Hive.openBox<Worker>(
        'workers_production'); // <-- ✅ خلي بالك، ده السطر الجديد
    // ✅ أضف هذا السطر لفتح صندوق 'workers_staple'
    await Hive.openBox<Worker>(
        'workers_staple'); // <-- ✅ خلي بالك، ده السطر الجديد

    // ✅ أضف هذا السطر لفتح صندوق_finished_product_model
    await Hive.openBox<FinishedProduct>(
        'finished_products'); // <-- ✅ خلي بالك، ده السطر الجديد
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const SmartSheetApp(),
    ),
  );
}

class SmartSheetApp extends StatelessWidget {
  const SmartSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Smart Sheet',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      home: const SplashScreen(),
      routes: {
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        CameraQualitySettingsScreen.routeName: (context) =>
            const CameraQualitySettingsScreen(),
        // ✅ تعديل مسار '/maintenance' لتمرير الاسم والعنوان الافتراضي (مثلاً، إنتاج)
        '/maintenance': (context) => const MaintenanceScreen(
              boxName: 'maintenanceRecords', // ✅ الاسم الافتراضي
              title: 'سجلات الصيانة', // ✅ العنوان الافتراضي
            ),
        '/store_entry': (context) => const StoreEntryScreen(),
        // ✅ تحديث مسار '/workers' لتمرير الاسم بشكل عام
        '/workers': (context) => const WorkersScreen(
              departmentBoxName: 'workers', // القيمة الافتراضية
              departmentTitle: 'طاقم العمل', // القيمة الافتراضية
            ),
        // ✅ يمكنك إضافة مسار لطاقم الدبوس إذا أردت (اختياري)
        // '/workers_staple': (context) => const WorkersScreen(
        //       departmentBoxName: 'workers_staple',
        //       departmentTitle: 'طاقم الدبوس',
        //     ),
      },
    );
  }
}
