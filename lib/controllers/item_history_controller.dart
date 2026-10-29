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

  /// جلب سجل التعديلات لصنف معين (من السيرفر مع كاش محلي)
  static Future<List<Map<String, dynamic>>> fetchHistory(String itemId) async {
    if (itemId.trim().isEmpty) return [];

    // استرجاع الكاش المحلي أولاً
    List<Map<String, dynamic>> localRecords = [];
    try {
      final box = Hive.isBoxOpen('item_edit_history')
          ? Hive.box('item_edit_history')
          : await Hive.openBox('item_edit_history');

      final cached = box.get(itemId) as List?;
      if (cached != null) {
        localRecords = cached
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] خطأ قراءة الكاش المحلي: $e');
    }

    // محاولة جلب أحدث البيانات من Supabase
    try {
      final res = await _supabase
          .from('item_edit_history')
          .select()
          .eq('item_id', itemId)
          .order('edited_at', ascending: false);

      if (res.isNotEmpty) {
        final serverRecords = res
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // تحديث الكاش المحلي
        try {
          final box = Hive.isBoxOpen('item_edit_history')
              ? Hive.box('item_edit_history')
              : await Hive.openBox('item_edit_history');
          await box.put(itemId, serverRecords);
        } catch (_) {}

        return serverRecords;
      }
    } catch (e) {
      debugPrint('⚠️ [ItemHistoryController] فشل الجلب من Supabase ($e) — استخدام الكاش المحلي');
    }

    return localRecords;
  }
}
