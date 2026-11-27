import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:smart_sheet/globals.dart';
import 'package:smart_sheet/screens/auth_screen.dart';
import 'package:smart_sheet/screens/client_items_screen.dart';
import 'package:smart_sheet/screens/gatekeeper_screen.dart';
import 'package:smart_sheet/screens/production_report_screen.dart';
import 'package:smart_sheet/screens/saved_sizes_screen.dart';
import 'package:smart_sheet/screens/staple_production_reports_screen.dart';
import 'package:smart_sheet/utils/route_observer.dart';

/// خدمة التوجيه المركزي عند الضغط على الإشعارات (Android & Windows)
class NotificationNavigationService {
  NotificationNavigationService._();

  /// المفتاح العام المرتبط بـ MaterialApp
  static GlobalKey<NavigatorState> get navigatorKey => appNavigatorKey;

  static bool _isAppReady = false;
  static Map<String, dynamic>? _pendingData;

  /// يُستدعى فور اكتمال التهيئة وفتح الشاشة الرئيسية (HomeScreen)
  /// لتنفيذ أي توجيه مؤجل من إشعار فتح التطبيق من حالة الإغلاق التام.
  static void markAppReady() {
    _isAppReady = true;
    final pending = _pendingData;
    if (pending != null) {
      _pendingData = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNavigation(pending);
      });
    }
  }

  /// تحليل Payload نصي (JSON) وتوجيه المستخدم
  static void handleJsonPayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        handleNavigation(decoded);
      } else if (decoded is Map) {
        handleNavigation(Map<String, dynamic>.from(decoded));
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationNavigationService] JSON decode error: $e');
    }
  }

  /// التوجيه المركزي بناءً على بيانات الإشعار
  static void handleNavigation(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;

    final nav = navigatorKey.currentState;
    final currentRoute = currentRouteNotifier.value;

    // إذا لم تكتمل تهيئة التطبيق أو كان المستخدم على شاشة البوابة/تسجيل الدخول،
    // نؤجل التوجيه لحين الوصول إلى الشاشة الرئيسية.
    if (!_isAppReady ||
        nav == null ||
        currentRoute == '/' ||
        currentRoute == GatekeeperScreen.routeName ||
        currentRoute == AuthScreen.routeName) {
      _pendingData = Map<String, dynamic>.from(data);
      debugPrint(
          '⏳ [NotificationNavigationService] تم تأجيل التوجيه لحين جاهزية التطبيق: $data');
      return;
    }

    final tableName = data['table_name']?.toString().trim() ?? '';
    final eventType =
        (data['event_type']?.toString().trim() ?? '').toUpperCase();
    final clientName =
        (data['client_name'] ?? data['clientName'] ?? data['customer_name'])
                ?.toString()
                .trim() ??
            '';
    final productName = (data['product_name'] ??
                data['productName'] ??
                data['item_name'] ??
                data['product'])
            ?.toString()
            .trim() ??
        '';
    final department = data['department']?.toString().trim() ?? '';
    final syncId = (data['sync_id'] ?? data['id'])?.toString().trim() ?? '';
    final isClientRecord = data['is_client_record'] == true ||
        data['is_client_record']?.toString().trim().toLowerCase() == 'true' ||
        data['isClientRecord'] == true ||
        data['isClientRecord']?.toString().trim().toLowerCase() == 'true';

    debugPrint(
      '🧭 [NotificationNavigationService] توجيه: table=$tableName, '
      'event=$eventType, isClient=$isClientRecord, client=$clientName, '
      'product=$productName, dept=$department, syncId=$syncId',
    );

    // ─── 1. جدول العملاء والأصناف (customers) ────────────────────────
    if (tableName == 'customers') {
      _handleCustomersNavigation(
        nav: nav,
        eventType: eventType,
        isClientRecord: isClientRecord,
        clientName: clientName,
        productName: productName,
        syncId: syncId,
      );
      return;
    }

    // ─── 2. جلسات التشغيل وتقارير الإنتاج ──────────────────────────
    if (tableName == 'live_sessions' ||
        tableName.endsWith('production_reports')) {
      _handleProductionNavigation(
        nav: nav,
        tableName: tableName,
        department: department,
      );
      return;
    }

    // ─── Fallback للإشعارات المحلية القديمة التي تحتوي على clientName فقط ───
    if (tableName.isEmpty && clientName.isNotEmpty) {
      _openClientFromSavedSizes(
        nav: nav,
        clientName: clientName,
      );
    }
  }

  static void _handleCustomersNavigation({
    required NavigatorState nav,
    required String eventType,
    required bool isClientRecord,
    required String clientName,
    required String productName,
    required String syncId,
  }) {
    final isDelete = eventType == 'DELETE';

    // حذف عميل → فتح صفحة سجل العملاء فقط
    if (isClientRecord && isDelete) {
      nav.popUntil((route) => route.isFirst);
      nav.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/saved_sizes'),
          builder: (_) => const SavedSizesScreen(),
        ),
      );
      return;
    }

    // حذف صنف → فتح صفحة العميل صاحب الصنف المحذوف
    if (!isClientRecord && isDelete) {
      nav.popUntil((route) => route.isFirst);
      if (clientName.isNotEmpty) {
        nav.push(
          MaterialPageRoute(
            settings: RouteSettings(name: 'ClientItemsScreen_$clientName'),
            builder: (_) => ClientItemsScreen(clientName: clientName),
          ),
        );
      } else {
        nav.push(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/saved_sizes'),
            builder: (_) => const SavedSizesScreen(),
          ),
        );
      }
      return;
    }

    // إضافة أو تعديل عميل → فتح سجل العملاء ثم دفع صفحة العميل
    if (isClientRecord) {
      _openClientFromSavedSizes(
        nav: nav,
        clientName: clientName,
      );
      return;
    }

    // إضافة أو تعديل صنف → فتح سجل العملاء ثم صفحة العميل مع تمرير الصنف/sync_id لتمييزه
    _openClientFromSavedSizes(
      nav: nav,
      clientName: clientName,
      highlightSyncId: syncId.isNotEmpty ? syncId : null,
      highlightProductName: productName.isNotEmpty ? productName : null,
    );
  }

  static void _openClientFromSavedSizes({
    required NavigatorState nav,
    required String clientName,
    String? highlightSyncId,
    String? highlightProductName,
  }) {
    nav.popUntil((route) => route.isFirst);
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/saved_sizes'),
        builder: (_) => const SavedSizesScreen(),
      ),
    );
    if (clientName.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          settings: RouteSettings(name: 'ClientItemsScreen_$clientName'),
          builder: (_) => ClientItemsScreen(
            clientName: clientName,
            highlightSyncId: highlightSyncId,
            highlightProductName: highlightProductName,
          ),
        ),
      );
    }
  }

  static void _handleProductionNavigation({
    required NavigatorState nav,
    required String tableName,
    required String department,
  }) {
    final dept = _resolveDepartment(tableName: tableName, department: department);
    nav.popUntil((route) => route.isFirst);

    if (dept == 'staple') {
      nav.push(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/staple_production_reports'),
          builder: (_) => const StapleProductionReportsScreen(),
        ),
      );
      return;
    }

    final Widget targetScreen;
    if (dept == 'production_line') {
      targetScreen =
          const FlexoProductionReportScreen(department: 'production_line');
    } else if (dept == 'crushing') {
      targetScreen = const FlexoProductionReportScreen(department: 'crushing');
    } else {
      targetScreen = const FlexoProductionReportScreen(department: 'flexo');
    }

    nav.push(
      MaterialPageRoute(
        settings: RouteSettings(name: '/production_reports_$dept'),
        builder: (_) => targetScreen,
      ),
    );
  }

  static String _resolveDepartment({
    required String tableName,
    required String department,
  }) {
    final normalizedDept = department.trim().toLowerCase();
    final normalizedTable = tableName.trim().toLowerCase();

    if (normalizedDept == 'staple' ||
        normalizedDept == 'staples' ||
        normalizedTable.startsWith('staple')) {
      return 'staple';
    }
    if (normalizedDept == 'die_cutting' ||
        normalizedDept == 'crushing' ||
        normalizedTable.startsWith('die_cutting')) {
      return 'crushing';
    }
    if (normalizedDept == 'line' ||
        normalizedDept == 'production_line' ||
        normalizedTable.startsWith('line')) {
      return 'production_line';
    }
    return 'flexo';
  }
}
