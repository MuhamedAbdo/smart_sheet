import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/utils/route_observer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/home_screen.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';

import 'package:window_manager/window_manager.dart';
import 'package:smart_sheet/widgets/desktop_title_bar.dart';
import 'package:smart_sheet/widgets/desktop_sidebar.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/forgot_password_screen.dart';
import 'package:smart_sheet/screens/update_password_screen.dart';
import 'package:smart_sheet/screens/backup_restore_screen.dart';
import 'package:smart_sheet/screens/maintenance_screen.dart';
import 'package:smart_sheet/screens/store_entry_screen.dart';
import 'package:smart_sheet/screens/workers_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';

// استيراد الموديلات
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/store_entry_model.dart';
import 'package:smart_sheet/models/production_report.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/downtime_interval.dart';
import 'package:smart_sheet/models/live_session.dart';

// استيراد الخدمات والبروفايدر والشاشات
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
    // 1. التأكد من تهيئة نظام Flutter
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();

    // 2. تهيئة قواعد بيانات Hive أولاً (لأنها ضرورية للثيم والإعدادات)
    if (!kIsWeb) {
      await Hive.initFlutter();
      _registerAdapters();
      await Hive.openBox('settings');
      
      // فتح صناديق العلاقات الأساسية
      await Hive.openBox<WorkerAction>('worker_actions');
      await Future.wait([
        Hive.openBox<Worker>('workers'),
        Hive.openBox<Worker>('workers_flexo'),
        Hive.openBox<Worker>('workers_production'),
        Hive.openBox<FinishedProduct>('finished_products'),
        Hive.openBox<LiveSession>('flexo_live_sessions'),
      ]);
      _openBackgroundBoxes();
    }

    // 3. تهيئة Supabase والإشعارات
    await Future.wait([
      _initializeNotifications(),
      Supabase.initialize(
          url: supabaseUrl.trim(), anonKey: supabaseAnonKey.trim()),
    ]);

    // 4. تهيئة نافذة سطح المكتب
    if (!kIsWeb && Platform.isWindows) {
      try {
        await windowManager.ensureInitialized();
        
        WindowOptions windowOptions = const WindowOptions(
          size: Size(1280, 720),
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
        );

        await windowManager.waitUntilReadyToShow(windowOptions);
        await windowManager.show();
        await windowManager.focus();
        debugPrint("✅ Window is now visible");
      } catch (e) {
        debugPrint("⚠️ Window Manager Initialization Failed: $e");
      }
    }
  } catch (e) {
    debugPrint("❌ Critical Initialization Error: $e");
  }

  debugPrint("🚀 Reached runApp()");
  // 5. تشغيل التطبيق مع الـ Providers
  runApp(
    MultiProvider(
      providers: [
        // سيقوم ThemeProvider الآن بالعثور على صندوق settings مفتوحاً وجاهزاً
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const SmartSheetApp(),
    ),
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(11)) {
    Hive.registerAdapter(WorkerActionAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(WorkerAdapter());
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(FinishedProductAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(MaintenanceRecordAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(StoreEntryAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ProductionReportAdapter());
  if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(FlexoMachineAdapter());
  if (!Hive.isAdapterRegistered(16)) Hive.registerAdapter(DowntimeIntervalAdapter());
  if (!Hive.isAdapterRegistered(17)) Hive.registerAdapter(LiveSessionAdapter());
}

void _openBackgroundBoxes() {
  Hive.openBox<StoreEntry>('store_flexo');
  Hive.openBox<MaintenanceRecord>('maintenance_records_main');
  Hive.openBox<FlexoMachine>('flexo_machines');

  final otherBoxes = [
    'savedSheetSizes',
    'inkReports',
    'flexoArchive',
    'measurements',
    'serial_setup_state',
  ];
  for (var box in otherBoxes) {
    Hive.openBox(box).then(
      (_) => {}, // Success case - do nothing
      onError: (e) => debugPrint("⚠️ Failed to open $box: $e"),
    );
  }
}

Future<void> _initializeNotifications() async {
  if (kIsWeb || !Platform.isAndroid) return;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin
      .initialize(const InitializationSettings(android: androidSettings));
}

class SmartSheetApp extends StatelessWidget {
  const SmartSheetApp({super.key});

  @override
  Widget build(BuildContext context) {
    // مراقبة ThemeProvider للتغييرات
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: Provider.of<AuthService>(context, listen: false).navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Smart Sheet',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,

      // ✅ دعم اللغات والتقويم (DatePicker) لضمان عدم حدوث خطأ No MaterialLocalizations
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'), // العربية
        Locale('en', 'US'), // الإنجليزية
      ],
      locale: const Locale('ar', 'SA'), // اللغة الافتراضية للتطبيق

      // ✅ تطبيق حجم الخط عالمياً والتخطيط المكتبي عبر الـ Builder
      builder: (context, child) {
        return Scaffold(
          backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              if (!kIsWeb && Platform.isWindows) const DesktopTitleBar(),
              Expanded(
                child: Row(
                  children: [
                    if (!kIsWeb && Platform.isWindows)
                      ValueListenableBuilder<String?>(
                        valueListenable: currentRouteNotifier,
                        builder: (context, routeName, child) {
                          if (routeName == '/' || routeName == AuthScreen.routeName) {
                            return const SizedBox.shrink();
                          }
                          return const DesktopSidebar();
                        },
                      ),
                    Expanded(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(themeProvider.fontScale),
                        ),
                        child: child!,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },

      home: const SplashScreen(),
      routes: {
        SettingsScreen.routeName: (_) => const SettingsScreen(),

        AuthScreen.routeName: (_) => const AuthScreen(),
        ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
        UpdatePasswordScreen.routeName: (_) => const UpdatePasswordScreen(),
        BackupRestoreScreen.routeName: (_) => const BackupRestoreScreen(),
        '/maintenance': (_) => const MaintenanceScreen(
            boxName: 'maintenance_records_main', title: 'سجلات الصيانة'),
        '/store_entry': (_) => const StoreEntryScreen(
            boxName: 'store_flexo', title: 'وارد المخزن'),
        '/workers': (_) => const WorkersScreen(
            departmentBoxName: 'workers', departmentTitle: 'طاقم العمل'),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
