// lib/src/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // صورة الشعار
            Image(
              image: AssetImage('assets/images/logo.png'),
              width: 120,
              height: 120,
              // لو عاوز تضيف fit أو errorWidget
            ),
            SizedBox(height: 24),
            // اسم التطبيق
            Text(
              'Smart Sheet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 16),
            // نص التحميل
            Text(
              'جاري التحميل...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 12),
            // مؤشر التحميل
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}
