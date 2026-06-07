import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/utils/route_observer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/home_screen.dart';
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
import 'package:smart_sheet/utils/device_manager.dart';

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
import 'package:smart_sheet/models/day_schedule.dart';

// استيراد الخدمات والبروفايدر والشاشات
import 'package:smart_sheet/config/constants.dart';
import 'package:smart_sheet/services/sync_service.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  bool initSuccess = false;

  try {
    // 1. التأكد من تهيئة نظام Flutter
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();

    // 2. تهيئة قواعد بيانات Hive أولاً (لأنها ضرورية للثيم والإعدادات)
    if (!kIsWeb) {
      await Hive.initFlutter();
      _registerAdapters();

      // ─── محاولة فتح settings مع retry للتعامل مع lock file ───
      // يحدث عند وجود نسخة سابقة من التطبيق لم تُغلق بعد
      try {
        await Hive.openBox('settings');
        // ✅ تأكد من أن كل جهاز يملك UUID ثابتاً منذ أول تشغيل
        // ضروري لنظام ملكية الإجراءات (isOwner check في action cards)
        await DeviceManager.getDeviceId();
      } catch (lockError) {
        debugPrint('⚠️ settings.lock محجوز، انتظار 1 ثانية وإعادة المحاولة: $lockError');
        await Future.delayed(const Duration(seconds: 1));
        await Hive.openBox('settings'); // إذا فشلت المرة الثانية → ستُرفع للـ catch الخارجي
        await DeviceManager.getDeviceId();
      }

      // فتح صناديق العلاقات الأساسية
      await Hive.openBox<WorkerAction>('worker_actions');
      await Future.wait([
        Hive.openBox<Worker>('workers'),
        Hive.openBox<Worker>('workers_flexo'),
        Hive.openBox<Worker>('workers_production'),
        Hive.openBox<Worker>('workers_staple'),
        Hive.openBox<FinishedProduct>('finished_products'),
        Hive.openBox<LiveSession>('flexo_live_sessions'),
        Hive.openBox<DaySchedule>('factory_schedule'), // جدول أيام الوردية
        Hive.openBox('sync_queue'), // قائمة انتظار المزامنة
      ]);
      _openBackgroundBoxes();
      // تهيئة القيم الافتراضية لجدول أيام الوردية إذا كان فارغاً
      _initDefaultSchedule();
      
      // إغلاق أي أذونات أو إجراءات بالساعات مفتوحة من الأيام السابقة
      Worker.autoCloseHourlyActionsGlobal();
    }

    // 3. تهيئة Supabase بذكاء (بدون تعطيل التطبيق)
    try {
      await Supabase.initialize(
        url: supabaseUrl.trim(),
        anonKey: supabaseAnonKey.trim(),
        authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      ).timeout(const Duration(seconds: 5));
      debugPrint("✅ Supabase initialized successfully");
    } catch (e) {
      debugPrint("⚠️ Supabase Initialization failed (Offline Mode): $e");
    }

    // 3b. تهيئة الإشعارات — مغلّفة بـ try/catch لمنع MissingPluginException
    //     من إيقاف التطبيق (تحدث على المحاكي أو عند التشغيل بعد Clean Build)
    try {
      await _initializeNotifications();
      debugPrint('✅ Notifications: تمت التهيئة بنجاح.');
    } catch (e) {
      debugPrint(
          '⚠️ Notifications: تعذّرت التهيئة (MissingPluginException مقبول): $e');
    }

    // تشغيل المزامنة السحابية في الخلفية دون حظر التطبيق (Background execution)
    SyncService.instance.initialize().catchError((e) {
      debugPrint("⚠️ سيرفر Supabase غير متاح حالياً، التطبيق يعمل في وضع الأوفلاين: $e");
    });
    debugPrint(
        '✅ SyncService: تم استدعاء initialize() للعمل في الخلفية.');

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

    initSuccess = true; // ✅ نجح كل شيء
  } catch (e) {
    debugPrint("❌ Critical Initialization Error: $e");
    // لا نكمل — نُظهر شاشة خطأ واضحة بدلاً من الـ crash الصامت
  }

  debugPrint("🚀 Reached runApp() | initSuccess=$initSuccess");

  // 5. تشغيل التطبيق مع الـ Providers
  runApp(
    initSuccess
        ? MultiProvider(
            providers: [
              // سيقوم ThemeProvider الآن بالعثور على صندوق settings مفتوحاً وجاهزاً
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => AuthService()),
            ],
            child: const SmartSheetApp(),
          )
        : const _InitErrorApp(),
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
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(ProductionReportAdapter());
  }
  if (!Hive.isAdapterRegistered(15)) {
    Hive.registerAdapter(FlexoMachineAdapter());
  }
  if (!Hive.isAdapterRegistered(16)) {
    Hive.registerAdapter(DowntimeIntervalAdapter());
  }
  if (!Hive.isAdapterRegistered(17)) Hive.registerAdapter(LiveSessionAdapter());
  if (!Hive.isAdapterRegistered(18)) Hive.registerAdapter(DayScheduleAdapter());
}

