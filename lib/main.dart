// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart'; // ✅ أضف هذا الاستيراد
import 'package:smart_sheet/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

// استيراد الشاشات
import 'screens/splash_screen.dart';

// ✅ أصلح الـ URL: أزل المسافات (مهم جدًا)
const String supabaseUrl = 'https://edytjabmzjtidmtukvxt.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkeXRqYWJtemp0aWRtdHVrdnh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDAyMjAsImV4cCI6MjA3MDY3NjIyMH0.xUmC4xHSP5c3kFK-jg7qZCDhrFw8rBGhZkbNdCk7kKw';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Hive فقط على الأجهزة
  if (!kIsWeb) {
    await Hive.initFlutter();
    await Hive.openBox('settings');
    await Hive.openBox('measurements');
  }

  // تهيئة Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(
    // ✅ لف التطبيق بـ Provider
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const SmartSheetApp(),
    ),
  );
}

class SmartSheetApp extends StatelessWidget {
  const SmartSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Sheet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const SplashScreen(),
    );
  }
}
