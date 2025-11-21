// lib/src/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  // دالة الانتقال للـ Home بعد تأخير
  void _navigateToHome() async {
    // تأخير 1.5 ثانية (تجربة مستخدم أفضل)
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));

    // تأكد أن الشاشة لسه موجودة قبل الانتقال
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // صورة الشعار حسب الثيم
            Image(
              image: AssetImage(
                isDarkMode
                    ? 'assets/images/logo_dark.jpg'
                    : 'assets/images/logo_light.jpg',
              ),
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            // اسم التطبيق
            Text(
              'Smart Sheet',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            // نص التحميل
            Text(
              'جاري التحميل...',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            // مؤشر التحميل
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? Colors.blue[300]! : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
