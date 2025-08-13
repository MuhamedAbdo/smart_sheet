// lib/main.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String supabaseUrl = 'https://edytjabmzjtidmtukvxt.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkeXRqYWJtemp0aWRtdHVrdnh0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUxMDAyMjAsImV4cCI6MjA3MDY3NjIyMH0.xUmC4xHSP5c3kFK-jg7qZCDhrFw8rBGhZkbNdCk7kKw'; // ← عدلها

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Hive
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('measurements');

  // ✅ تهيئة Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const SmartSheetApp());
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
