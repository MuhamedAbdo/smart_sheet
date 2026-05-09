import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/providers/theme_provider.dart';

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
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint("Navigation Error: $e");
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
