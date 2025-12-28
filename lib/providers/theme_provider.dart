// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkTheme';
  static const String _fontScaleKey = 'fontScale'; // مفتاح الحفظ في Hive

  bool _isDarkTheme = false;
  double _fontScale = 1.0; // القيمة الافتراضية للخط

  bool get isDarkTheme => _isDarkTheme;
  double get fontScale => _fontScale;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final box = Hive.box('settings');

      // تحميل حالة الثيم
      _isDarkTheme = box.get(_themeKey, defaultValue: false) as bool;

      // تحميل حجم الخط
      _fontScale = box.get(_fontScaleKey, defaultValue: 1.0) as double;

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  // التحكم في الثيم
  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    final box = Hive.box('settings');
    await box.put(_themeKey, _isDarkTheme);
    notifyListeners();
  }

  // التحكم في حجم الخط
  Future<void> setFontScale(double scale) async {
    _fontScale = scale;
    final box = Hive.box('settings');
    await box.put(_fontScaleKey, _fontScale);
    notifyListeners();
  }

  ThemeData get theme => _isDarkTheme ? _darkTheme : _lightTheme;

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    fontFamily: 'Cairo',
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFF212121), // Colors.grey[900]
    fontFamily: 'Cairo',
  );
}
