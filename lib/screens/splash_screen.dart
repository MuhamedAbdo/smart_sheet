import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    try {
      // إضافة تأخير إضافي لضمان اكتمال جميع عمليات الحذف
      await Future.delayed(const Duration(milliseconds: 500));

      // القراءة مباشرة من التخزين الآمن لتجنب الكاش
      const storage = FlutterSecureStorage();
      final factoryId = await storage.read(key: 'factory_id');

      debugPrint("🔍 Direct storage read: factoryId = $factoryId");

      if (factoryId == null || factoryId.isEmpty) {
        debugPrint("🔗 No factory_id found, redirecting to auth screen");
        Navigator.pushReplacementNamed(context, AuthScreen.routeName);
      } else {
        debugPrint("✅ Factory found: $factoryId, navigating to home");
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      debugPrint("Navigation Error: $e");
      // في حالة الخطأ، توجه إلى شاشة تسجيل الدخول كخيار آمن
      Navigator.pushReplacementNamed(context, AuthScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkTheme;
    final size = MediaQuery.of(context).size;
    final isWindows = size.width > 600; // Simple check for desktop-like width

    // اختيار الصورة حسب المنصة والوضع
    final String logoAsset;
    if (isWindows) {
      // Desktop
      logoAsset = isDarkMode
          ? 'assets/images/disktop_logo_dark.png'
          : 'assets/images/disktop_logo_light.png';
    } else {
      // Mobile
      logoAsset = isDarkMode
          ? 'assets/images/logo_dark.jpg'
          : 'assets/images/logo_light.jpg';
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full screen background image
          Image.asset(
            logoAsset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          // Version info at bottom
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Text(
              'Smart Sheet v1.2.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
