// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkTheme';

  // ✅ تغيير: لا نستخدم 'late' لأن القيمة قد تُستخدم قبل اكتمال async
  bool _isDarkTheme = false;

  bool get isDarkTheme => _isDarkTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      // ✅ ملاحظة: 'settings' مفتوح مسبقًا في main.dart، لذا لا نحتاج openBox
      final box = Hive.box('settings');
      final savedTheme = box.get(_themeKey, defaultValue: false) as bool;
      if (_isDarkTheme != savedTheme) {
        _isDarkTheme = savedTheme;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
      // نبقي القيمة الافتراضية false في حالة الفشل
    }
  }

  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    await _saveTheme();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    try {
      final box = Hive.box('settings');
      await box.put(_themeKey, _isDarkTheme);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
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
    scaffoldBackgroundColor: Colors.grey[900],
    fontFamily: 'Cairo',
  );
}
