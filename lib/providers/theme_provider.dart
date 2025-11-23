// lib/src/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkTheme';

  late bool _isDarkTheme;

  bool get isDarkTheme => _isDarkTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    // ✅ فتح الصندوق داخليًا
    final box = await Hive.openBox('settings');
    _isDarkTheme = box.get(_themeKey, defaultValue: false);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    await _saveTheme();
    notifyListeners();
  }

  Future<void> _saveTheme() async {
    final box = await Hive.openBox('settings');
    await box.put(_themeKey, _isDarkTheme);
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
