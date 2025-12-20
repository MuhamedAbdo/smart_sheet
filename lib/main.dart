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
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_sheet/config/constants.dart';

/// حل مشكلة SSL و DNS في بعض الشبكات للهواتف الحقيقية
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تفعيل تجاوزات الـ HTTP للـ APK
  HttpOverrides.global = MyHttpOverrides();

  // تهيئة Supabase
  await Supabase.initialize(
    url: supabaseUrl.trim(),
    anonKey: supabaseAnonKey.trim(),
  );

  // تهيئة Hive
  if (!kIsWeb) {
    await Hive.initFlutter();

    // تسجيل الـ Adapters
    Hive.registerAdapter(WorkerAdapter());
    Hive.registerAdapter(WorkerActionAdapter());
    Hive.registerAdapter(FinishedProductAdapter());
    Hive.registerAdapter(MaintenanceRecordAdapter());
    Hive.registerAdapter(StoreEntryAdapter());

    // فتح الصناديق الأساسية والمخصصة لكل قسم
    // ملاحظة: يجب تحديد النوع <Type> لكل صندوق ليتوافق مع استدعاءاته في التطبيق
    await Future.wait([
      Hive.openBox('settings'),
      Hive.openBox('measurements'),
      Hive.openBox('serial_setup_state'),
      Hive.openBox('savedSheetSizes'),
      Hive.openBox('savedSheetSizes_production'),
      Hive.openBox('inkReports'),
      Hive.openBox('storeEntries'),

      // ✅ صناديق وارد المخزن لكل قسم (تم تحديد النوع StoreEntry)
      Hive.openBox<StoreEntry>('store_flexo'),
      Hive.openBox<StoreEntry>('store_production'),
      Hive.openBox<StoreEntry>('store_staple'),
      Hive.openBox<StoreEntry>('store_crushing'),

      // ✅ صناديق الصيانة (تم تحديد النوع MaintenanceRecord)
      Hive.openBox<MaintenanceRecord>('maintenance_records_main'),
      Hive.openBox<MaintenanceRecord>('maintenance_staple_v2'),
      Hive.openBox<MaintenanceRecord>('maintenance_flexo_v2'),
      Hive.openBox<MaintenanceRecord>('maintenance_production_v2'),
      Hive.openBox<MaintenanceRecord>('maintenance_crushing_v2'),

      // ✅ صناديق العمال لكل قسم (تم تحديد النوع Worker)
      Hive.openBox<Worker>('workers'),
      Hive.openBox<Worker>('workers_flexo'),
      Hive.openBox<Worker>('workers_production'),
      Hive.openBox<Worker>('workers_staple'),
      Hive.openBox<Worker>('workers_crushing'),

      Hive.openBox<WorkerAction>('worker_actions'),
      Hive.openBox<FinishedProduct>('finished_products'),
    ]);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AuthService()),
      ],
      child: const SmartSheetApp(),
    ),
  );
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
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        CameraQualitySettingsScreen.routeName: (context) =>
            const CameraQualitySettingsScreen(),
        AuthScreen.routeName: (context) => const AuthScreen(),

        // مسارات افتراضية
        '/maintenance': (context) => const MaintenanceScreen(
            boxName: 'maintenance_records_main', title: 'سجلات الصيانة'),
        '/store_entry': (context) => const StoreEntryScreen(
            boxName: 'store_flexo', title: 'وارد المخزن'),
        '/workers': (context) => const WorkersScreen(
            departmentBoxName: 'workers', departmentTitle: 'طاقم العمل'),
      },
    );
  }
}
