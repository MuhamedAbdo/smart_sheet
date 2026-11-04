import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/screens/home_screen.dart';
import 'package:smart_sheet/screens/gatekeeper_screen.dart';
import 'package:smart_sheet/main.dart';

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
    // 1. الانتظار المزدوج: نعطي مهلة للرسم (Splash) وفي نفس الوقت نحمّل البيانات الثقيلة
    final minDelay = Future.delayed(const Duration(milliseconds: 2500)); // مدة أطول قليلاً لتناسب الديسكتوب
    
    // تشغيل التهيئة الثقيلة في الخلفية
    final heavyInit = initializeHeavyData();

    await Future.wait([minDelay, heavyInit]);

    if (!mounted) return;

    try {
      // ✅ فحص شامل لحالة التفعيل (is_device_unlocked / has_valid_code) عبر جميع الطبقات
      // الترتيب: 1. SharedPreferences (الطبقة الأكثر ثباتاً عبر التحديثات)
      //        2. SafeSecureStorage (FlutterSecureStorage)
      //        3. pairing_vault (صندوق Hive الدائم)
      //        4. settings (Legacy Hive)
      bool isUnlocked = false;

      // 1. SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('is_device_unlocked') == true ||
            prefs.getBool('has_valid_code') == true) {
          isUnlocked = true;
        }
      } catch (e) {
        debugPrint('⚠️ SplashScreen: prefs read error: $e');
      }

      // 2. SafeSecureStorage
      if (!isUnlocked) {
        try {
          const storage = SafeSecureStorage();
          final val = await storage.read(key: 'is_device_unlocked');
          final codeVal = await storage.read(key: 'has_valid_code');
          if (val == 'true' || codeVal == 'true') {
            isUnlocked = true;
          }
        } catch (e) {
          debugPrint('⚠️ SplashScreen: SafeSecureStorage read error: $e');
        }
      }

      // 3. pairing_vault في Hive
      if (!isUnlocked && Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
        final vaultBox = Hive.box(SafeSecureStorage.pairingVaultBoxName);
        if (vaultBox.get('is_device_unlocked', defaultValue: false) == true ||
            vaultBox.get('has_valid_code', defaultValue: false) == true) {
          isUnlocked = true;
        }
      }

      // 4. settings في Hive (Legacy)
      if (!isUnlocked && Hive.isBoxOpen('settings')) {
        final legacyVal = Hive.box('settings').get('is_device_unlocked', defaultValue: false);
        final legacyCode = Hive.box('settings').get('has_valid_code', defaultValue: false);
        if (legacyVal == true || legacyCode == true) {
          isUnlocked = true;
        }
      }

      // ✅ التزامن والتعافي الذاتي (Self-Healing):
      // إذا كان الجهاز مفكوك القفل في أي طبقة، نضمن فوراً وجوده في جميع الطبقات الأخرى
      // لضمان عدم فقدانه مستقبلاً عند تحديث التطبيق أو استعادة النسخة الاحتياطية
      if (isUnlocked) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_device_unlocked', true);
          await prefs.setBool('has_valid_code', true);

          const storage = SafeSecureStorage();
          await storage.write(key: 'is_device_unlocked', value: 'true');
          await storage.write(key: 'has_valid_code', value: 'true');

          if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
            final vaultBox = Hive.box(SafeSecureStorage.pairingVaultBoxName);
            await vaultBox.put('is_device_unlocked', true);
            await vaultBox.put('has_valid_code', true);
          }
          if (Hive.isBoxOpen('settings')) {
            await Hive.box('settings').put('is_device_unlocked', true);
            await Hive.box('settings').put('has_valid_code', true);
          }
          debugPrint('🔓 SplashScreen: تم تأكيد حالة فك القفل ومزامنتها بنجاح عبر جميع الطبقات');
        } catch (syncErr) {
          debugPrint('⚠️ SplashScreen: sync error: $syncErr');
        }
      }

      // إذا كان الجهاز مفكوك القفل، يفتح التطبيق مباشرة على الشاشة الرئيسية (Home) كمتصفح عام
      final Widget targetScreen = isUnlocked ? const HomeScreen() : const GatekeeperScreen();

      // انتقال سلس (Fade Transition) للواجهة الرئيسية
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          settings: RouteSettings(name: isUnlocked ? '/home' : GatekeeperScreen.routeName),
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
      // Fallback إلى الشاشة الرئيسية مباشرة
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
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
