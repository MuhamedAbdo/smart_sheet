import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/screens/splash_screen.dart';
import 'package:smart_sheet/utils/route_observer.dart';
import 'package:smart_sheet/utils/cache_helper.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
import 'package:smart_sheet/utils/data_normalization_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_sheet/providers/theme_provider.dart';
import 'package:smart_sheet/screens/home_screen.dart';
import 'package:smart_sheet/screens/settings_screen.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/screens/die_cutting_forms_screen.dart';

import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';
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
import 'package:smart_sheet/services/kill_switch_service.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// استيراد الموديلات
import 'package:smart_sheet/models/worker_action_model.dart';
import 'package:smart_sheet/models/worker_model.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/models/maintenance_record_model.dart';
import 'package:smart_sheet/models/store_entry_model.dart';
import 'package:smart_sheet/models/flexo_production_report.dart';
import 'package:smart_sheet/models/flexo_machine.dart';
import 'package:smart_sheet/models/downtime_interval.dart';
import 'package:smart_sheet/models/live_session.dart';
import 'package:smart_sheet/models/day_schedule.dart';
import 'package:smart_sheet/models/die_cutting_form.dart';
import 'package:smart_sheet/models/die_cutting_production_report.dart';

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

// ─── Top-Level Background Handler — يجب أن يكون في أعلى مستوى خارج أي كلاس ───
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint(
      '📬 [FCM Background Handler in main.dart] Title: ${message.notification?.title ?? message.data['title']} | Body: ${message.notification?.body ?? message.data['body']}');

  // في حال كان الإشعار يعتمد على data فقط ولا يحتوي على notification object
  // نقوم بإظهاره كإشعار محلي بواسطة fcmBackgroundHandler
  if (message.notification == null) {
    await fcmBackgroundHandler(message);
  }
}

