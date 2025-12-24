import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/store_entry_model.dart';
import 'package:smart_sheet/models/ink_report.dart';

import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/screens/backup_restore_screen.dart';
import 'package:smart_sheet/config/constants.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();

    // تهيئة الإشعارات و Supabase
    await Future.wait([
      _initializeNotifications(),
      Supabase.initialize(
          url: supabaseUrl.trim(), anonKey: supabaseAnonKey.trim()),
    ]);

    if (!kIsWeb) {
      await Hive.initFlutter();
      _registerAdapters();

      // هـام جداً: يجب فتح صندوق worker_actions أولاً لأنه مرتبط بـ Worker عبر HiveList
      // إذا تم فتح صناديق العمال قبل هذا الصندوق سيحدث الخطأ الذي ظهر لك
      await Hive.openBox<WorkerAction>('worker_actions');

      // الآن نفتح الصناديق الحرجة الأخرى
      await Future.wait([
        Hive.openBox('settings'),
        Hive.openBox<Worker>('workers'),
        Hive.openBox<Worker>('workers_flexo'),
        Hive.openBox<Worker>('workers_production'),
        Hive.openBox<FinishedProduct>('finished_products'),
      ]);

      // فتح الباقي في الخلفية (صناديق لا تحتوي على علاقات HiveList)
      _openBackgroundBoxes();
    }
  } catch (e) {
    debugPrint("❌ Critical Initialization Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const SmartSheetApp(),
    ),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(11))
    Hive.registerAdapter(WorkerActionAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkerAdapter());
  if (!Hive.isAdapterRegistered(5))
    Hive.registerAdapter(FinishedProductAdapter());
  if (!Hive.isAdapterRegistered(6))
    Hive.registerAdapter(MaintenanceRecordAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(StoreEntryAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(InkReportAdapter());
}

void _openBackgroundBoxes() {
  Hive.openBox<StoreEntry>('store_flexo');
  Hive.openBox<MaintenanceRecord>('maintenance_records_main');

  final otherBoxes = [
    'savedSheetSizes',
    'inkReports',
    'measurements',
    'serial_setup_state'
  ];
  for (var box in otherBoxes) {
    Hive.openBox(box)
        .catchError((e) => debugPrint("⚠️ Failed to open $box: $e"));
  }
}

Future<void> _initializeNotifications() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin
      .initialize(const InitializationSettings(android: androidSettings));
}

class SmartSheetApp extends StatelessWidget {
  const SmartSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Smart Sheet',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      home: const SplashScreen(),
      routes: {
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        CameraQualitySettingsScreen.routeName: (_) =>
            const CameraQualitySettingsScreen(),
        AuthScreen.routeName: (_) => const AuthScreen(),
        BackupRestoreScreen.routeName: (_) => const BackupRestoreScreen(),
        '/maintenance': (_) => const MaintenanceScreen(
            boxName: 'maintenance_records_main', title: 'سجلات الصيانة'),
        '/store_entry': (_) => const StoreEntryScreen(
            boxName: 'store_flexo', title: 'وارد المخزن'),
        '/workers': (_) => const WorkersScreen(
            departmentBoxName: 'workers', departmentTitle: 'طاقم العمل'),
      },
    );
  }
}
