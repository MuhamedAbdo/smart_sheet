// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/store_entry_model.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/camera_quality_settings_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await Hive.initFlutter();

    Hive.registerAdapter(WorkerAdapter());
    Hive.registerAdapter(WorkerActionAdapter());
    Hive.registerAdapter(FinishedProductAdapter());
    Hive.registerAdapter(MaintenanceRecordAdapter());
    Hive.registerAdapter(StoreEntryAdapter());

    await Hive.openBox('settings');
    await Hive.openBox('measurements');
    await Hive.openBox('serial_setup_state');
    await Hive.openBox('savedSheetSizes');
    await Hive.openBox('savedSheetSizes_production');
    await Hive.openBox('inkReports');
    await Hive.openBox('storeEntries');

    // الصيانة
    await Hive.openBox<MaintenanceRecord>('maintenance_records_main');
    await Hive.openBox<MaintenanceRecord>('maintenance_staple_v2');
    await Hive.openBox<MaintenanceRecord>('maintenance_flexo_v2');
    await Hive.openBox<MaintenanceRecord>('maintenance_production_v2');

    // المخازن
    await Hive.openBox<StoreEntry>('store_flexo');
    await Hive.openBox<StoreEntry>('store_production');
    await Hive.openBox<StoreEntry>('store_staple');

    // العمال
    await Hive.openBox<WorkerAction>('worker_actions');
    await Hive.openBox<Worker>('workers');
    await Hive.openBox<Worker>('workers_flexo');
    await Hive.openBox<Worker>('workers_production');
    await Hive.openBox<Worker>('workers_staple');

    // المنتجات
    await Hive.openBox<FinishedProduct>('finished_products');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
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
      title: 'Smart Sheet',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      home: const SplashScreen(),
      routes: {
        SettingsScreen.routeName: (context) => const SettingsScreen(),
        CameraQualitySettingsScreen.routeName: (context) =>
            const CameraQualitySettingsScreen(),
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
