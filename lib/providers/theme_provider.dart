// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkTheme';
  static const String _fontScaleKey = 'fontScale';
  static const String _boxName = 'settings';

  bool _isDarkTheme = false;
  double _fontScale = 1.0;

  bool get isDarkTheme => _isDarkTheme;
  double get fontScale => _fontScale;

  ThemeProvider() {
    _loadSettings();
  }

  // استخدام فتح الصندوق بشكل آمن
  Future<void> _loadSettings() async {
    try {
      // نستخدم openBox لضمان عدم حدوث خطأ "Box not found"
      final box = await Hive.openBox(_boxName);

      _isDarkTheme = box.get(_themeKey, defaultValue: false);
      _fontScale =
          (box.get(_fontScaleKey, defaultValue: 1.0) as num).toDouble();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> toggleTheme() async {
    try {
      _isDarkTheme = !_isDarkTheme;
      final box = await Hive.openBox(_boxName);
      await box.put(_themeKey, _isDarkTheme);
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling theme: $e');
    }
  }

  Future<void> setFontScale(double scale) async {
    try {
      _fontScale = scale;
      final box = await Hive.openBox(_boxName);
      await box.put(_fontScaleKey, _fontScale);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting font scale: $e');
    }
  }

  ThemeData get theme => _isDarkTheme ? AppTheme.darkTheme : AppTheme.lightTheme;
}
