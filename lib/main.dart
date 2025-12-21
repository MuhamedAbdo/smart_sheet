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
import 'package:smart_sheet/services/auth_service.dart'; // ✅ تأكد من وجود هذا المسار
import 'package:smart_sheet/screens/auth_screen.dart';
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
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // تفعيل تجاوزات الـ HTTP
    HttpOverrides.global = MyHttpOverrides();

    // تهيئة Supabase (تأكد من وجود القيم في constants.dart)
    await Supabase.initialize(
      url: supabaseUrl.trim(),
      anonKey: supabaseAnonKey.trim(),
    );

    if (!kIsWeb) {
      await Hive.initFlutter();

      // تسجيل الـ Adapters
      Hive.registerAdapter(WorkerAdapter());
      Hive.registerAdapter(WorkerActionAdapter());
      Hive.registerAdapter(FinishedProductAdapter());
      Hive.registerAdapter(MaintenanceRecordAdapter());
      Hive.registerAdapter(StoreEntryAdapter());

      // ✅ فتح الصناديق الأساسية باستخدام دالة الحماية
      await _openSafeBox('settings');
      await _openSafeBox('measurements');
      await _openSafeBox('serial_setup_state');
      await _openSafeBox('savedSheetSizes');
      await _openSafeBox('savedSheetSizes_production');
      await _openSafeBox('inkReports');
      await _openSafeBox('storeEntries');

      // صناديق الصيانة
      await _openSafeBox<MaintenanceRecord>('maintenance_records_main');
      await _openSafeBox<MaintenanceRecord>('maintenance_staple_v2');
      await _openSafeBox<MaintenanceRecord>('maintenance_flexo_v2');
      await _openSafeBox<MaintenanceRecord>('maintenance_production_v2');
      await _openSafeBox<MaintenanceRecord>('maintenance_crushing_v2');

      // صناديق المخازن
      await _openSafeBox<StoreEntry>('store_flexo');
      await _openSafeBox<StoreEntry>('store_production');
      await _openSafeBox<StoreEntry>('store_staple');
      await _openSafeBox<StoreEntry>('store_crushing');

      // صناديق العمال
      await _openSafeBox<WorkerAction>('worker_actions');
      await _openSafeBox<Worker>('workers');
      await _openSafeBox<Worker>('workers_flexo');
      await _openSafeBox<Worker>('workers_production');
      await _openSafeBox<Worker>('workers_staple');
      await _openSafeBox<Worker>('workers_crushing');

      // المنتجات
      await _openSafeBox<FinishedProduct>('finished_products');
    }
  } catch (e) {
    debugPrint("Initialization Critical Error: $e");
  }

  runApp(
    // ✅ تم تغيير هذا الجزء ليشمل AuthService المطلوب للـ AppDrawer
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AuthService()),
      ],
      child: const SmartSheetApp(),
    ),
  );
}

// ✅ دالة حماية: تمنع الشاشة السوداء عند تعارض أنواع البيانات في النسخة الاحتياطية
Future<void> _openSafeBox<T>(String boxName) async {
  try {
    await Hive.openBox<T>(boxName);
  } catch (e) {
    debugPrint("⚠️ Warning: Box $boxName failed to open. Error: $e");
    await Hive.openBox(boxName); // فتحه كـ dynamic كحل أخير
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
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        CameraQualitySettingsScreen.routeName: (context) =>
            const CameraQualitySettingsScreen(),
        AuthScreen.routeName: (context) => const AuthScreen(),

        // المسارات الافتراضية
        '/maintenance': (context) => const MaintenanceScreen(
              boxName: 'maintenance_records_main',
              title: 'سجلات الصيانة',
            ),
        '/store_entry': (context) => const StoreEntryScreen(
              boxName: 'store_flexo',
              title: 'وارد المخزن',
            ),
        '/workers': (context) => const WorkersScreen(
              departmentBoxName: 'workers',
              departmentTitle: 'طاقم العمل',
            ),
      },
    );
  }
}
