// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/auth_provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ✅ استيراد الشاشات

const String supabaseUrl =
    'https://edytjabmzjtidmtukvxt.supabase.co'; // ✅ إزالة المسافات
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkeXRqYWJtemp0aWRtdHVrdnh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDAyMjAsImV4cCI6MjA3MDY3NjIyMH0.xUmC4xHSP5c3kFK-jg7qZCDhrFw8rBGhZkbNdCk7kKw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Hive.initFlutter();

    // ✅ افتح كل الصناديق هنا
    await Hive.openBox('settings');
    await Hive.openBox('measurements');
    await Hive.openBox('serial_setup_state');
    await Hive.openBox('savedSheetSizes');
    await Hive.openBox('inkReports');
    await Hive.openBox('maintenanceRecords'); // ✅ فتح صندوق الصيانة
    await Hive.openBox('storeEntries'); // ✅ أضف هذا السطر
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
        '/maintenance': (context) =>
            const MaintenanceScreen(), // ✅ إضافة الصفحة للـ routes
      },
    );
  }
}
