import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/widgets/auth_gate.dart';
import 'package:smart_sheet/screens/gatekeeper_screen.dart';

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
      // ✅ إصلاح: قراءة is_device_unlocked من pairing_vault الدائم بدلاً من settings
      // pairing_vault لا يُمسح بـ forceLogout() أو تسجيل الخروج العادي
      bool isUnlocked = false;
      if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
        isUnlocked = Hive.box(SafeSecureStorage.pairingVaultBoxName)
            .get('is_device_unlocked', defaultValue: false) == true;
      }

      // التوافق مع النسخ القديمة: إذا لم تُوجد في vault، ابحث في settings (Legacy)
      if (!isUnlocked && Hive.isBoxOpen('settings')) {
        final legacyVal = Hive.box('settings').get('is_device_unlocked', defaultValue: false);
        if (legacyVal == true) {
          isUnlocked = true;
          // ترحيل القيمة لـ pairing_vault لضمان استمراريتها
          if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
            await Hive.box(SafeSecureStorage.pairingVaultBoxName)
                .put('is_device_unlocked', true);
            debugPrint('🔄 SplashScreen: is_device_unlocked مُرحَّل من settings إلى pairing_vault');
          }
        }
      }

      final Widget targetScreen = isUnlocked ? const AuthGate() : const GatekeeperScreen();

      // انتقال سلس (Fade Transition) للواجهة الرئيسية
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: isUnlocked ? '/auth_gate' : GatekeeperScreen.routeName),
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
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
      // Fallback
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
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
