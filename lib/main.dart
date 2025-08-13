// lib/main.dart

import 'package:flutter/material.dart';
import 'package:smart_sheet/screens/splash_screen.dart';

void main() {
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
        fontFamily: 'Cairo', // هنضيف الخط لاحقًا
      ),
      home: const SplashScreen(),
    );
  }
}