Future<void> main() async {
  bool initSuccess = false;
  String? initErrorDetails;

  try {
    // 1. التأكد من تهيئة نظام Flutter
    WidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();

    // تهيئة كاش الصور الموحد وتسريع الوصول المتزامن اللاحق
    await CacheHelper.init();

    // 2. تهيئة قواعد بيانات Hive أولاً (لأنها ضرورية للثيم والإعدادات)
    if (!kIsWeb) {
      if (Platform.isWindows) {
        await Hive.initFlutter('SmartSheet_Data');
      } else {
        await Hive.initFlutter();
      }
      _registerAdapters();

      // ─── محاولة فتح settings مع retry متقدم للتعامل مع lock file ───
      // يحدث عند التثبيت فوق نسخة قديمة بدون إغلاق التطبيق أولاً
      await _openSettingsBoxWithLockRecovery();
      // ✅ تأكد من أن كل جهاز يملك UUID ثابتاً منذ أول تشغيل
      // ضروري لنظام ملكية الإجراءات (isOwner check في action cards)
      await DeviceManager.getDeviceId();

      // فتح صناديق العلاقات الأساسية
      await Hive.openBox<WorkerAction>('worker_actions');
      await Future.wait([
        Hive.openBox<Worker>('workers'),
        Hive.openBox<Worker>('workers_flexo'),
        Hive.openBox<Worker>('workers_production'),
        Hive.openBox<Worker>('workers_staple'),
        Hive.openBox<FinishedProduct>('finished_products'),
        Hive.openBox<LiveSession>('flexo_live_sessions'),
        Hive.openBox<FlexoMachine>('flexo_machines'),
        Hive.openBox<DaySchedule>('factory_schedule'), // جدول أيام الوردية
        Hive.openBox('sync_queue'), // قائمة انتظار المزامنة
        Hive.openBox<DieCuttingForm>('die_cutting_forms'), // قوالب التكسير
        Hive.openBox<DieCuttingProductionReport>('die_cutting_production_reports'),
      ]);
      _openBackgroundBoxes();
      
      // ✅ التنظيف الفوري: طبقة التوافق (Migration/Normalization Layer)
      // نضمن تحويل أي مفاتيح قديمة في الأرشيف وقائمة الانتظار لـ snake_case مباشرة
      await DataNormalizationHelper.normalizeUntypedBoxes();
      
      // تهيئة القيم الافتراضية لجدول أيام الوردية إذا كان فارغاً
      _initDefaultSchedule();

      // إغلاق أي أذونات أو إجراءات بالساعات مفتوحة من الأيام السابقة
      Worker.autoCloseHourlyActionsGlobal();
    }

    // 3. تهيئة Firebase وتسجيل Background Handler
    // ⚠️ يجب تسجيل onBackgroundMessage فوراً بعد Firebase.initializeApp()
    //    وقبل أي عمل آخر — هذا شرط حتمي لـ Android native plugin
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await Firebase.initializeApp();
        // تسجيل Background Handler مباشرةً بعد init لضمان استقبال الإشعارات في الخلفية ومغلق
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
        debugPrint('✅ Firebase + FCM Background Handler: تمت التهيئة بنجاح.');
      } catch (e) {
        debugPrint('⚠️ Firebase init failed: $e');
      }
    }

    // 3a. تهيئة Supabase بذكاء (بدون تعطيل التطبيق)
    try {
      await Supabase.initialize(
        url: supabaseUrl.trim(),
        anonKey: supabaseAnonKey.trim(),
        authOptions:
            const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
      ).timeout(const Duration(seconds: 5));
      debugPrint("✅ Supabase initialized successfully");
    } catch (e) {
      debugPrint("⚠️ Supabase Initialization failed (Offline Mode): $e");
    }

    // 3b. تهيئة الإشعارات المحلية + Firebase Cloud Messaging
    //     مغلّفة بـ try/catch لمنع MissingPluginException من إيقاف التطبيق
    try {
      await _initializeNotifications();
      // تهيئة FCM بعد التهيئة المحلية (Android فقط)
      await PushNotificationService.init();
      debugPrint('✅ Notifications + FCM: تمت التهيئة بنجاح.');
    } catch (e) {
      debugPrint('⚠️ Notifications/FCM: تعذّرت التهيئة (مقبول): $e');
    }

    // 3c. تهيئة إشعارات سطح المكتب (Windows Native Notifications) قبل تشغيل خدمات المزامنة
    if (!kIsWeb && Platform.isWindows) {
      try {
        await localNotifier.setup(
          appName: 'Smart Sheet',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        UIUtils.markLocalNotifierReady();
        debugPrint("✅ Local Notifier setup successfully");
      } catch (e) {
        debugPrint("⚠️ Local Notifier Setup Failed: $e");
      }
    }

    // تشغيل المزامنة السحابية في الخلفية دون حظر التطبيق (Background execution)
    SyncService.instance.initialize().catchError((e) {
      debugPrint(
          "⚠️ سيرفر Supabase غير متاح حالياً، التطبيق يعمل في وضع الأوفلاين: $e");
    });
    debugPrint('✅ SyncService: تم استدعاء initialize() للعمل في الخلفية.');

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
  } catch (e, st) {
    initErrorDetails = e.toString();
    debugPrint("❌ Critical Initialization Error: $e\n$st");
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
        : _InitErrorApp(errorMessage: initErrorDetails),
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
    Hive.registerAdapter(FlexoProductionReportAdapter());
  }
  if (!Hive.isAdapterRegistered(15)) {
    Hive.registerAdapter(FlexoMachineAdapter());
  }
  if (!Hive.isAdapterRegistered(16)) {
    Hive.registerAdapter(DowntimeIntervalAdapter());
  }
  if (!Hive.isAdapterRegistered(17)) Hive.registerAdapter(LiveSessionAdapter());
  if (!Hive.isAdapterRegistered(18)) Hive.registerAdapter(DayScheduleAdapter());
  if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(ShiftAdapter());
  if (!Hive.isAdapterRegistered(20)) {
    Hive.registerAdapter(DieCuttingFormAdapter());
  }
  if (!Hive.isAdapterRegistered(25)) {
    Hive.registerAdapter(DieCuttingProductionReportAdapter());
  }
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
  Hive.openBox<FlexoProductionReport>('flexo_production_reports_box');

  final otherBoxes = [
    'savedSheetSizes',
    'flexoArchive',
    'lineArchive',
    'crushingArchive',
    'serial_setup_state',
  ];
  for (var box in otherBoxes) {
    Hive.openBox(box).then(
      (_) => {}, // Success case - do nothing
      onError: (e) => debugPrint("⚠️ Failed to open $box: $e"),
    );
  }
}

