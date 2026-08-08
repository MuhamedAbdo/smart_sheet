// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'isDarkTheme';
  static const String _fontScaleKey = 'fontScale';
  static const String _shiftStartHourKey = 'shiftStartHour';
  static const String _shiftStartMinuteKey = 'shiftStartMinute';
  static const String _shiftEndHourKey = 'shiftEndHour';
  static const String _shiftEndMinuteKey = 'shiftEndMinute';
  static const String _printedFactoryNameKey = 'printedFactoryName';
  static const String _factoryLogoBase64Key = 'factoryLogoBase64';
  static const String _boxName = 'settings';

  bool _isDarkTheme = false;
  double _fontScale = 1.0;
  TimeOfDay _shiftStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _shiftEnd = const TimeOfDay(hour: 16, minute: 0);
  String _printedFactoryName = "العاشر للطباعة والنشر والتغليف\n( كازنبرس )";
  String? _factoryLogoBase64;

  bool get isDarkTheme => _isDarkTheme;
  double get fontScale => _fontScale;
  TimeOfDay get shiftStart => _shiftStart;
  TimeOfDay get shiftEnd => _shiftEnd;
  String get printedFactoryName => _printedFactoryName;
  String? get factoryLogoBase64 => _factoryLogoBase64;

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

      final startH = box.get(_shiftStartHourKey, defaultValue: 8) as int;
      final startM = box.get(_shiftStartMinuteKey, defaultValue: 0) as int;
      _shiftStart = TimeOfDay(hour: startH, minute: startM);

      final endH = box.get(_shiftEndHourKey, defaultValue: 16) as int;
      final endM = box.get(_shiftEndMinuteKey, defaultValue: 0) as int;
      _shiftEnd = TimeOfDay(hour: endH, minute: endM);

      _printedFactoryName = box.get(_printedFactoryNameKey, defaultValue: "العاشر للطباعة والنشر والتغليف\n( كازنبرس )") as String;
      _factoryLogoBase64 = box.get(_factoryLogoBase64Key) as String?;

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

  Future<void> setShiftStart(TimeOfDay time) async {
    try {
      _shiftStart = time;
      final box = await Hive.openBox(_boxName);
      await box.put(_shiftStartHourKey, time.hour);
      await box.put(_shiftStartMinuteKey, time.minute);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting shift start: $e');
    }
  }

  Future<void> setShiftEnd(TimeOfDay time) async {
    try {
      _shiftEnd = time;
      final box = await Hive.openBox(_boxName);
      await box.put(_shiftEndHourKey, time.hour);
      await box.put(_shiftEndMinuteKey, time.minute);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting shift end: $e');
    }
  }

  Future<void> setPrintedFactoryName(String name) async {
    try {
      _printedFactoryName = name;
      final box = await Hive.openBox(_boxName);
      await box.put(_printedFactoryNameKey, _printedFactoryName);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting printed factory name: $e');
    }
  }

  Future<void> setFactoryLogoBase64(String? base64Str) async {
    try {
      _factoryLogoBase64 = base64Str;
      final box = await Hive.openBox(_boxName);
      if (base64Str == null || base64Str.isEmpty) {
        await box.delete(_factoryLogoBase64Key);
      } else {
        await box.put(_factoryLogoBase64Key, base64Str);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting factory logo: $e');
    }
  }

  ThemeData get theme => _isDarkTheme ? _darkTheme : _lightTheme;

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: 'Cairo',
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: 'Cairo',
  );
}