/// يُعبّئ صندوق factory_schedule بالقيم الافتراضية إذا كان فارغاً (أول تشغيل)
void _initDefaultSchedule() {
  if (!Hive.isBoxOpen('factory_schedule')) return;
  final box = Hive.box<DaySchedule>('factory_schedule');
  if (box.isEmpty) {
    for (final d in DaySchedule.defaults) {
      box.put(d.dayName, d);
    }
    debugPrint('✅ factory_schedule: تم تعبئة الإعدادات الافتراضية.');
  }
}

void _openBackgroundBoxes() {
  Hive.openBox<StoreEntry>('store_flexo');
  Hive.openBox<MaintenanceRecord>('maintenance_records_main');
  Hive.openBox<FlexoMachine>('flexo_machines');

  final otherBoxes = [
    'savedSheetSizes',
    'inkReports',
    'flexoArchive',
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

class SmartSheetApp extends StatefulWidget {
  const SmartSheetApp({super.key});

  @override
  State<SmartSheetApp> createState() => _SmartSheetAppState();
}

class _SmartSheetAppState extends State<SmartSheetApp>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// إعادة تهيئة الـ Realtime channels عند العودة للمقدمة —
  /// على Android يقوم النظام بإيقاف WebSocket في الخلفية،
  /// مما يُفضي إلى فقدان أحداث live_sessions على الأجهزة غير المُنشئة للجلسة.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('▶️ SmartSheetApp: العودة للمقدمة → إعادة تهيئة المزامنة...');
      SyncService.instance.initialize().catchError((e) {
        debugPrint('❌ SmartSheetApp: فشل initialize() عند resume: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // مراقبة ThemeProvider للتغييرات
    final themeProvider = context.watch<ThemeProvider>();

    // تسجيل ThemeProvider في SyncService حتى يتمكن FactorySync mixin
    // من تطبيق أوقات الوردية الواردة من Supabase Realtime مباشرةً.
    SyncService.instance.setThemeProvider(themeProvider);

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey:
          Provider.of<AuthService>(context, listen: false).navigatorKey,
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
          resizeToAvoidBottomInset: false,
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
                          if (routeName == '/' ||
                              routeName == AuthScreen.routeName) {
                            return const SizedBox.shrink();
                          }
                          return const DesktopSidebar();
                        },
                      ),
                    Expanded(
                      child: MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler:
                              TextScaler.linear(themeProvider.fontScale),
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

// ─── شاشة الخطأ الحرج ─────────────────────────────────────────
// تُعرض عوضاً عن الـ crash الصامت عند فشل التهيئة
// السبب الأكثر شيوعاً: ملف settings.lock محجوز بسبب نسخة سابقة من التطبيق
class _InitErrorApp extends StatelessWidget {
  const _InitErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFE94560), size: 72),
                const SizedBox(height: 24),
                const Text(
                  'فشل تشغيل التطبيق',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                const Text(
                  'تأكد من إغلاق أي نسخة أخرى من التطبيق تعمل في الخلفية، ثم أعد التشغيل.',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('تحقق من اللوجات', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    debugPrint('🔄 _InitErrorApp: المستخدم طلب مراجعة اللوجات.');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
