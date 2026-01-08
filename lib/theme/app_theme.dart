import 'package:flutter/material.dart';

class AppTheme {
  // 🎨 الألوان الأساسية
  static const Color primaryColor = Color(0xFF2C3E50); // أزرق داكن احترافي
  static const Color secondaryColor = Color(0xFF3498DB); // أزرق زاهي
  static const Color accentColor = Color(0xFFE74C3C); // أحمر أنيق
  static const Color successColor = Color(0xFF27AE60); // أخضر ناجح
  static const Color warningColor = Color(0xFFF39C12); // برتقالي تحذير
  static const Color errorColor = Color(0xFFE74C3C); // أحمر خطأ

  // 🌈 ألوان الوضع الفاتح
  static const Color lightBackground = Color(0xFFF5F7FA); // رمادي ثلجي ناعم
  static const Color lightSurface = Color(0xFFFAFBFC); // أبيض ناعم جداً
  static const Color lightOnSurface = Color(0xFF2C3E50);
  static const Color lightOnBackground = Color(0xFF2C3E50);

  // 🎨 ألوان جديدة للوضع الفاتح المحسّن
  static const Color vibrantBlue = Color(0xFF2980B9); // أزرق أكثر حيوية
  static const Color softBorder = Color(0xFFE8F4FD); // حدود زرقاء باهتة جداً

  // 🌙 ألوان الوضع الداكن
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkOnSurface = Color(0xFFEAEAEA);
  static const Color darkOnBackground = Color(0xFFEAEAEA);

  // 📱 إعدادات الخطوط
  static const String fontFamily = 'Cairo';

  // 🎯 الظلال والإطارات
  static const double borderRadius = 16.0; // أكثر استدارة
  static const double cardElevation = 8.0; // ظل أعمق
  static const double buttonElevation = 4.0; // ظل أعمق للأزرار

  // ✨ ثيم الوضع الفاتح
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,

      // 🎨 لوحة الألوان
      colorScheme: const ColorScheme.light(
        primary: vibrantBlue,
        onPrimary: lightOnSurface,
        secondary: vibrantBlue,
        surface: lightSurface,
        background: lightBackground,
        onSurface: lightOnSurface,
        onBackground: lightOnBackground,
        error: errorColor,
      ),

      // 📱 AppBar ثيم
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        iconTheme: IconThemeData(
          color: lightOnSurface,
          size: 24,
        ),
      ),

      // 🃏 Card ثيم
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: softBorder, width: 0.5), // حدود زرقاء باهتة
        ),
        shadowColor: Colors.black.withOpacity(0.15), // ظل أعمق وأكثر نعومة
      ),

      // 🔘 Button ثيم
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: vibrantBlue,
          foregroundColor: Colors.white,
          elevation: buttonElevation,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(color: softBorder, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // 📝 Text Field ثيم
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: vibrantBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: lightOnSurface,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.grey.shade600,
        ),
      ),

      // 🎯 Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: vibrantBlue,
        foregroundColor: Colors.white,
        elevation: 8,
      ),

      // 📊 Drawer ثيم
      drawerTheme: DrawerThemeData(
        backgroundColor: lightSurface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            bottomLeft: Radius.circular(borderRadius),
          ),
        ),
      ),

      // 🎨 BottomNavigationBar ثيم
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: vibrantBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
    );
  }

  // 🌙 ثيم الوضع الداكن
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,

      // 🎨 لوحة الألوان
      colorScheme: const ColorScheme.dark(
        primary: secondaryColor,
        onPrimary: darkOnSurface,
        secondary: accentColor,
        surface: darkSurface,
        background: darkBackground,
        onSurface: darkOnSurface,
        onBackground: darkOnBackground,
        error: errorColor,
      ),

      // 📱 AppBar ثيم
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: fontFamily,
        ),
        iconTheme: const IconThemeData(
          color: darkOnSurface,
          size: 24,
        ),
      ),

      // 🃏 Card ثيم
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        shadowColor: Colors.black26,
      ),

      // 🔘 Button ثيم
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
          elevation: buttonElevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),

      // 📝 Text Field ثيم
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: secondaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: darkOnSurface,
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.grey.shade400,
        ),
      ),

      // 🎯 Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
      ),

      // 📊 Drawer ثيم
      drawerTheme: DrawerThemeData(
        backgroundColor: darkSurface,
        elevation: 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(borderRadius),
            bottomLeft: Radius.circular(borderRadius),
          ),
        ),
      ),

      // 🎨 BottomNavigationBar ثيم
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: secondaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // 🎨 أدوات مساعدة للألوان
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'ناجح':
      case 'مكتمل':
        return successColor;
      case 'warning':
      case 'تحذير':
      case 'قيد التنفيذ':
        return warningColor;
      case 'error':
      case 'خطأ':
      case 'فشل':
        return errorColor;
      default:
        return primaryColor;
    }
  }

  // 📏 مسافات متسقة
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // 🎯 أحجام الخطوط
  static const double fontSizeXS = 12.0;
  static const double fontSizeS = 14.0;
  static const double fontSizeM = 16.0;
  static const double fontSizeL = 18.0;
  static const double fontSizeXL = 20.0;
  static const double fontSizeXXL = 24.0;
  static const double fontSizeXXXL = 32.0;
}