// ─── تحصين Hive Lock — 3 محاولات مع حذف Lock File آمن على جميع الأنظمة ───────────
//
// السبب: عند التثبيت فوق نسخة قديمة، يبقى ملف settings.lock
// محجوزاً من العملية السابقة. إذا فشلت المحاولة الأولى والثانية، نحاول
// حذف الـ lock file بأمان ثم إعادة الفتح.
//
Future<void> _openSettingsBoxWithLockRecovery() async {
  // المحاولة الأولى — المسار الطبيعي السريع
  try {
    await Hive.openBox('settings');
    debugPrint('✅ settings box: فُتح بنجاح (المحاولة 1)');
    return;
  } catch (e1) {
    debugPrint('⚠️ settings.lock محجوز (محاولة 1): $e1');
  }

  // المحاولة الثانية — انتظار 1.5 ثانية ثم إعادة المحاولة
  await Future.delayed(const Duration(milliseconds: 1500));
  try {
    await Hive.openBox('settings');
    debugPrint('✅ settings box: فُتح بنجاح (المحاولة 2)');
    return;
  } catch (e2) {
    debugPrint('⚠️ settings.lock لا يزال محجوزاً (محاولة 2): $e2');
  }

  // المحاولة الثالثة — حذف lock file بأمان (على جميع الأنظمة Windows & Android)
  if (!kIsWeb) {
    try {
      final hiveDir = await getApplicationDocumentsDirectory();
      final lockFile = File('${hiveDir.path}/settings.lock');
      if (lockFile.existsSync()) {
        lockFile.deleteSync();
        debugPrint('🔓 [HiveLock] تم حذف settings.lock المتعلق بأمان.');
      }
    } catch (deleteError) {
      debugPrint('⚠️ [HiveLock] تعذّر حذف lock file: $deleteError');
    }
  }

  await Future.delayed(const Duration(milliseconds: 500));
  // المحاولة الأخيرة — إذا فشلت، تُرفع الاستثناء للـ catch الخارجي
  await Hive.openBox('settings');
  debugPrint('✅ settings box: فُتح بنجاح (المحاولة 3 بعد حذف اللوك)');
}

Future<void> _initializeNotifications() async {
  if (kIsWeb || !Platform.isAndroid) return;
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // طلب صلاحيات الإشعارات لأندرويد 13 فما فوق لضمان عملها على كل الأجهزة
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // إنشاء وتوثيق قناة الإشعارات (Notification Channel) في نظام Android 8+ لضمان ظهور الإشعار بـ High Priority
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'factory_push_channel',
    'إشعارات المصنع',
    description: 'إشعارات Push الحقيقية من المصنع',
    importance: Importance.max,
    playSound: true,
  );
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        try {
          final payloadData = jsonDecode(response.payload!);
          final clientName = payloadData['clientName']?.toString();

          if (clientName != null && clientName.isNotEmpty) {
            // التحقق من وجود العميل محلياً قبل التوجيه
            bool clientExists = false;
            if (Hive.isBoxOpen('savedSheetSizes')) {
              final box = Hive.box('savedSheetSizes');
              for (var i = 0; i < box.length; i++) {
                final item = box.getAt(i);
                if (item is Map &&
                    (item['clientName']?.toString().trim() ?? '') ==
                        clientName.trim()) {
                  clientExists = true;
                  break;
                }
              }
            }

            if (clientExists) {
              final authService = Provider.of<AuthService>(
                  scaffoldMessengerKey.currentContext!,
                  listen: false);
              final nav = authService.navigatorKey.currentState;
              if (nav != null) {
                bool isAlreadyTop = false;
                nav.popUntil((route) {
                  if (route.isCurrent &&
                      route.settings.name == 'ClientItemsScreen_$clientName') {
                    isAlreadyTop = true;
                  }
                  return true;
                });

                if (!isAlreadyTop) {
                  nav.push(
                    MaterialPageRoute(
                      settings:
                          RouteSettings(name: 'ClientItemsScreen_$clientName'),
                      builder: (_) => ClientItemsScreen(clientName: clientName),
                    ),
                  );
                }
              }
            } else {
              debugPrint('⚠️ العميل غير موجود محلياً: $clientName');
            }
          }
        } catch (e) {
          debugPrint('❌ _initializeNotifications payload parsing error: $e');
        }
      }
    },
  );
}

class SmartSheetApp extends StatefulWidget {
  const SmartSheetApp({super.key});

  @override
  State<SmartSheetApp> createState() => _SmartSheetAppState();
}

