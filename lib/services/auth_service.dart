import 'dart:async';
import 'package:hive/hive.dart';
import 'package:smart_sheet/utils/permission_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_state.dart';
import 'package:flutter/material.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/pairing_service.dart';
import 'package:smart_sheet/services/kill_switch_service.dart';
import 'package:smart_sheet/services/push_notification_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  UserState _state = UserState.unauthenticated();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  UserState get state => _state;
  bool get isAuthenticated {
    if (Hive.isBoxOpen('settings')) {
      return Hive.box('settings')
              .get('is_user_logged_in', defaultValue: false) ==
          true;
    }
    return false;
  }

  String? get factoryId => _factoryId;
  bool get isDeviceLinked => _factoryId != null && _factoryId!.isNotEmpty;
  bool get isAdmin => _state.role?.trim().toLowerCase() == 'admin';
  String? get currentUserEmail => _state.user?.email;
  String? _factoryId;

  AuthService() {
    // 💡 الاستماع إلى تغيرات حالة Supabase
    _supabaseClient.auth.onAuthStateChange.listen((data) {
      _onAuthStateChange(data.event, data.session);
    });

    // تحقق من الجلسة الأولية عند التشغيل
    _checkInitialSession();
    _loadFactoryId();
  }

  Future<void> _loadFactoryId() async {
    const storage = SafeSecureStorage();
    _factoryId = await storage.read(key: 'factory_id');
    notifyListeners();
  }

  void _onAuthStateChange(AuthChangeEvent event, Session? session) {
    if (event == AuthChangeEvent.passwordRecovery) {
      // التوجه تلقائياً إلى شاشة تحديث كلمة المرور
      navigatorKey.currentState?.pushNamed('/update-password');
    }

    if (session != null) {
      // Keep existing role if available to avoid flicker before fetch
      _state = UserState.authenticated(session.user, role: _state.role);

      if (event == AuthChangeEvent.initialSession ||
          event == AuthChangeEvent.signedIn) {
        _fetchAndStoreUserData(session.user.id);
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('is_user_logged_in', true);
        }
        // ✅ إذا كنا في وضع الأوفلاين وتم تجديد الجلسة، يجب فحص حالة المصنع والبروفايل فوراً
        if (_state.user?.id == 'local_cached_user' || _factoryId == null) {
          _fetchAndStoreUserData(session.user.id);
        }
      } else {
        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('is_user_logged_in', true);
        }
      }
    } else {
      final isLocalLoggedIn = Hive.isBoxOpen('settings') &&
          Hive.box('settings').get('is_user_logged_in', defaultValue: false) ==
              true;
      if (!isLocalLoggedIn) {
        _state = UserState.unauthenticated();
        _clearUserData();
      }
    }
    notifyListeners();
  }

  void _checkInitialSession() {
    final session = _supabaseClient.auth.currentSession;
    final isLocalLoggedIn = Hive.isBoxOpen('settings') &&
        Hive.box('settings').get('is_user_logged_in', defaultValue: false) ==
            true;

    debugPrint(
        '🔍 AuthService._checkInitialSession: session=${session != null}, isLocalLoggedIn=$isLocalLoggedIn');

    if (session != null) {
      debugPrint(
          '🔍 AuthService: Session exists, calling _fetchAndStoreUserData');
      _state = UserState.authenticated(session.user, role: _state.role);
      if (Hive.isBoxOpen('settings')) {
        Hive.box('settings').put('is_user_logged_in', true);
      }
      _fetchAndStoreUserData(session.user.id);
    } else if (isLocalLoggedIn) {
      final user = _supabaseClient.auth.currentUser;
      debugPrint(
          '🔍 AuthService: Session is NULL, but isLocalLoggedIn=true. currentUser=${user != null}');
      if (user != null) {
        _state = UserState.authenticated(user, role: _state.role);
        _fetchAndStoreUserData(user.id);
      } else {
        debugPrint(
            '🚨 AuthService: Both session and user are NULL! The session was revoked or expired. Forcing logout to protect data.');
        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('is_user_logged_in', false);
        }

        // مسح البيانات الإجباري
        KillSwitchService.instance.forceLogout(
          clearProfileFactoryId: false,
          reason: 'انتهت الجلسة أو تم إلغاؤها. يرجى تسجيل الدخول مجدداً.',
        );

        _state = UserState.unauthenticated().copyWith(
          errorMessage: 'انتهت الجلسة أو تم إلغاؤها. يرجى تسجيل الدخول مجدداً.',
        );
        _clearUserData();

        Future.microtask(() {
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/auth-screen', (route) => false);
        });
      }
    } else {
      debugPrint(
          '🔍 AuthService: Not logged in locally and no session. Logging out.');
      _state = UserState.unauthenticated();
      _clearUserData();
    }
    notifyListeners();
  }

  Future<void> _fetchAndStoreUserData(String userId,
      {bool checkDeviceLink = true}) async {
    try {
      const storage = SafeSecureStorage();

      final response = await _supabaseClient
          .from('profiles')
          .select('factory_id, role, status')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final role = response['role']?.toString() ?? 'employee';
        await storage.write(key: 'user_role', value: role);

        final fetchedFactoryId = response['factory_id']?.toString();
        final userEmail = _supabaseClient.auth.currentUser?.email;
        final status = response['status']?.toString() ?? 'active';

        // 🚨 0. فحص حالة الحساب (إيقاف مؤقت)
        if (status == 'suspended') {
          debugPrint(
              '🚨 AuthService: User status is suspended. Disabling permissions.');
          PermissionHelper.isSuspended = true;
          await storage.write(key: 'is_suspended', value: 'true');
          // لا نطرده، نتركه يدخل التطبيق لكن بلا صلاحيات ولا مزامنة
        } else {
          PermissionHelper.isSuspended = false;
          await storage.write(key: 'is_suspended', value: 'false');
        }

        // 🚨 0.5. حفظ الإيميل في الـ profiles لتسهيل التعرف على الحساب من قبل الإدارة
        if (userEmail != null && userEmail.isNotEmpty) {
          try {
            await _supabaseClient
                .from('profiles')
                .update({'email': userEmail}).eq('id', userId);
          } catch (e) {
            debugPrint('⚠️ AuthService: Failed to update email in profile: $e');
          }
        }

        final oldFactoryId = await storage.read(key: 'factory_id');

        // 🚨 1. فحص الحسابات التي تم فك ارتباطها (كان لها مصنع وتمت إزالته)
        if (fetchedFactoryId == null &&
            oldFactoryId != null &&
            oldFactoryId.isNotEmpty &&
            userEmail != 'mohamedabdo9999933@gmail.com' &&
            role != 'super_admin') {
          debugPrint('🚨 AuthService: User was unlinked. Wiping data.');
          await KillSwitchService.instance.forceLogout(
            reason:
                'تم فك ارتباط حسابك بالمصنع. يرجى الانتظار حتى يتم ربطك بمصنع جديد.',
            clearProfileFactoryId: false,
          );
          _state = UserState.unauthenticated().copyWith(
            errorMessage: 'تم فك ارتباط حسابك.',
          );
          notifyListeners();
          return; // 🛑 إيقاف استكمال عملية تسجيل الدخول
        }

        // 🚨 2. مسح البيانات إذا تغير المصنع لمنع تسريب بيانات المصنع القديم
        if (oldFactoryId != null &&
            oldFactoryId != fetchedFactoryId &&
            fetchedFactoryId != null) {
          debugPrint('🚨 AuthService: Factory ID changed. Wiping old data.');
          await KillSwitchService.instance.forceLogout(
            reason:
                'تم تغيير المصنع الخاص بك. يرجى إعادة تسجيل الدخول مرة أخرى لتحديث البيانات.',
            clearProfileFactoryId: false,
          );
          _state = UserState.unauthenticated().copyWith(
            errorMessage:
                'تم تغيير المصنع الخاص بك. يرجى إعادة تسجيل الدخول مرة أخرى لتحديث البيانات.',
          );
          notifyListeners();
          return; // 🛑 إيقاف استكمال عملية تسجيل الدخول
        }

        // 🚨 3. فحص حالة المصنع (موقوف أم لا) لجميع المستخدمين بما فيهم المدراء
        if (fetchedFactoryId != null) {
          try {
            final factoryRecord = await _supabaseClient
                .from('factories')
                .select('status')
                .eq('factory_id', fetchedFactoryId)
                .single();

            if (factoryRecord['status'] == 'suspended') {
              debugPrint(
                  '🚨 AuthService: المصنع موقوف مؤقتاً. سيتم منع الدخول ومسح البيانات.');
              await KillSwitchService.instance.forceLogout(
                reason:
                    'تم إيقاف هذا المصنع مؤقتاً. يرجى مراجعة الإدارة العليا.',
                clearProfileFactoryId: false,
              );

              _state = UserState.unauthenticated().copyWith(
                errorMessage:
                    'تم إيقاف هذا المصنع مؤقتاً. يرجى مراجعة الإدارة العليا.',
              );
              notifyListeners();
              return;
            }
          } on PostgrestException catch (e) {
            if (e.code == 'PGRST116') {
              debugPrint(
                  '🚨 AuthService: تم حجب المصنع بواسطة سياسات الأمان (RLS). سيتم منع الدخول ومسح البيانات.');
              await KillSwitchService.instance.forceLogout(
                reason:
                    'تم إيقاف هذا المصنع مؤقتاً. يرجى مراجعة الإدارة العليا.',
                clearProfileFactoryId: false,
              );

              _state = UserState.unauthenticated().copyWith(
                errorMessage:
                    'تم إيقاف هذا المصنع مؤقتاً. يرجى مراجعة الإدارة العليا.',
              );
              notifyListeners();
              return;
            }
            debugPrint(
                '⚠️ AuthService check factory status PostgrestException: $e');
          } catch (e) {
            debugPrint('⚠️ AuthService check factory status error: $e');
          }
        }

        // 🚨 4. فحص is_device_linked
        if (checkDeviceLink) {
          if (role != 'admin' && userEmail != null && userEmail.isNotEmpty) {
            try {
              final workerRecord = await _supabaseClient
                  .from('workers')
                  .select('is_device_linked')
                  .eq('email', userEmail)
                  .maybeSingle();
              if (workerRecord != null) {
                final isLinked =
                    workerRecord['is_device_linked'] as bool? ?? true;
                if (!isLinked) {
                  debugPrint(
                      '🚨 AuthService: هذا الحساب تم فك ارتباطه من الإدارة! مسح البيانات ومنع الدخول...');
                  await _supabaseClient
                      .from('profiles')
                      .update({'factory_id': null}).eq('id', userId);

                  await KillSwitchService.instance.forceLogout(
                    reason: 'تم فك ارتباطك بهذا المصنع. يرجى مراجعة الإدارة.',
                    clearProfileFactoryId: true,
                  );
                  _state = UserState.unauthenticated().copyWith(
                    errorMessage:
                        'تم فك ارتباطك بهذا المصنع. يرجى مراجعة الإدارة.',
                  );
                  notifyListeners();
                  return;
                }
              }
            } catch (e) {
              debugPrint('⚠️ AuthService check is_device_linked error: $e');
            }
          }
        } else {
          debugPrint(
              'ℹ️ AuthService._fetchAndStoreUserData: تخطي فحص is_device_linked (تحديث دوري)');
        }

        _factoryId = fetchedFactoryId;
        if (_factoryId != null) {
          await storage.write(key: 'factory_id', value: _factoryId!);
        }
        // ✅ إذا كان _factoryId == null لأن profiles.factory_id == null وليس بسبب فك الارتباط، نحتفظ بالقيمة المحلية المخزّنة
        else if (_factoryId == null && !checkDeviceLink) {
          // إعادة القراءة من Secure Storage لتجنب فقدان factory_id المحلي
          final cached = await storage.read(key: 'factory_id');
          if (cached != null && cached.isNotEmpty) {
            _factoryId = cached;
            debugPrint(
                'ℹ️ AuthService: احتفظ بـ factory_id المحلي ($cached) لأن profiles.factory_id = null وتحديث دوري.');
          }
        }

        _state = _state.copyWith(role: role);

        if (Hive.isBoxOpen('settings')) {
          Hive.box('settings').put('is_user_logged_in', true);
        }

        notifyListeners();

        // تفعيل Real-time channels والمزامنة المبدئية بعد تخزين factory_id
        await SyncService.instance.initialize();

        // 🔔 رفع FCM Token للعامل بعد التهيئة الناجحة (Android فقط)
        // نُرسل التوكن بعد المزامنة لضمان وجود سجل العامل في Supabase
        if (userEmail != null && userEmail.isNotEmpty) {
          unawaited(PushNotificationService.uploadToken(userEmail));
        }
      } else {
        // Profile not found (could be due to RLS policies blocking the select)
        debugPrint(
            '🚨 AuthService: لم يتم العثور على ملف المستخدم (RLS Block). المصنع موقوف أو الحساب محذوف!');

        final localFactoryId = await storage.read(key: 'factory_id');

        if (localFactoryId == null) {
          debugPrint(
              'ℹ️ AuthService: حساب جديد. السماح بالدخول وتعيين role كـ employee.');
          _factoryId = null;
          _state = _state.copyWith(role: 'employee');

          if (Hive.isBoxOpen('settings')) {
            Hive.box('settings').put('is_user_logged_in', true);
          }
          notifyListeners();
        } else {
          await KillSwitchService.instance.forceLogout(
            reason:
                'تم إيقاف هذا المصنع أو سحب صلاحياتك. يرجى مراجعة الإدارة العليا.',
            clearProfileFactoryId: false,
          );

          _state = UserState.unauthenticated().copyWith(
            errorMessage:
                'تم إيقاف هذا المصنع أو سحب صلاحياتك. يرجى مراجعة الإدارة العليا.',
          );
          notifyListeners();
        }
      }
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        debugPrint('🚨 AuthService: PostgrestException PGRST116. RLS blocked.');
        final localFactoryId =
            await const SafeSecureStorage().read(key: 'factory_id');

        if (localFactoryId == null) {
          debugPrint(
              'ℹ️ AuthService: حساب جديد (Caught Exception). السماح بالدخول وتعيين role كـ employee.');
          _factoryId = null;
          _state = _state.copyWith(role: 'employee');

          if (Hive.isBoxOpen('settings')) {
            Hive.box('settings').put('is_user_logged_in', true);
          }
          notifyListeners();
        } else {
          await KillSwitchService.instance.forceLogout(
            reason:
                'تم إيقاف هذا المصنع أو سحب صلاحياتك. يرجى مراجعة الإدارة العليا.',
            clearProfileFactoryId: false,
          );
          _state = UserState.unauthenticated().copyWith(
            errorMessage:
                'تم إيقاف هذا المصنع أو سحب صلاحياتك. يرجى مراجعة الإدارة العليا.',
          );
          notifyListeners();
        }
      } else {
        debugPrint('Error fetching user data: $e');
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _clearUserData() async {
    const storage = SafeSecureStorage();
    await storage.delete(key: 'factory_id');
    await storage.delete(key: 'user_role');
    _factoryId = null;
    // إلغاء Real-time channels عند تسجيل الخروج
    unawaited(SyncService.instance.dispose());
  }

  /// 📧 تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  Future<String?> signIn(
      {required String email, required String password}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final res = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session != null) {
        // ننتظر تحميل بيانات المستخدم وحالة المصنع بدلاً من الاعتماد على الخلفية
        await _fetchAndStoreUserData(res.session!.user.id);

        if (!isAuthenticated || _state.errorMessage != null) {
          return _state.errorMessage ?? 'عفواً، لا يمكن تسجيل الدخول.';
        }
      }

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return null; // نجاح
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// تحديث البيانات من السيرفر (مسح التخزين المؤقت)
  Future<String?> refreshUserData() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return "يرجى تسجيل الدخول أولاً";

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final oldRole = _state.role;
      const storage = SafeSecureStorage();
      final oldFactoryId = await storage.read(key: 'factory_id');

      // ✅ إصلاح: عند التحديث الدوري، لا نمسح factory_id ولا نتحقق من is_device_linked
      // (تحقيق الجهاز يتم فقط عند تسجيل الدخول الأولي)
      await storage.delete(
          key: 'user_role'); // فقط الدور يُعاد جلبه، ليس factory_id

      // جلب البيانات من السيرفر بدون فحص is_device_linked (لمنع مسح factory_id بالخطأ)
      await _fetchAndStoreUserData(user.id, checkDeviceLink: false);

      final newRole = _state.role;
      final newFactoryId = await storage.read(key: 'factory_id');

      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      if ((oldRole != null && oldRole != newRole) ||
          (oldFactoryId != null &&
              newFactoryId != null &&
              oldFactoryId != newFactoryId)) {
        // ✅ تغيير حقيقي في المصنع — تسجيل خروج للمزامنة الكاملة
        await signOut();
        return "⚠️ تم اكتشاف تغيير في الصلاحيات أو المصنع.\nتم تسجيل الخروج تلقائياً لضمان سلامة البيانات.";
      }

      return null; // نجاح التحديث بدون تغييرات حرجية
    } catch (e) {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return "فشل التحديث: $e";
    }
  }

  /// 🔗 ربط الموظف بمصنع جديد عبر QR Code أو كود يدوي
  Future<String?> linkToFactory(String inputCode) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw Exception('المستخدم غير مسجل الدخول');
      }

      String factoryId = inputCode.trim();

      // إذا كان الكود قصيراً (6 خانات أو أقل)، نتحقق من خدمة الربط
      if (factoryId.length <= 6) {
        final pairingResult = await PairingService().verifyAndLink(factoryId);

        if (pairingResult != null && pairingResult['success'] == true) {
          factoryId = pairingResult['factory_id'];
          debugPrint('✅ Resolved pairing code $inputCode to $factoryId');
        } else {
          throw Exception(pairingResult?['error'] ??
              'كود الربط غير صحيح أو منتهي الصلاحية');
        }
      }

      // تحديث أو إنشاء ملف المستخدم في قاعدة البيانات
      await _supabaseClient.from('profiles').upsert({
        'id': user.id,
        'factory_id': factoryId,
        'role': 'employee',
      });

      // تسجيل وتفعيل ارتباط الجهاز في جدول workers في Supabase
      if (user.email != null && user.email!.isNotEmpty) {
        await KillSwitchService.instance.registerDevice(
          email: user.email!,
          factoryId: factoryId,
        );
      }

      // تحديث الجلسة والبيانات لتفعيل الهوية الجديدة فوراً
      await refreshUserData();

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return null; // نجاح
    } catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: 'فشل الربط: $e');
      notifyListeners();
      return 'فشل الربط: $e';
    }
  }

  /// 📝 إنشاء حساب جديد (تسجيل)
  Future<String?> signUp(
      {required String email, required String password}) async {
    // 1. بدء التحميل
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
        // 💡 إضافة رابط إعادة التوجيه لفتح التطبيق عند الضغط على زر التفعيل في الإيميل
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      );

      // 2. إيقاف التحميل فوراً عند استلام رد من السيرفر
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      if (response.session == null) {
        // 💡 رسالة واضحة للمستخدم وتوجيهه للجيميل
        return '✅ تم إنشاء الحساب بنجاح!\n\nيرجى فتح بريدك الإلكتروني (Gmail) الآن والضغط على رابط التفعيل لتتمكن من الدخول إلى التطبيق.';
      }

      return null; // نجاح (في حال كان التفعيل التلقائي مفعلاً في Supabase)
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// � إعادة تعيين كلمة المرور
  Future<String?> resetPassword({required String email}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      await _supabaseClient.auth.resetPasswordForEmail(email);
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      return '✅ تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.\n\nيرجى فتح بريدك والضغط على الرابط لتعيين كلمة مرور جديدة.';
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// � تحديث كلمة المرور الجديدة
  Future<String?> updatePassword({required String newPassword}) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      await _supabaseClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _state = _state.copyWith(isLoading: false);
      notifyListeners();

      return '✅ تم تحديث كلمة المرور بنجاح';
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, errorMessage: e.message);
      notifyListeners();
      return e.message;
    } catch (e) {
      _state = _state.copyWith(
          isLoading: false, errorMessage: 'حدث خطأ غير متوقع: $e');
      notifyListeners();
      return 'حدث خطأ غير متوقع: $e';
    }
  }

  /// �🚪 تسجيل الخروج
  Future<void> signOut() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();
    try {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').put('is_user_logged_in', false);
      }

      // مسح الصناديق المحلية بالكامل عند تسجيل الخروج لحماية البيانات
      await KillSwitchService.instance.forceLogout(
        clearProfileFactoryId: false,
        reason: 'تم تسجيل الخروج بنجاح',
      );

      // العودة الإجبارية لشاشة تسجيل الدخول
      Future.microtask(() {
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/auth-screen', (route) => false);
      });
    } catch (e) {
      _state = UserState.unauthenticated()
          .copyWith(errorMessage: 'فشل تسجيل الخروج: $e');
      notifyListeners();
    }
  }

  /// 🔓 فك ارتباط الجهاز بالمصنع الحالي (مسح factory_id محلياً ومن السيرفر)
  Future<void> unlinkFactory() async {
    const storage = SafeSecureStorage();
    await storage.delete(key: 'factory_id');
    _factoryId = null;

    // إيقاف القنوات
    unawaited(SyncService.instance.dispose());

    // تحديث قاعدة البيانات لمسح factory_id من حساب المستخدم
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user != null) {
        await _supabaseClient
            .from('profiles')
            .update({'factory_id': null}).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error clearing factory_id from profiles: $e');
    }

    notifyListeners();
  }
}
