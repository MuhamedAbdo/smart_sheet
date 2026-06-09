// lib/services/sync/customer_sync.dart
//
// Mixin: CustomerSync on SyncServiceBase
// المسؤولية: مزامنة جدولَي customers + customer_products
//   • القناتان: _customersChannel + _customerProductsChannel
//   • الـ Callbacks: _onCustomerChange + _onCustomerProductChange
//   • المزامنة المبدئية: _initCustomers + _initCustomerProducts
//   • الـ Helpers: _customerToHive + _mergeLocalCustomerFields
//                  _deleteFromBoxByAnyId + _deleteFromBoxByClientName
//
// ⚠️ لا تعدّل هذا الملف إلا عند تغيير منطق العملاء أو أصنافهم حصراً.
//
// 🔑 part of sync_service.dart — نفس الـ library → يرى جميع الـ private.
//    mixin on SyncServiceBase → يرى _supabase + _scheduleReconnect + _reconnectAttempts.

part of '../sync_service.dart';

mixin CustomerSync on SyncServiceBase {
  // ─── حقول القنوات ────────────────────────────────────────────────
  RealtimeChannel? _customersChannel;
  RealtimeChannel? _customerProductsChannel;

  // ==============================================================
  // Initial Sync
  // ==============================================================

  /// المزامنة المبدئية لجدول customers → Hive box: savedSheetSizes
  Future<void> _initCustomers(String factoryId) async {
    try {
      final res = await _supabase
          .from('customers')
          .select()
          .eq('factory_id', factoryId);

      final box = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');

      for (final r in res) {
        try {
          final hasSheetDetails = r['sheet_details'] != null;
          final hiveRecord = _customerToHive(r);
          final syncId = r['sync_id'] ?? r['id'];
          if (syncId == null) continue;
          hiveRecord['sync_id'] = syncId;

          dynamic existingKey = syncId;
          for (var i = 0; i < box.length; i++) {
            final item = box.getAt(i);
            if (item is Map && item['sync_id'] == syncId) {
              existingKey = box.keyAt(i);
              _mergeLocalCustomerFields(hiveRecord, item, hasSheetDetails);
              break;
            }
          }
          await box.put(existingKey, hiveRecord);
        } catch (e) {
          debugPrint('❌ CustomerSync._initCustomers record parsing error: $e');
        }
      }
      debugPrint('✅ CustomerSync: تم استرجاع ${res.length} customers.');
    } catch (e) {
      debugPrint('❌ CustomerSync._initCustomers: $e');
    }
  }

  /// المزامنة المبدئية لجدول customer_products → Hive box: finished_products
  Future<void> _initCustomerProducts(String factoryId) async {
    try {
      final res = await _supabase
          .from('customers')
          .select()
          .eq('factory_id', factoryId);

      final box = Hive.isBoxOpen('finished_products')
          ? Hive.box<FinishedProduct>('finished_products')
          : await Hive.openBox<FinishedProduct>('finished_products');

      await box.clear();
      for (final r in res) {
        final product = FinishedProduct.fromJson(r);
        await box.put(product.id, product);
      }
      debugPrint('✅ CustomerSync: تم استرجاع ${res.length} customer_products.');
    } catch (e) {
      debugPrint('❌ خطأ صامت في المزامنة: $e');
    }
  }

  // ==============================================================
  // Channel Setup & Teardown
  // ==============================================================

  /// إعداد قناتَي Real-time الخاصتين بالعملاء وأصنافهم
  void _setupCustomerChannels(String factoryId) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'factory_id',
      value: factoryId,
    );

    // ─── customers ─────────────────────────────────────────────────
    _customersChannel = _supabase
        .channel('rt_customers_${factoryId}_v2')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [customers] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onCustomerChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → customers (factory: $factoryId)');
            _reconnectAttempts['customer_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customers — جدولة إعادة الاتصال...');
            _scheduleReconnect('customer_channels', () async {
              await _tearDownCustomerChannels();
              _setupCustomerChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customers: $error');
            _scheduleReconnect('customer_channels', () async {
              await _tearDownCustomerChannels();
              _setupCustomerChannels(factoryId);
            });
          } else {
            debugPrint('📡 customers: $status ${error ?? ""}');
          }
        });

    // ─── customer_products ─────────────────────────────────────────
    _customerProductsChannel = _supabase
        .channel('rt_customer_products_${factoryId}_v1')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          filter: filter,
          callback: (payload) {
            debugPrint(
              '📥 [customer_products] event=${payload.eventType} '
              'new=${payload.newRecord} old=${payload.oldRecord}',
            );
            _onCustomerProductChange(payload, factoryId);
          },
        )
        .subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            debugPrint('✅ SUBSCRIBED → customer_products (factory: $factoryId)');
            _reconnectAttempts['customer_channels'] = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customer_products — جدولة إعادة الاتصال...');
            _scheduleReconnect('customer_channels', () async {
              await _tearDownCustomerChannels();
              _setupCustomerChannels(factoryId);
            });
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customer_products: $error');
            _scheduleReconnect('customer_channels', () async {
              await _tearDownCustomerChannels();
              _setupCustomerChannels(factoryId);
            });
          } else {
            debugPrint('📡 customer_products: $status ${error ?? ""}');
          }
        });
  }

  /// إغلاق قناتَي العملاء وتحريرهما
  Future<void> _tearDownCustomerChannels() async {
    if (_customersChannel != null) {
      await _supabase.removeChannel(_customersChannel!);
      _customersChannel = null;
    }
    if (_customerProductsChannel != null) {
      await _supabase.removeChannel(_customerProductsChannel!);
      _customerProductsChannel = null;
    }
  }

  // ==============================================================
  // Real-time Callbacks
  // ==============================================================

  // ─── customers → savedSheetSizes ────────────────────────────────
  void _onCustomerChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;

      // ⚠️ عند DELETE: oldRecord يكون فارغاً إذا لم يكن REPLICA IDENTITY FULL مفعّلاً.
      // نستخدم newRecord كـ fallback لاستخراج المعرّف.
      Map<String, dynamic> record;
      if (isDelete) {
        record = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        record = payload.newRecord;
      }

      if (record.isEmpty) {
        debugPrint(
          '⚠️ [customers] DELETE payload فارغ تماماً! '
          'تأكد من تفعيل: ALTER TABLE customers REPLICA IDENTITY FULL;',
        );
        return;
      }

      final recordFactoryId = record['factory_id']?.toString();
      if (!isDelete && recordFactoryId != myFactoryId) {
        debugPrint('⏭️ [customers] تجاهل: factory مختلف ($recordFactoryId)');
        return;
      }

      if (!Hive.isBoxOpen('savedSheetSizes')) {
        debugPrint('⚠️ [customers] Box savedSheetSizes مغلق!');
        return;
      }
      final box = Hive.box('savedSheetSizes');

      if (isDelete) {
        final clientName = record['client_name']?.toString() ?? '';
        final syncId   = record['sync_id']?.toString();
        final remoteId = record['id']?.toString();
        debugPrint('🗑️ [customers] وصل طلب حذف: $clientName (sync_id=$syncId, id=$remoteId)');
        final deleted = await _deleteFromBoxByAnyId(box, syncId: syncId, remoteId: remoteId);
        if (!deleted) {
          await _deleteFromBoxByClientName(box, clientName);
        }
        debugPrint('🗑️ [customers] اكتمل الحذف: $clientName');
      } else {
        final clientName = record['client_name']?.toString() ?? '';
        final rawSyncId = record['sync_id']?.toString() ?? record['id']?.toString();
        final syncId = rawSyncId ??
            '${clientName}_${myFactoryId}_${record['product_code'] ?? ''}';

        debugPrint('🌟 وصلت بيانات جديدة: $clientName (factory: $recordFactoryId) key=$syncId');

        if (!isDelete && payload.eventType == PostgresChangeEvent.insert) {
          final isClientRecord = record['is_client_record'] == true || record['is_client_record'] == 'true';
          final title = isClientRecord ? "➕ عميل جديد" : "📦 صنف جديد مضاف";
          final body = isClientRecord 
              ? "تم تسجيل العميل: $clientName" 
              : "تم إضافة صنف: ${record['product_name'] ?? ''} للعميل: $clientName";
          
          SyncService.instance.showLocalNotification(title, body, clientName);

          UIUtils.showTopOverlay(
            title: title,
            message: body,
            onTap: () async {
              bool clientExists = false;
              if (Hive.isBoxOpen('savedSheetSizes')) {
                final box = Hive.box('savedSheetSizes');
                for (var i = 0; i < box.length; i++) {
                  final item = box.getAt(i);
                  if (item is Map && (item['clientName']?.toString().trim() ?? '') == clientName.trim()) {
                    clientExists = true;
                    break;
                  }
                }
              }

              if (clientExists) {
                final context = scaffoldMessengerKey.currentContext;
                if (context != null) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final nav = authService.navigatorKey.currentState;
                  if (nav != null) {
                    bool isAlreadyTop = false;
                    nav.popUntil((route) {
                      if (route.isCurrent && route.settings.name == 'ClientItemsScreen_$clientName') {
                        isAlreadyTop = true;
                      }
                      return true; // Stop immediately, don't pop anything
                    });

                    if (!isAlreadyTop) {
                      nav.push(
                        MaterialPageRoute(
                          settings: RouteSettings(name: 'ClientItemsScreen_$clientName'),
                          builder: (_) => ClientItemsScreen(clientName: clientName),
                        ),
                      );
                    }
                  }
                }
              } else {
                debugPrint('⚠️ العميل غير موجود محلياً (Tap): $clientName');
              }
            },
          );
        }

        try {
          final hasSheetDetails = record['sheet_details'] != null;
          final hiveRecord = _customerToHive(record);
          hiveRecord['sync_id'] = syncId;

          dynamic existingKey = syncId;
          for (var i = 0; i < box.length; i++) {
            final item = box.getAt(i);
            if (item is Map && item['sync_id'] == syncId) {
              existingKey = box.keyAt(i);
              _mergeLocalCustomerFields(hiveRecord, item, hasSheetDetails);
              break;
            }
          }

          if (!isDelete && payload.eventType == PostgresChangeEvent.insert && box.containsKey(existingKey)) {
            debugPrint('⏭️ [customers] السجل موجود مسبقاً، سيتم منع التكرار: $existingKey');
            return;
          }

          await box.put(existingKey, hiveRecord);
          debugPrint('✅ [customers] تم حفظ محلياً: $clientName');
        } catch (e) {
          debugPrint('❌ CustomerSync._onCustomerChange parsing error: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ _onCustomerChange: $e');
    }
  }

  // ─── customer_products → finished_products ──────────────────────
  void _onCustomerProductChange(
    PostgresChangePayload payload,
    String myFactoryId,
  ) async {
    try {
      final isDelete = payload.eventType == PostgresChangeEvent.delete;

      // ⚠️ نفس fallback pattern للتعامل مع REPLICA IDENTITY FULL المعطّل
      Map<String, dynamic> record;
      if (isDelete) {
        record = payload.oldRecord.isNotEmpty
            ? payload.oldRecord
            : payload.newRecord;
      } else {
        record = payload.newRecord;
      }
      if (record.isEmpty) {
        debugPrint(
          '⚠️ [customer_products] DELETE payload فارغ! '
          'تأكد من: ALTER TABLE customer_products REPLICA IDENTITY FULL;',
        );
        return;
      }

      if (!Hive.isBoxOpen('finished_products')) {
        await Hive.openBox<FinishedProduct>('finished_products');
      }
      final box = Hive.box<FinishedProduct>('finished_products');
      final stableKey = record['sync_id']?.toString() ?? record['id']?.toString();
      if (stableKey == null) return;

      if (isDelete) {
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }
        if (existingKey != null && box.containsKey(existingKey)) {
          await box.delete(existingKey);
        } else if (box.containsKey(stableKey)) {
          await box.delete(stableKey);
        }
        debugPrint('🗑️ [customer_products] حُذف محلياً: $stableKey');
      } else {
        final product = FinishedProduct.fromJson(record);
        dynamic existingKey = stableKey;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && item.id == stableKey) { existingKey = box.keyAt(i); break; }
        }

        if (!isDelete && payload.eventType == PostgresChangeEvent.insert && box.containsKey(existingKey)) {
          debugPrint('⏭️ [customer_products] السجل موجود مسبقاً، سيتم منع التكرار: $existingKey');
          return;
        }

        await box.put(existingKey, product);
        debugPrint('✅ [customer_products] تم حفظ/تحديث: $stableKey');

        if (!isDelete && payload.eventType == PostgresChangeEvent.insert) {
          final clientName = record['client_name']?.toString() ?? '';
          const title = "📦 صنف جديد مضاف";
          final body = "تم إضافة صنف: ${record['product_name'] ?? ''} للعميل: $clientName";
          SyncService.instance.showLocalNotification(title, body, clientName);

          UIUtils.showTopOverlay(
            title: title,
            message: body,
            onTap: () async {
              bool clientExists = false;
              if (Hive.isBoxOpen('savedSheetSizes')) {
                final box = Hive.box('savedSheetSizes');
                for (var i = 0; i < box.length; i++) {
                  final item = box.getAt(i);
                  if (item is Map && (item['clientName']?.toString().trim() ?? '') == clientName.trim()) {
                    clientExists = true;
                    break;
                  }
                }
              }

              if (clientExists) {
                final context = scaffoldMessengerKey.currentContext;
                if (context != null) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final nav = authService.navigatorKey.currentState;
                  if (nav != null) {
                    bool isAlreadyTop = false;
                    nav.popUntil((route) {
                      if (route.isCurrent && route.settings.name == 'ClientItemsScreen_$clientName') {
                        isAlreadyTop = true;
                      }
                      return true; // Stop immediately, don't pop anything
                    });

                    if (!isAlreadyTop) {
                      nav.push(
                        MaterialPageRoute(
                          settings: RouteSettings(name: 'ClientItemsScreen_$clientName'),
                          builder: (_) => ClientItemsScreen(clientName: clientName),
                        ),
                      );
                    }
                  }
                }
              } else {
                debugPrint('⚠️ العميل غير موجود محلياً (Tap): $clientName');
              }
            },
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _onCustomerProductChange: $e');
    }
  }

  // ==============================================================
  // Helpers — خاصة بالعملاء
  // ==============================================================

  Map<String, dynamic> _customerToHive(Map<String, dynamic> r) {
    try {
      final sheetDetails = r['sheet_details'] as Map<String, dynamic>? ?? {};
      return {
        'id':             r['id'],
        'sync_id':        r['sync_id'],
        'processType':    r['process_type']?.toString() ?? 'تفصيل',
        'clientName':     r['client_name']?.toString() ?? '',
        'productName':    r['product_name']?.toString() ?? '',
        'productCode':    r['product_code']?.toString() ?? '',
        'length':         r['length']?.toString() ?? '',
        'width':          r['width']?.toString() ?? '',
        'height':         r['height']?.toString() ?? '',
        'isSheet':        r['is_sheet'] ?? false,
        'date':           r['date']?.toString() ?? DateTime.now().toIso8601String(),
        'factory_id':     r['factory_id'],
        'imagePaths':     r['image_paths'] ?? [],
        'isClientRecord': r['is_client_record'] ?? false,
        'isOverFlap': sheetDetails['isOverFlap'] ?? false,
        'isFlap': sheetDetails['isFlap'] ?? true,
        'isOneFlap': sheetDetails['isOneFlap'] ?? false,
        'isTwoFlap': sheetDetails['isTwoFlap'] ?? true,
        'addTwoMm': sheetDetails['addTwoMm'] ?? false,
        'isFullSize': sheetDetails['isFullSize'] ?? true,
        'isQuarterSize': sheetDetails['isQuarterSize'] ?? false,
        'isQuarterWidth': sheetDetails['isQuarterWidth'] ?? true,
        'sheetLengthResult': sheetDetails['sheetLengthResult']?.toString() ?? '',
        'sheetWidthResult': sheetDetails['sheetWidthResult']?.toString() ?? '',
        'productionWidth1': sheetDetails['productionWidth1']?.toString() ?? '',
        'productionHeight': sheetDetails['productionHeight']?.toString() ?? '',
        'productionWidth2': sheetDetails['productionWidth2']?.toString() ?? '',
        'sheetLengthManual': sheetDetails['sheetLengthManual']?.toString() ?? '',
        'sheetWidthManual': sheetDetails['sheetWidthManual']?.toString() ?? '',
        'cuttingType': sheetDetails['cuttingType']?.toString() ?? 'دوبل',
      };
    } catch (e) {
      debugPrint('❌ CustomerSync._customerToHive error: $e');
      return {
        'id': r['id'],
        'sync_id': r['sync_id'],
        'clientName': r['client_name']?.toString() ?? 'خطأ في البيانات',
      };
    }
  }

  void _mergeLocalCustomerFields(
    Map<String, dynamic> newRecord,
    Map<dynamic, dynamic> existingRecord,
    bool hasSheetDetails,
  ) {
    if (hasSheetDetails) return;
    const localFields = [
      'isOverFlap', 'isFlap', 'isOneFlap', 'isTwoFlap', 'addTwoMm',
      'isFullSize', 'isQuarterSize', 'isQuarterWidth',
      'sheetLengthResult', 'sheetWidthResult',
      'productionWidth1', 'productionHeight', 'productionWidth2',
      'sheetLengthManual', 'sheetWidthManual', 'cuttingType',
    ];
    for (var field in localFields) {
      if (existingRecord.containsKey(field)) {
        newRecord[field] = existingRecord[field];
      }
    }
  }

  /// دالة الحذف الموحدة بثلاث طرق (sync_id → id → بحث خطي)
  Future<bool> _deleteFromBoxByAnyId(
    Box box, {
    String? syncId,
    String? remoteId,
  }) async {
    if (syncId != null && box.containsKey(syncId)) {
      await box.delete(syncId);
      debugPrint('🗑️ [box] ✅ حُذف بالمفتاح المباشر (sync_id): $syncId');
      return true;
    }
    if (remoteId != null && box.containsKey(remoteId)) {
      await box.delete(remoteId);
      debugPrint('🗑️ [box] ✅ حُذف بالمفتاح المباشر (id): $remoteId');
      return true;
    }
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is! Map) continue;
      final vSyncId = v['sync_id']?.toString();
      final vId     = v['id']?.toString();
      final matched = (syncId  != null && vSyncId == syncId)  ||
                      (remoteId != null && vSyncId == remoteId) ||
                      (remoteId != null && vId     == remoteId) ||
                      (syncId  != null && vId     == syncId);
      if (matched) {
        await box.delete(box.keyAt(i));
        debugPrint('🗑️ [box] ✅ حُذف بالبحث الخطي (sync_id=$vSyncId | id=$vId)');
        return true;
      }
    }
    debugPrint('⚠️ [box] ❌ لم يُعثر على السجل (sync_id=$syncId | id=$remoteId)');
    return false;
  }

  Future<void> _deleteFromBoxByClientName(Box box, String clientName) async {
    final keysToDelete = [];
    for (int i = 0; i < box.length; i++) {
      final v = box.getAt(i);
      if (v is Map &&
          (v['clientName']?.toString().trim() ?? '') == clientName.trim()) {
        keysToDelete.add(box.keyAt(i));
      }
    }
    for (final k in keysToDelete) { await box.delete(k); }
  }
}
