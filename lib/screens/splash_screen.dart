import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'home_screen.dart';

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

  void _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2500)); // مدة أطول قليلاً لتناسب الديسكتوب

    if (!mounted) return;

    try {
      // انتقال سلس (Fade Transition) للواجهة الرئيسية
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 1000),
        ),
      );
    } catch (e) {
      debugPrint("Navigation Error: $e");
      // Fallback في حالة فشل الـ PageRouteBuilder المخصص
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = kIsWeb || (!kIsWeb && Platform.isWindows);

    if (isDesktop) {
      final String desktopLogoPath = isDarkMode 
          ? 'assets/images/disktop_logo_dark.png' 
          : 'assets/images/disktop_logo_light.png';

      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Image.asset(
            desktopLogoPath,
            fit: BoxFit.cover, // يضمن ملء الشاشة العريضة دون تشويه
          ),
        ),
      );
    }

    // الموبايل: عرض الـ Splash Screen الأصلية
    final String logoPath = isDarkMode ? 'assets/images/logo_dark.jpg' : 'assets/images/logo_light.jpg';

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            logoPath,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.38, // تم الرفع مرة أخرى بناءً على طلب المستخدم
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.blue[300]! : Colors.blue[700]!,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
