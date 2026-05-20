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
        final hiveRecord = _customerToHive(r);
        final syncId = r['sync_id'] ?? r['id'];
        hiveRecord['sync_id'] = syncId;

        dynamic existingKey = syncId;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == syncId) {
            existingKey = box.keyAt(i);
            _mergeLocalCustomerFields(hiveRecord, item);
            break;
          }
        }
        await box.put(existingKey, hiveRecord);
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
          .from('customer_products')
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
      debugPrint('❌ CustomerSync._initCustomerProducts: $e');
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
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customers — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customers: $error');
            _scheduleReconnect();
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
          table: 'customer_products',
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
            _reconnectAttempts = 0;
          } else if (status == RealtimeSubscribeStatus.timedOut) {
            debugPrint('⏱️ TIMEOUT → customer_products — جدولة إعادة الاتصال...');
            _scheduleReconnect();
          } else if (status == RealtimeSubscribeStatus.channelError) {
            debugPrint('❌ CHANNEL ERROR → customer_products: $error');
            _scheduleReconnect();
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
      final record = isDelete ? payload.oldRecord : payload.newRecord;

      if (record.isEmpty) {
        debugPrint('⚠️ [customers] payload فارغ! تحقق من Replica Identity في Supabase.');
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

        final hiveRecord = _customerToHive(record);
        hiveRecord['sync_id'] = syncId;

        dynamic existingKey = syncId;
        for (var i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item is Map && item['sync_id'] == syncId) {
            existingKey = box.keyAt(i);
            _mergeLocalCustomerFields(hiveRecord, item);
            break;
          }
        }

        await box.put(existingKey, hiveRecord);
        debugPrint('✅ [customers] تم حفظ محلياً: $clientName');
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
      final record = isDelete ? payload.oldRecord : payload.newRecord;
      if (record.isEmpty) return;

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
        await box.put(existingKey, product);
        debugPrint('✅ [customer_products] تم حفظ/تحديث: $stableKey');
      }
    } catch (e) {
      debugPrint('❌ _onCustomerProductChange: $e');
    }
  }

  // ==============================================================
  // Helpers — خاصة بالعملاء
  // ==============================================================

  Map<String, dynamic> _customerToHive(Map<String, dynamic> r) {
    return {
      'id':             r['id'],
      'sync_id':        r['sync_id'],
      'processType':    r['process_type'] ?? 'تفصيل',
      'clientName':     r['client_name'] ?? '',
      'productName':    r['product_name'] ?? '',
      'productCode':    r['product_code'] ?? '',
      'length':         r['length']?.toString() ?? '',
      'width':          r['width']?.toString() ?? '',
      'height':         r['height']?.toString() ?? '',
      'isSheet':        r['is_sheet'] ?? false,
      'date':           r['date'] ?? DateTime.now().toIso8601String(),
      'factory_id':     r['factory_id'],
      'imagePaths':     r['image_paths'] ?? [],
      'isClientRecord': r['is_client_record'] ?? false,
    };
  }

  void _mergeLocalCustomerFields(
    Map<String, dynamic> newRecord,
    Map<dynamic, dynamic> existingRecord,
  ) {
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
