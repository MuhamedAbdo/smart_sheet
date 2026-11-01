import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:smart_sheet/services/sync_service.dart';
import 'package:smart_sheet/services/supabase_manager.dart';

/// كلاس يمثل الفرق بين قيمة قديمة وقيمة جديدة لحقل معين
class ItemFieldDiff {
  final String key;
  final String label;
  final String oldValue;
  final String newValue;
  final IconData icon;

  const ItemFieldDiff({
    required this.key,
    required this.label,
    required this.oldValue,
    required this.newValue,
    required this.icon,
  });
}

/// متحكم إدارة سجل التعديلات لأصناف العملاء (Edit History Controller)
/// يتولى مقارنة البيانات، استخراج الحقول النصية والرقمية، واستثناء الصور والمرفقات تماماً،
/// وحفظ وتحديث السجلات في Supabase و Hive (Offline-First).
class ItemHistoryController {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// أسماء الحقول النصية والرقمية التي يتم تتبعها فقط (استثناء تام للصور والمرفقات)
  static const List<String> trackedKeys = [
    'length',
    'width',
    'height',
    'productName',
    'productCode',
    'clientName',
    'processType',
    'isSheet',
    'formNumber',
    'numberOfBoxes',
    'cuttingType',
    'sheetLengthManual',
    'sheetWidthManual',
    'sheetLengthResult',
    'sheetWidthResult',
    'productionWidth1',
    'productionHeight',
    'productionWidth2',
    'isOverFlap',
    'isFlap',
    'isOneFlap',
    'isTwoFlap',
    'addTwoMm',
    'isFullSize',
    'isQuarterSize',
    'isQuarterWidth',
    'productState',
    'notes',
  ];

  /// مسميات الحقول باللغة العربية
  static const Map<String, String> fieldLabels = {
    'length': 'الطول',
    'width': 'العرض',
    'height': 'الارتفاع',
    'productName': 'اسم الصنف',
    'product_name': 'اسم الصنف',
    'productCode': 'كود الصنف',
    'product_code': 'كود الصنف',
    'clientName': 'اسم العميل',
    'client_name': 'اسم العميل',
    'processType': 'نوع التشغيل',
    'process_type': 'نوع التشغيل',
    'isSheet': 'شيت فقط',
    'is_sheet': 'شيت فقط',
    'formNumber': 'رقم الفورمة',
    'form_number': 'رقم الفورمة',
    'numberOfBoxes': 'عدد العلب',
    'number_of_boxes': 'عدد العلب',
    'cuttingType': 'نوع التكسير',
    'sheetLengthManual': 'طول الشيت (يدوي)',
    'sheetWidthManual': 'عرض الشيت (يدوي)',
    'sheetLengthResult': 'طول الشيت المحسوب',
    'sheetWidthResult': 'عرض الشيت المحسوب',
    'productionWidth1': 'عرض الإنتاج 1',
    'productionHeight': 'ارتفاع الإنتاج',
    'productionWidth2': 'عرض الإنتاج 2',
    'isOverFlap': 'أوفر فلاب',
    'isFlap': 'شفة واحدة',
    'isOneFlap': 'فلاب مفرد',
    'isTwoFlap': 'فلاب مزدوج',
    'addTwoMm': 'إضافة 2 مم',
    'isFullSize': 'مقاس كامل',
    'isQuarterSize': 'ربع المقاس',
    'isQuarterWidth': 'ربع العرض',
    'productState': 'حالة المنتج',
    'product_state': 'حالة المنتج',
    'notes': 'الملاحظات',
  };

  /// أيقونات معبرة لكل حقل
  static const Map<String, IconData> fieldIcons = {
    'length': Icons.straighten_rounded,
    'width': Icons.square_foot_rounded,
    'height': Icons.height_rounded,
    'productName': Icons.inventory_2_outlined,
    'product_name': Icons.inventory_2_outlined,
    'productCode': Icons.qr_code_rounded,
    'product_code': Icons.qr_code_rounded,
    'clientName': Icons.person_outline_rounded,
    'client_name': Icons.person_outline_rounded,
    'processType': Icons.precision_manufacturing_outlined,
    'process_type': Icons.precision_manufacturing_outlined,
    'isSheet': Icons.layers_outlined,
    'is_sheet': Icons.layers_outlined,
    'formNumber': Icons.tag_rounded,
    'form_number': Icons.tag_rounded,
    'numberOfBoxes': Icons.grid_view_rounded,
    'number_of_boxes': Icons.grid_view_rounded,
    'cuttingType': Icons.content_cut_rounded,
    'sheetLengthManual': Icons.straighten_rounded,
    'sheetWidthManual': Icons.square_foot_rounded,
    'sheetLengthResult': Icons.calculate_outlined,
    'sheetWidthResult': Icons.calculate_outlined,
    'productState': Icons.style_outlined,
    'product_state': Icons.style_outlined,
    'notes': Icons.notes_rounded,
  };