class _SmartSheetAppState extends State<SmartSheetApp>
    with WidgetsBindingObserver {
  // ─── Debounce لمنع استدعاء initialize() أكثر من مرة عند resume ──
  // يحدث على Windows عند إعادة التركيز على النافذة
  DateTime? _lastResumeTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ✅ بدء مستمع Kill Switch بعد أول بناء للتطبيق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startKillSwitchListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KillSwitchService.instance.stopListening();
    super.dispose();
  }

  // ==============================================================================
  // Kill Switch Listener
  // ==============================================================================

  /// يبدأ الاستماع لتغييرات ارتباط الجهاز — لأجهزة العمال فقط (employee).
  /// لا يعمل على جهاز الآدمن أو عند عدم وجود ربط.
  Future<void> _startKillSwitchListener() async {
    try {
      const storage = SafeSecureStorage();
      final factoryId = await storage.read(key: 'factory_id');
      final userRole = await storage.read(key: 'user_role');

      if (factoryId == null) {
        debugPrint('⏭️ KillSwitch: غير ممكّن (غير مرتبط بمصنع)');
        return;
      }

      // 1. فحص الحالة الفورية من السحاب لتنفيذ الطرد القسري إن تم فك الارتباط
      final loggedOut =
          await KillSwitchService.instance.checkAndEnforceKillSwitch(
        onForcedLogout: _onForcedLogout,
      );
      if (loggedOut) return;

      // 2. جلب معرّف العامل المحفوظ محلياً (إذا لم يكن آدمن) وبدء قناة الاستماع
      final workerId = userRole == 'admin' ? null : await KillSwitchService.instance.getLinkedWorkerId();
      
      debugPrint('🔒 KillSwitch: تفعيل المستمع (Factory: $factoryId, Worker: $workerId)');
      await KillSwitchService.instance.startListening(
        factoryId: factoryId,
        workerId: workerId,
        onForcedLogout: _onForcedLogout,
      );
    } catch (e) {
      debugPrint('❌ KillSwitch._startKillSwitchListener: $e');
    }
  }

  /// الطرد القسري من التطبيق وإعادة التوجيه لشاشة الربط.
  void _onForcedLogout(String message) {
    debugPrint('🚨 KillSwitch: تنفيذ الطرد القسري... السبب: $message');
    // إعادة التوجيه لشاشة Auth (الربط بالمصنع)
    if (!mounted) return;

    final authService = context.read<AuthService>();
    final nav = authService.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(
        AuthScreen.routeName,
        (route) => false,
      );
    }

    // عرض SnackBar بعد الانتقال
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.link_off, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  /// إعادة تهيئة الـ Realtime channels عند العودة للمقدمة —
  /// على Android يقوم النظام بإيقاف WebSocket في الخلفية،
  /// مما يُفضي إلى فقدان أحداث live_sessions على الأجهزة غير المُنشئة للجلسة.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();

      // تحديد مدة الـ Debounce بناءً على المنصة:
      // الموبايل (Android/iOS): 3 ثوانٍ فقط، لأن التطبيق قد يعود من الخلفية ويحتاج تحديث سريع.
      // الديسكتوب (Windows/Mac/Linux): 5 دقائق (300 ثانية)، لأن مجرد النقر على النافذة (Gain Focus)
      // يطلق حدث resumed، مما يؤدي إلى إعادة تهيئة المزامنة بشكل مستمر ومزعج إذا لم نضع مسافة زمنية طويلة.
      final int debounceSeconds = (Platform.isAndroid || Platform.isIOS) ? 3 : 300;

      // تجاهل أي استدعاء ثانٍ في غضون المدة المحددة
      if (_lastResumeTime != null &&
          now.difference(_lastResumeTime!).inSeconds < debounceSeconds) {
        debugPrint(
            '⏭️ SmartSheetApp: تجاهل resume مكرر (${now.difference(_lastResumeTime!).inSeconds}s < $debounceSeconds)');
        return;
      }
      _lastResumeTime = now;
      debugPrint('▶️ SmartSheetApp: العودة للمقدمة → إعادة تهيئة المزامنة...');
      _startKillSwitchListener();
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
        '/die_cutting_forms': (_) => const DieCuttingFormsScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}

// ─── شاشة الخطأ الحرج ─────────────────────────────────────────
// تُعرض عوضاً عن الـ crash الصامت عند فشل التهيئة
// السبب الأكثر شيوعاً: ملف settings.lock محجوز بسبب نسخة سابقة من التطبيق
class _InitErrorApp extends StatelessWidget {
  final String? errorMessage;
  const _InitErrorApp({this.errorMessage});

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
                const Icon(Icons.error_outline,
                    color: Color(0xFFE94560), size: 72),
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
                Text(
                  errorMessage != null
                      ? 'السبب التفصيلي: $errorMessage'
                      : 'تأكد من إغلاق أي نسخة أخرى من التطبيق تعمل في الخلفية، ثم أعد التشغيل.',
                  style: const TextStyle(
                      color: Color(0xFFAAAAAA), fontSize: 14, height: 1.6),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('تحقق من اللوجات',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    debugPrint(
                        '🔄 _InitErrorApp: المستخدم طلب مراجعة اللوجات.');
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

