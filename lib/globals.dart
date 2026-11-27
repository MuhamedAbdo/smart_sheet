// lib/globals.dart
import 'package:flutter/material.dart';

/// مفتاح عالمي لعرض SnackBar من أي مكان
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// مفتاح عالمي موحد للـ Navigator لتمكين التوجيه المباشر من الإشعارات والخدمات
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