  /// استخراج كائن نظيف يحتوي فقط على الحقول النصية والرقمية (مع استثناء تام لمصفوفات الصور)
  static Map<String, dynamic> extractCleanTextAndNumericData(Map data) {
    final clean = <String, dynamic>{};

    for (final key in trackedKeys) {
      dynamic value = data[key];

      // فحص المفاتيح البديلة بصيغة snake_case إن لم تكن متوفرة
      if (value == null) {
        if (key == 'productName') value = data['product_name'];
        if (key == 'productCode') value = data['product_code'];
        if (key == 'clientName') value = data['client_name'];
        if (key == 'processType') value = data['process_type'] ?? data['operation_type'];
        if (key == 'isSheet') value = data['is_sheet'];
        if (key == 'formNumber') value = data['form_number'];
        if (key == 'numberOfBoxes') value = data['number_of_boxes'];
        if (key == 'productState') value = data['product_state'] ?? data['productState'];
        if (key == 'notes') value = data['notes'];
      }

      if (value != null) {
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) clean[key] = trimmed;
        } else if (value is num || value is bool) {
          clean[key] = value;
        }
      }
    }

    final op = getOperationType(data, data);
    clean['operation_type'] = op;
    clean['processType'] = op;

    return clean;
  }

  /// تحديد نوع العملية (تفصيل أو تكسير) من الكائن الجديد أو القديم
  static String getOperationType(Map oldData, Map newData) {
    final val = newData['operation_type'] ??
        newData['operationType'] ??
        newData['processType'] ??
        newData['process_type'] ??
        oldData['operation_type'] ??
        oldData['operationType'] ??
        oldData['processType'] ??
        oldData['process_type'] ??
        'تفصيل';
    final str = val.toString().trim();
    return str.contains('تكسير') ? 'تكسير' : 'تفصيل';
  }

  /// التحقق مما إذا كانت القيمة فارغة أو تعادل صفراً
  static bool isEffectivelyEmptyOrZero(dynamic value) {
    if (value == null) return true;
    String str = value.toString().trim();
    if (str.isEmpty || str == 'null' || str == '—') return true;

    // تنظيف البادئات والوحدات
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    str = str.replaceAll('٫', '.').replaceAll('،', '.');
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    str = str.replaceAll(
      RegExp(
        r'^(?:📏|📐)?\s*(?:طول|عرض|ارتفاع|فلاب)?\s*(?:الشيت)?\s*[:\-]?\s*',
        caseSensitive: false,
      ),
      '',
    );
    str = str.replaceAll(RegExp(r'\s*(سم|cm|علبة)', caseSensitive: false), '').trim();

    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(str);
    if (match != null) {
      final numVal = double.tryParse(match.group(0)!);
      if (numVal != null && numVal == 0) return true;
      return false;
    }

    return str.isEmpty;
  }

  /// حساب تسمية نوع الشريحة لعمليات التفصيل (ص، 1/2 ص، 1/4 ص)
  static String getSliceTypeLabel(Map data) {
    final isFull = data['isFullSize'] == true;
    final isQuarter = data['isQuarterSize'] == true;
    final isQuarterWidth = data['isQuarterWidth'] ?? true;

    if (isFull) {
      return 'ص';
    } else if (isQuarter) {
      return isQuarterWidth ? '1/4 ص (عرض)' : '1/4 ص (طول)';
    } else if (data.containsKey('isFullSize') || data.containsKey('isQuarterSize')) {
      return '1/2 ص';
    }
    return '';
  }

  /// فحص وجود أي تغيير حقيقي مع مراعاة نوع العملية واستبعاد الحقول الفارغة
  static bool hasChanges(Map oldMap, Map newMap) {
    return computeDifferences(
      Map<String, dynamic>.from(oldMap),
      Map<String, dynamic>.from(newMap),
    ).isNotEmpty;
  }

  /// حساب الفروقات التفصيلية مع تكييف المسميات والحقول بناءً على نوع العملية
  static List<ItemFieldDiff> computeDifferences(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    final cleanOld = extractCleanTextAndNumericData(oldData);
    final cleanNew = extractCleanTextAndNumericData(newData);

    final opType = getOperationType(cleanOld, cleanNew);
    final isDieCutting = opType == 'تكسير';
    final isDetailing = !isDieCutting;

    final diffs = <ItemFieldDiff>[];

    // 1. خيارات الشريحة الخاصة بالتفصيل (ص، 1/2 ص، 1/4 ص)
    if (isDetailing) {
      final oldSlice = getSliceTypeLabel(oldData);
      final newSlice = getSliceTypeLabel(newData);
      if (oldSlice != newSlice && (oldSlice.isNotEmpty || newSlice.isNotEmpty)) {
        diffs.add(
          ItemFieldDiff(
            key: 'sliceType',
            label: 'نوع الشريحة',
            oldValue: oldSlice.isNotEmpty ? oldSlice : '—',
            newValue: newSlice.isNotEmpty ? newSlice : '—',
            icon: Icons.auto_awesome_mosaic_rounded,
          ),
        );
      }
    }

    // 2. الحقول المستبعدة تماماً بناءً على نوع العملية الحالي
    final excludedKeys = isDetailing
        ? {
            // في التفصيل: إخفاء تام لعدد العلب ورقم الفورمة ونوع التضليع ومقاس الشيت اليدوي
            'numberOfBoxes',
            'number_of_boxes',
            'formNumber',
            'form_number',
            'cuttingType',
            'sheetLengthManual',
            'sheetWidthManual',
            // حجب البوليانات الفردية للشريحة لأنها تظهر كحقل مجمع (نوع الشريحة)
            'isFullSize',
            'isQuarterSize',
            'isQuarterWidth',
          }
        : {
            // في التكسير: إخفاء حقول الفلاب وتفاصيل تفصيل الكرتون
            'productionWidth1',
            'productionWidth2',
            'productionHeight',
            'sheetLengthResult',
            'sheetWidthResult',
            'isOverFlap',
            'isFlap',
            'isOneFlap',
            'isTwoFlap',
            'addTwoMm',
            'isFullSize',
            'isQuarterSize',
            'isQuarterWidth',
          };

    final allKeys = {...cleanOld.keys, ...cleanNew.keys};

    for (final key in allKeys) {
      if (excludedKeys.contains(key)) continue;

      final oldValRaw = cleanOld[key];
      final newValRaw = cleanNew[key];

      // تجاهل إذا كانت القيمة القديمة والجديدة فارغة أو تعادل صفراً
      final oldEmptyOrZero = isEffectivelyEmptyOrZero(oldValRaw);
      final newEmptyOrZero = isEffectivelyEmptyOrZero(newValRaw);

      if (oldEmptyOrZero && newEmptyOrZero) {
        continue;
      }

      final oldFormatted = _formatFieldValue(key, oldValRaw, isDetailing);
      final newFormatted = _formatFieldValue(key, newValRaw, isDetailing);

      if (oldFormatted != newFormatted) {
        final label = _getFieldLabel(key, isDetailing);
        final icon = _getFieldIcon(key, isDetailing);

        diffs.add(
          ItemFieldDiff(
            key: key,
            label: label,
            oldValue: oldFormatted,
            newValue: newFormatted,
            icon: icon,
          ),
        );
      }
    }

    return diffs;
  }

  /// تحديد المسمى العربي الملائم للحقل حسب نوع العملية
  static String _getFieldLabel(String key, bool isDetailing) {
    if (isDetailing) {
      if (key == 'productionWidth1' || key == 'production_width_1') return 'فلاب 1';
      if (key == 'productionWidth2' || key == 'production_width_2') return 'فلاب 2';
      if (key == 'productionHeight' || key == 'production_height') return 'ارتفاع التفصيل';
      if (key == 'isOverFlap') return 'أوفر فلاب';
      if (key == 'addTwoMm') return 'إضافة 2 ملم للفلاب';
      if (key == 'isFlap') return 'فلاب';
      if (key == 'isOneFlap') return '1 فلاب';
      if (key == 'isTwoFlap') return '2 فلاب';
    } else {
      // في عمليات التكسير
      if (key == 'cuttingType') return 'نوع التضليع / الشريحة';
      if (key == 'numberOfBoxes' || key == 'number_of_boxes') return 'عدد العلب';
      if (key == 'formNumber' || key == 'form_number') return 'رقم الفورمة';
      if (key == 'sheetLengthManual') return 'طول الشيت';
      if (key == 'sheetWidthManual') return 'عرض الشيت';
    }

    // الحقول المشتركة
    const generalLabels = {
      'length': 'الطول',
      'width': 'العرض',
      'height': 'الارتفاع',
      'productName': 'اسم الصنف',
      'product_name': 'اسم الصنف',
      'productCode': 'كود الصنف',
      'product_code': 'كود الصنف',
      'clientName': 'اسم العميل',
      'client_name': 'اسم العميل',
      'processType': 'نوع العملية',
      'process_type': 'نوع العملية',
      'operation_type': 'نوع العملية',
      'isSheet': 'شيت فقط',
      'is_sheet': 'شيت فقط',
      'sheetLengthResult': 'طول الشيت المحسوب',
      'sheetWidthResult': 'عرض الشيت المحسوب',
      'productState': 'حالة المنتج',
      'product_state': 'حالة المنتج',
      'notes': 'الملاحظات',
    };

    return generalLabels[key] ?? fieldLabels[key] ?? key;
  }

  /// أيقونة مناسبة للحقل حسب نوع العملية
  static IconData _getFieldIcon(String key, bool isDetailing) {
    if (key == 'productionWidth1' || key == 'productionWidth2') {
      return Icons.unfold_more_rounded;
    }
    if (key == 'cuttingType') {
      return Icons.layers_rounded;
    }
    if (key == 'isOverFlap' || key == 'addTwoMm' || key == 'isFlap') {
      return Icons.check_circle_outline_rounded;
    }
    return fieldIcons[key] ?? Icons.edit_note_rounded;
  }

  /// فحص ما إذا كان المفتاح يمثل بعداً أو مقاساً بوحدة "سم"
  static bool isDimensionKey(String key) {
    return key == 'length' ||
        key == 'width' ||
        key == 'height' ||
        key == 'sheetLength' ||
        key == 'sheetWidth' ||
        key == 'sheet_length' ||
        key == 'sheet_width' ||
        key == 'sheetLengthManual' ||
        key == 'sheetWidthManual' ||
        key == 'sheet_length_manual' ||
        key == 'sheet_width_manual' ||
        key == 'sheetLengthResult' ||
        key == 'sheetWidthResult' ||
        key == 'sheet_length_result' ||
        key == 'sheet_width_result' ||
        key == 'productionWidth1' ||
        key == 'production_width_1' ||
        key == 'productionWidth2' ||
        key == 'production_width_2' ||
        key == 'productionHeight' ||
        key == 'production_height';
  }

  /// استخراج الرقم وتنسيق الأبعاد ومقاسات الشيت دون بادئات وصفية ومع منع تكرار وحدة "سم"
  static String formatDimension(dynamic value) {
    if (value == null) return '—';
    String str = value.toString().trim();
    if (str.isEmpty || str == 'null' || str == '—') return '—';

    // توحيد الأرقام المكتوبة بالعربية والفاصلة العشرية
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const englishDigits = '0123456789';
    str = str.replaceAll('٫', '.').replaceAll('،', '.');
    for (int i = 0; i < 10; i++) {
      str = str.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    // 1. تنظيف أي بادئات وصفية مثل "طول الشيت:" أو "عرض الشيت:" أو "طول:" أو الرموز التعبيرية
    str = str.replaceAll(
      RegExp(
        r'^(?:📏|📐)?\s*(?:طول|عرض|ارتفاع|فلاب)?\s*(?:الشيت)?\s*[:\-]?\s*',
        caseSensitive: false,
      ),
      '',
    );

    // 2. إزالة أي تواجد مكرر لوحدة "سم" أو "cm" أو مسافات زائدة
    str = str.replaceAll(RegExp(r'\s*(سم|cm)', caseSensitive: false), '').trim();

    // 3. استخراج القيمة الرقمية النظيفة فقط لمنع أي تكرار أو تشوه
    final match = RegExp(r'[-+]?\d+(?:\.\d+)?').firstMatch(str);
    if (match != null) {
      final rawNumStr = match.group(0)!;
      final d = double.tryParse(rawNumStr);
      if (d != null) {
        // إذا كان الرقم عدداً صحيحاً، يُعرض كعدد صحيح نظيف مثل الطول والعرض (مثال: 134 سم، 120 سم)
        if (d % 1 == 0) {
          return '${d.toInt()} سم';
        }
        // إذا كان كسراً عشرياً، إزالة الأصفار غير الضرورية في النهاية (مثال: 35.90 تصبح 35.9 سم مثل الارتفاع 22.5 سم)
        final formatted = d.toString().replaceAll(RegExp(r'\.?0+$'), '');
        return '$formatted سم';
      }
      return '$rawNumStr سم';
    }

    return str.isEmpty ? '—' : '$str سم';
  }

  /// استخراج وتنسيق عدد العلب
  static String formatBoxes(dynamic value) {
    if (value == null) return '—';
    String str = value.toString().trim();
    if (str.isEmpty || str == 'null' || str == '—') return '—';
    str = str.replaceAll(RegExp(r'\s*علبة', caseSensitive: false), '').trim();
    final d = double.tryParse(str);
    if (d != null) {
      final formatted = d % 1 == 0 ? d.toInt().toString() : d.toString();
      return '$formatted علبة';
    }
    return '$str علبة';
  }

  /// تنسيق القيم لعرض مقروء (إضافة وحدات القياس أو النصوص المناسبة)
  static String _formatFieldValue(String key, dynamic value, bool isDetailing) {
    if (value == null) return '—';
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return '—';

    if (value is bool) {
      if (key == 'isOverFlap' || key == 'addTwoMm' || key == 'isFlap') {
        return value ? 'مفعل' : 'معطل';
      }
      return value ? 'نعم' : 'لا';
    }

    // الأبعاد ومقاسات الفلاب والشيت
    if (isDimensionKey(key)) {
      return formatDimension(value);
    }

    if (key == 'numberOfBoxes' || key == 'number_of_boxes') {
      return formatBoxes(value);
    }

    return str;
  }

  /// تسجيل عملية التعديل (Insert في جدول item_edit_history)
  static Future<void> recordHistory({
    required String itemId,
    required Map<String, dynamic> oldData,
    required Map<String, dynamic> newData,
  }) async {
    if (itemId.trim().isEmpty) return;

    // التحقق من وجود تغييرات حقيقية في البيانات النصية أو الرقمية
    if (!hasChanges(oldData, newData)) {
      debugPrint('ℹ️ [ItemHistoryController] لم تطرأ أي تغييرات نصية أو رقمية على الصنف: $itemId');
      return;
    }

    final cleanOld = extractCleanTextAndNumericData(oldData);
    final cleanNew = extractCleanTextAndNumericData(newData);

    final historyId = const Uuid().v4();
    final editedAt = DateTime.now().toUtc().toIso8601String();

    final factoryId = await SupabaseManager.getFactoryId();

    final payload = <String, dynamic>{
      'id': historyId,
      'item_id': itemId,
      if (factoryId != null && factoryId.isNotEmpty) 'factory_id': factoryId,
      'edited_at': editedAt,
      'old_data': cleanOld,
      'new_data': cleanNew,
    };

    // 1. التخزين المحلي في Hive لضمان السرعة ودعم العمل دون إنترنت (Offline-First)
    try {
      final box = Hive.isBoxOpen('item_edit_history')
          ? Hive.box('item_edit_history')
          : await Hive.openBox('item_edit_history');

      final existing = (box.get(itemId) as List?) ?? [];
      final updatedList = List<Map<String, dynamic>>.from(
        existing.map((e) => Map<String, dynamic>.from(e as Map)),
      )..insert(0, payload);

      await box.put(itemId, updatedList);
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] خطأ حفظ السجل محلياً في Hive: $e');
    }

    // 2. الحفظ في Supabase (مباشر أو عبر طابور المزامنة عند انقطاع الإنترنت)
    try {
      await _supabase.from('item_edit_history').insert(payload);
      debugPrint('✅ [ItemHistoryController] تم إدخال سجل التعديل في Supabase بنجاح للصنف: $itemId');
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] فشل الرفع المباشر ($e) — سيتم الإضافة لطابور المزامنة');
      await SyncService.instance.pushToQueue(
        'item_edit_history',
        payload,
        operation: 'upsert',
      );
    }
  }

  /// جلب السجلات المحلية من كاش Hive مع فحص طابور المزامنة (sync_queue) أولاً (Offline-First)
  static Future<List<Map<String, dynamic>>> getLocalHistory(String itemId) async {
    if (itemId.trim().isEmpty) return [];

    final recordsMap = <String, Map<String, dynamic>>{};

    // 1. استرجاع السجلات المحفوظة في صندوق Hive
    try {
      final box = Hive.isBoxOpen('item_edit_history')
          ? Hive.box('item_edit_history')
          : await Hive.openBox('item_edit_history');

      final cached = box.get(itemId) as List?;
      if (cached != null) {
        for (final item in cached) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id']?.toString() ?? const Uuid().v4();
            recordsMap[id] = map;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] خطأ قراءة الكاش المحلي: $e');
    }

    // 2. فحص طابور المزامنة sync_queue لأي عمليات تعديل معلقة لم ترفع بعد
    try {
      if (Hive.isBoxOpen('sync_queue') || await Hive.boxExists('sync_queue')) {
        final queueBox = Hive.isBoxOpen('sync_queue')
            ? Hive.box('sync_queue')
            : await Hive.openBox('sync_queue');

        for (var i = 0; i < queueBox.length; i++) {
          final entry = queueBox.getAt(i);
          if (entry is Map && entry['table'] == 'item_edit_history') {
            final data = entry['data'];
            if (data is Map && data['item_id']?.toString() == itemId) {
              final map = Map<String, dynamic>.from(data);
              final id = map['id']?.toString() ?? 'pending_$i';
              recordsMap[id] = map;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] خطأ قراءة طابور المزامنة: $e');
    }

    final list = recordsMap.values.toList();
    list.sort((a, b) {
      final aDate = a['edited_at']?.toString() ?? '';
      final bDate = b['edited_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return list;
  }

  /// جلب أحدث البيانات من Supabase وتحديث الكاش المحلي
  static Future<List<Map<String, dynamic>>> fetchRemoteHistory(String itemId) async {
    if (itemId.trim().isEmpty) return [];

    final res = await _supabase
        .from('item_edit_history')
        .select()
        .eq('item_id', itemId)
        .order('edited_at', ascending: false)
        .timeout(const Duration(seconds: 4));

    final serverRecords = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // دمج السجلات المحلية المعلقة في sync_queue التي قد لا تكون رُفعت بعد
    final localRecords = await getLocalHistory(itemId);
    final mergedMap = <String, Map<String, dynamic>>{};

    for (final r in serverRecords) {
      final id = r['id']?.toString() ?? '';
      if (id.isNotEmpty) mergedMap[id] = r;
    }
    for (final r in localRecords) {
      final id = r['id']?.toString() ?? '';
      if (id.isNotEmpty && !mergedMap.containsKey(id)) {
        mergedMap[id] = r;
      }
    }

    final combinedList = mergedMap.values.toList()
      ..sort((a, b) {
        final aDate = a['edited_at']?.toString() ?? '';
        final bDate = b['edited_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

    // تحديث الكاش المحلي
    try {
      final box = Hive.isBoxOpen('item_edit_history')
          ? Hive.box('item_edit_history')
          : await Hive.openBox('item_edit_history');
      await box.put(itemId, combinedList);
    } catch (_) {}

    return combinedList;
  }

  /// جلب سجل التعديلات لصنف معين (Offline-First: محلي أولاً ثم السيرفر)
  static Future<List<Map<String, dynamic>>> fetchHistory(String itemId) async {
    if (itemId.trim().isEmpty) return [];

    final localRecords = await getLocalHistory(itemId);

    try {
      final remoteRecords = await fetchRemoteHistory(itemId);
      if (remoteRecords.isNotEmpty) return remoteRecords;
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] فشل الجلب من Supabase ($e) — استخدام الكاش المحلي');
    }

    return localRecords;
  }

  /// تنظيف القيم المدخلة من أي وحدات قياس ملتصقة مثل "سم" أو "علبة"
  static dynamic cleanRawValue(String key, dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool) return value;
    final str = value.toString().trim();
    if (isDimensionKey(key)) {
      return str.replaceAll(RegExp(r'\s*(سم|cm)', caseSensitive: false), '').trim();
    }
    if (key == 'numberOfBoxes' || key == 'number_of_boxes') {
      return str.replaceAll(RegExp(r'\s*علبة', caseSensitive: false), '').trim();
    }
    return str;
  }

  /// استعادة نسخة سابقة من الصنف مع دمج ذكي وحماية كاملة للصور (Rollback / Restore)
  static Future<bool> restoreHistoryVersion(
    String itemId,
    Map<String, dynamic> targetData,
  ) async {
    if (itemId.trim().isEmpty) {
      debugPrint('⚠️ [restoreHistoryVersion] itemId فارغ');
      return false;
    }

    try {
      final box = Hive.isBoxOpen('savedSheetSizes')
          ? Hive.box('savedSheetSizes')
          : await Hive.openBox('savedSheetSizes');

      dynamic targetKey;
      Map<String, dynamic>? currentItem;

      // البحث عن السجل الحالي في Hive
      for (final key in box.keys) {
        final entry = box.get(key);
        if (entry is Map) {
          final sId = (entry['sync_id'] ?? entry['id'] ?? '').toString().trim();
          final keyStr = key.toString().trim();
          if (sId == itemId.trim() || keyStr == itemId.trim()) {
            targetKey = key;
            currentItem = Map<String, dynamic>.from(entry);
            break;
          }
        }
      }

      if (currentItem == null && box.containsKey(itemId)) {
        final entry = box.get(itemId);
        if (entry is Map) {
          targetKey = itemId;
          currentItem = Map<String, dynamic>.from(entry);
        }
      }

      if (currentItem == null || targetKey == null) {
        debugPrint('⚠️ [restoreHistoryVersion] لم يتم العثور على الصنف في Hive: $itemId');
        return false;
      }

      // ── حماية الصور (حرج جداً) ──
      // الاحتفاظ بمصفوفة الصور الحالية للعميل دون أي تغيير أو مسح
      final dynamic rawImages = currentItem['imagePaths'] ??
          currentItem['image_paths'] ??
          currentItem['images'];

      List<dynamic> preservedImages = [];
      if (rawImages is List) {
        preservedImages = List.from(rawImages);
      } else if (rawImages != null && rawImages.toString().trim().isNotEmpty) {
        preservedImages = [rawImages.toString().trim()];
      }

      // ── الدمج الذكي (Smart Merge) ──
      // استبدال جميع الحقول النصية والرقمية بالبيانات الموجودة في targetData
      final cleanTarget = extractCleanTextAndNumericData(targetData);
      final mergedItem = Map<String, dynamic>.from(currentItem);

      // تحديد نوع العملية المستهدف (تفصيل أو تكسير)
      final op = getOperationType(currentItem, targetData);
      mergedItem['processType'] = op;
      mergedItem['process_type'] = op;
      mergedItem['operation_type'] = op;

      // استبدال الحقول المتتبعة
      for (final key in trackedKeys) {
        dynamic val = targetData[key];
        if (val == null) {
          if (key == 'productName') val = targetData['product_name'];
          if (key == 'productCode') val = targetData['product_code'];
          if (key == 'clientName') val = targetData['client_name'];
          if (key == 'processType') val = targetData['process_type'] ?? targetData['operation_type'];
          if (key == 'isSheet') val = targetData['is_sheet'];
          if (key == 'formNumber') val = targetData['form_number'];
          if (key == 'numberOfBoxes') val = targetData['number_of_boxes'];
          if (key == 'productState') val = targetData['product_state'];
          if (key == 'notes') val = targetData['notes'];
        }

        if (val != null) {
          mergedItem[key] = cleanRawValue(key, val);
        } else if (cleanTarget.containsKey(key)) {
          mergedItem[key] = cleanRawValue(key, cleanTarget[key]);
        }
      }

      // ضبط الحقول الخاصة بنوع العملية لمنع التضارب
      if (op == 'تفصيل') {
        mergedItem.remove('cuttingType');
        mergedItem.remove('sheetLengthManual');
        mergedItem.remove('sheetWidthManual');
        mergedItem.remove('formNumber');
        mergedItem.remove('form_number');
        mergedItem.remove('numberOfBoxes');
        mergedItem.remove('number_of_boxes');
      } else if (op == 'تكسير') {
        mergedItem.remove('productionWidth1');
        mergedItem.remove('productionWidth2');
        mergedItem.remove('productionHeight');
        mergedItem.remove('sheetLengthResult');
        mergedItem.remove('sheetWidthResult');
        mergedItem.remove('isOverFlap');
        mergedItem.remove('isFlap');
        mergedItem.remove('isOneFlap');
        mergedItem.remove('isTwoFlap');
        mergedItem.remove('addTwoMm');
      }

      // توحيد الحقول المشتركة وذات التسميات المزدوجة
      final pState = targetData['productState'] ??
          targetData['product_state'] ??
          cleanTarget['productState'] ??
          mergedItem['productState'] ??
          mergedItem['product_state'] ??
          'سادة';
      mergedItem['productState'] = pState;
      mergedItem['product_state'] = pState;

      final notesVal = targetData['notes'] ??
          cleanTarget['notes'] ??
          mergedItem['notes'] ??
          '';
      mergedItem['notes'] = notesVal.toString();

      final fNum = mergedItem['formNumber'] ?? mergedItem['form_number'];
      mergedItem['formNumber'] = fNum;
      mergedItem['form_number'] = fNum;

      final nBoxes = mergedItem['numberOfBoxes'] ?? mergedItem['number_of_boxes'];
      mergedItem['numberOfBoxes'] = nBoxes;
      mergedItem['number_of_boxes'] = nBoxes;

      // مزامنة تفاصيل الشيت الداخلية sheet_details
      final sheetDetailsMap = (mergedItem['sheet_details'] is Map)
          ? Map<String, dynamic>.from(mergedItem['sheet_details'])
          : <String, dynamic>{};

      sheetDetailsMap.addAll({
        'isOverFlap': mergedItem['isOverFlap'] ?? false,
        'isFlap': mergedItem['isFlap'] ?? true,
        'isOneFlap': mergedItem['isOneFlap'] ?? false,
        'isTwoFlap': mergedItem['isTwoFlap'] ?? true,
        'addTwoMm': mergedItem['addTwoMm'] ?? false,
        'isFullSize': mergedItem['isFullSize'] ?? true,
        'isQuarterSize': mergedItem['isQuarterSize'] ?? false,
        'isQuarterWidth': mergedItem['isQuarterWidth'] ?? true,
        'sheetLengthResult': mergedItem['sheetLengthResult']?.toString() ?? '',
        'sheetWidthResult': mergedItem['sheetWidthResult']?.toString() ?? '',
        'productionWidth1': mergedItem['productionWidth1']?.toString() ?? '',
        'productionHeight': mergedItem['productionHeight']?.toString() ?? '',
        'productionWidth2': mergedItem['productionWidth2']?.toString() ?? '',
        'sheetLengthManual': mergedItem['sheetLengthManual']?.toString() ?? '',
        'sheetWidthManual': mergedItem['sheetWidthManual']?.toString() ?? '',
        'cuttingType': mergedItem['cuttingType']?.toString() ?? 'دوبل',
        'formNumber': fNum?.toString() ?? '',
        'form_number': fNum?.toString() ?? '',
        'numberOfBoxes': nBoxes,
        'number_of_boxes': nBoxes,
      });
      mergedItem['sheet_details'] = sheetDetailsMap;

      // تطبيق الحماية الصارمة لمصفوفة الصور
      mergedItem['imagePaths'] = preservedImages;
      mergedItem['image_paths'] = preservedImages;
      if (currentItem.containsKey('images')) {
        mergedItem['images'] = preservedImages;
      }

      // تحديث تاريخ السجل
      mergedItem['date'] = DateTime.now().toIso8601String();
      mergedItem['sync_id'] = (currentItem['sync_id'] ?? itemId).toString();

      // ── 3. الحفظ والتسجيل (Save & Sync) ──
      // أ) حفظ الكائن المدمج الجديد في Hive
      await box.put(targetKey, mergedItem);
      debugPrint('✅ [restoreHistoryVersion] تم حفظ الصنف المستعاد في Hive بنجاح');

      // ب) إضافة عملية الحفظ إلى طابور المزامنة sync_queue (كعملية update)
      final customerPayload = <String, dynamic>{
        'sync_id': mergedItem['sync_id'],
        'client_name': mergedItem['clientName'] ?? mergedItem['client_name'] ?? '',
        'product_name': mergedItem['productName'] ?? mergedItem['product_name'] ?? '',
        'product_code': mergedItem['productCode'] ?? mergedItem['product_code'] ?? '',
        'process_type': mergedItem['processType'] ?? mergedItem['process_type'] ?? 'تفصيل',
        'length': double.tryParse(mergedItem['length']?.toString() ?? ''),
        'width': double.tryParse(mergedItem['width']?.toString() ?? ''),
        'height': double.tryParse(mergedItem['height']?.toString() ?? ''),
        'is_sheet': mergedItem['isSheet'] == true || mergedItem['is_sheet'] == true,
        'date': mergedItem['date'],
        'is_client_record': mergedItem['isClientRecord'] == true || mergedItem['is_client_record'] == true,
        'image_paths': preservedImages.map((e) => e.toString()).toList(),
        'form_number': fNum?.toString() ?? '',
        'number_of_boxes': double.tryParse(nBoxes?.toString() ?? ''),
        'sheet_details': sheetDetailsMap,
        'product_state': pState,
        'notes': notesVal.toString(),
      };

      await SyncService.instance.pushToQueue(
        'customers',
        customerPayload,
        operation: 'update',
      );
      debugPrint('✅ [restoreHistoryVersion] تم إدراج عملية التحديث في sync_queue (update)');

      // ج) تفعيل دالة recordHistory تلقائياً لتسجيل حركة الاستعادة كتعديل جديد في السجل
      await recordHistory(
        itemId: itemId,
        oldData: currentItem,
        newData: mergedItem,
      );
      debugPrint('✅ [restoreHistoryVersion] تم تسجيل حركة الاستعادة كتعديل جديد في السجل');

      return true;
    } catch (e, stack) {
      debugPrint('❌ [restoreHistoryVersion] خطأ أثناء استعادة التعديل: $e\n$stack');
      return false;
    }
  }
}
