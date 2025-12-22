import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/store_entry_model.dart';
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
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/config/constants.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

    // 🔔 تهيئة الإشعارات المحلية
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await Supabase.initialize(
      url: supabaseUrl.trim(),
      anonKey: supabaseAnonKey.trim(),
    );

    if (!kIsWeb) {
      await Hive.initFlutter();
      Hive.registerAdapter(WorkerAdapter());
      Hive.registerAdapter(WorkerActionAdapter());
      Hive.registerAdapter(FinishedProductAdapter());
      Hive.registerAdapter(MaintenanceRecordAdapter());
      Hive.registerAdapter(StoreEntryAdapter());

      final boxes = [
        'settings',
        'measurements',
        'serial_setup_state',
        'savedSheetSizes',
        'savedSheetSizes_production',
        'inkReports',
        'storeEntries',
        'maintenance_records_main',
        'maintenance_staple_v2',
        'maintenance_flexo_v2',
        'maintenance_production_v2',
        'maintenance_crushing_v2',
        'store_flexo',
        'store_production',
        'store_staple',
        'store_crushing',
        'worker_actions',
        'workers',
        'workers_flexo',
        'workers_production',
        'workers_staple',
        'workers_crushing',
        'finished_products'
      ];

      for (var box in boxes) {
        await _openSafeBox(box);
      }
    }
  } catch (e) {
    debugPrint("Initialization Critical Error: $e");
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

Future<void> _openSafeBox<T>(String boxName) async {
  try {
    await Hive.openBox<T>(boxName);
  } catch (e) {
    debugPrint("⚠️ Box $boxName failed. Opening as dynamic.");
    await Hive.openBox(boxName);
  }
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
