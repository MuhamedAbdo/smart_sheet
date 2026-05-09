import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/utils/ui_utils.dart';
// الويدجات التالية محجوبة مؤقتاً من الـ UI لكنها تُستخدم في منطق التعديل
// ignore: unused_import
import 'package:smart_sheet/widgets/sheet_size_buttons.dart';
// ignore: unused_import
import 'package:smart_sheet/widgets/sheet_size_calculations.dart';
// ignore: unused_import
import 'package:smart_sheet/widgets/desktop_image_picker.dart';
// ignore: unused_import
import 'package:smart_sheet/widgets/sheet_size_checkboxes.dart';
// ignore: unused_import
import 'package:smart_sheet/widgets/sheet_size_form.dart';
// ignore: unused_import
import 'package:smart_sheet/widgets/sheet_size_production_table.dart';
import 'package:smart_sheet/services/sync_service.dart';

class AddSheetSizeScreen extends StatefulWidget {
  final Map? existingData;
  final dynamic existingDataKey;

  /// إذا مُرِّر هذا المتغير، يُعبَأ حقل اسم العميل ويُغلق تلقائياً
  final String? clientName;

  /// وضع "إدارة العميل" (تعديل اسم أو كود العميل فقط)
  final bool isClientOnlyMode;

  const AddSheetSizeScreen({
    super.key,
    this.existingData,
    this.existingDataKey,
    this.clientName,
    this.isClientOnlyMode = false,
  });

  @override
  State<AddSheetSizeScreen> createState() => _AddSheetSizeScreenState();
}

class _AddSheetSizeScreenState extends State<AddSheetSizeScreen> {
  String _processType = "تفصيل";
  String _cuttingType = 'دوبل';

  final clientNameController = TextEditingController();
  final productNameController = TextEditingController();
  final productCodeController = TextEditingController();
  final lengthController = TextEditingController();
  final widthController = TextEditingController();
  final heightController = TextEditingController();
  final sheetLengthManualController = TextEditingController();
  final sheetWidthManualController = TextEditingController();

  bool _isProcessing = false;
  List<dynamic> _capturedImages = []; // يدعم File محلي و String لرابط Supabase

  bool isSheet = false;
  bool isOverFlap = false;
  bool isFlap = true;

  bool isOneFlap = false;
  bool isTwoFlap = true;
  bool addTwoMm = false;
  bool isFullSize = true;
  bool isQuarterSize = false;
  bool isQuarterWidth = true;

  String sheetLengthResult = "";
  String sheetWidthResult = "";
  String productionWidth1 = "";
  String productionHeight = "";
  String productionWidth2 = "";

  String? _originalClientName;
  String? _originalClientCode;

  late Box _savedSheetSizesBox;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _savedSheetSizesBox = await Hive.openBox('savedSheetSizes');
    if (widget.existingData != null) {
      _loadExistingData(widget.existingData!);
      _originalClientName =
          widget.existingData!['clientName']?.toString().trim();
      _originalClientCode =
          widget.existingData!['productCode']?.toString().trim();
    } else if (widget.clientName != null && widget.clientName!.isNotEmpty) {
      // تعبئة اسم العميل تلقائياً عند الإضافة من شاشة تفاصيل العميل
      clientNameController.text = widget.clientName!;
      _originalClientName = widget.clientName!.trim();
    }
  }

  // دالة لتوحيد النصوص والأرقام العربية/الإنجليزية لتجنب التكرار
  String _normalizeString(String input) {
    if (input.isEmpty) return "";
    String normalized = input.trim().toLowerCase();

    // توحيد الحروف العربية (أ إ آ -> ا)، (ة -> ه)، (ى -> ي)
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');
    normalized = normalized.replaceAll('ة', 'ه');
    normalized = normalized.replaceAll('ى', 'ي');

    // تحويل الأرقام العربية إلى إنجليزية
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < arabicNumbers.length; i++) {
      normalized = normalized.replaceAll(arabicNumbers[i], i.toString());
    }

    return normalized;
  }

  // دالة للبحث عن مفتاح السجل المكرر (نفس العميل + نفس الكود)
  dynamic _getDuplicateKey(String clientName, String productCode) {
    if (clientName.trim().isEmpty) return null;

    final String newClient = _normalizeString(clientName);
    final String newCode = _normalizeString(productCode);

    for (var i = 0; i < _savedSheetSizesBox.length; i++) {
      final key = _savedSheetSizesBox.keyAt(i);
      final record = _savedSheetSizesBox.getAt(i);
      if (record is Map) {
        final existingClient =
            _normalizeString((record['clientName'] ?? '').toString());
        final existingCode =
            _normalizeString((record['productCode'] ?? '').toString());

        // نتخطى السجل الحالي إذا كنا في وضع التعديل لمنع التصادم مع النفس
        if (widget.existingDataKey != null && key == widget.existingDataKey) {
          continue;
        }

        if (existingClient == newClient && existingCode == newCode) {
          return key;
        }
      }
    }
    return null;
  }

  Future<void> _saveSheetSize(
      {dynamic duplicateKey, bool shouldDeleteOriginal = true}) async {
    final clientName = clientNameController.text.trim();
    final productCode = productCodeController.text.trim();

    // ① التحقق من أن اسم العميل غير فارغ
    if (clientName.isEmpty) {
      UIUtils.showInfoSnackBar(
        message: 'يرجى إدخال اسم العميل أولاً.',
        backgroundColor: Colors.redAccent,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    // ② التحقق من تكرار اسم العميل (في وضع الإضافة فقط)
    if (widget.existingDataKey == null && widget.clientName == null) {
      final String newClientLower = clientName.toLowerCase();
      bool clientAlreadyExists = false;

      for (var i = 0; i < _savedSheetSizesBox.length; i++) {
        final record = _savedSheetSizesBox.getAt(i);
        if (record is Map) {
          final existingClient =
              (record['clientName'] ?? '').toString().trim().toLowerCase();
          if (existingClient == newClientLower) {
            clientAlreadyExists = true;
            break;
          }
        }
      }

      if (clientAlreadyExists) {
        UIUtils.showInfoSnackBar(
          message: 'عذراً، هذا العميل مسجل بالفعل في النظام.',
          backgroundColor: Colors.orange,
          icon: Icons.error_outline,
        );
        return;
      }
    }

    final List<String> imageNames = _capturedImages.map((item) {
      if (item is File) {
        return item.path
            .split('/')
            .last; // إذا كانت صورة محلية جديدة احفظ اسمها فقط
      } else if (item is String) {
        return item; // إذا كان رابط Supabase أو مسار كامل، اتركه كما هو
      }
      return item.toString();
    }).toList();

    final newRecord = <String, dynamic>{
      'sync_id': widget.existingDataKey?.toString() ??
          '${DateTime.now().millisecondsSinceEpoch}_${clientName.hashCode}',
      'processType': _processType,
      'clientName': clientName,
      'productName': productNameController.text.trim(),
      'productCode': productCode,
      'length': lengthController.text,
      'width': widthController.text,
      'height': heightController.text,
      'imagePaths': imageNames,
      'date': DateTime.now().toIso8601String(),
      'isSheet': isSheet,
      'isClientRecord': isAddingClientOnly,
      'factoryId': '', // سيُملأ بواسطة SyncService
    };

    if (_processType == "تفصيل") {
      newRecord.addAll({
        'isOverFlap': isOverFlap,
        'isFlap': isFlap,
        'isOneFlap': isOneFlap,
        'isTwoFlap': isTwoFlap,
        'addTwoMm': addTwoMm,
        'isFullSize': isFullSize,
        'isQuarterSize': isQuarterSize,
        'isQuarterWidth': isQuarterWidth,
        'sheetLengthResult': sheetLengthResult,
        'sheetWidthResult': sheetWidthResult,
        'productionWidth1': productionWidth1,
        'productionHeight': productionHeight,
        'productionWidth2': productionWidth2,
      });
    } else {
      newRecord.addAll({
        'sheetLengthManual': sheetLengthManualController.text,
        'sheetWidthManual': sheetWidthManualController.text,
        'cuttingType': _cuttingType,
      });
    }

    // --- المنطق المطور للطلب (Hybrid Logic) ---
    if (duplicateKey != null) {
      // 1. حالة الإستبدال: نحدث السجل الذي كان مكرراً بالبيانات الجديدة
      await _savedSheetSizesBox.put(duplicateKey, newRecord);
      // وحذف السجل الأصلي (القديم) إذا لزم الأمر لضمان نظافة البيانات
      if (shouldDeleteOriginal &&
          widget.existingDataKey != null &&
          widget.existingDataKey != duplicateKey) {
        await _savedSheetSizesBox.delete(widget.existingDataKey);
      }
    } else {
      // 2. الفحص الأولي قبل الحفظ
      if (widget.existingDataKey != null) {
        // وضع التعديل (Edit Mode)
        if (productCode == _originalClientCode) {
          // لم يتغير الكود: تحديث السجل الحالي مباشرة
          await _savedSheetSizesBox.put(widget.existingDataKey, newRecord);
        } else {
          // تغير الكود: نفحص هل الكود الجديد مكرر عند نفس العميل؟
          final foundKey = _getDuplicateKey(clientName, productCode);
          if (foundKey != null) {
            // كود مكرر: نظهر ديالوج الاستبدال
            _showReplaceDialog(foundKey);
            return;
          }
          // كود فريد: نحفظ كـ صنف جديد (Template) ونبقي على القديم
          await _savedSheetSizesBox.add(newRecord);
        }
      } else {
        // وضع الإضافة (Add Mode) - نفحص التكرار أولاً
        final foundKey = _getDuplicateKey(clientName, productCode);
        if (foundKey != null) {
          _showReplaceDialog(foundKey);
          return;
        }
        await _savedSheetSizesBox.add(newRecord);
      }
    }

    // ④ المرحلة 3: تحديث متتالي (Cascading Update) إذا تغير اسم العميل أو كوده
    // يتم هذا فقط إذا كنا في وضع "تعديل بيانات العميل" (isClientOnlyMode)
    if (widget.isClientOnlyMode && _originalClientName != null) {
      final newName = clientName;
      final newCode = productCode;

      if (newName != _originalClientName || newCode != _originalClientCode) {
        final box = _savedSheetSizesBox;
        for (var i = 0; i < box.length; i++) {
          final key = box.keyAt(i);
          final record = box.getAt(i);
          if (record is Map &&
              (record['clientName']?.toString().trim() ?? '') ==
                  _originalClientName) {
            final updatedRecord = Map<String, dynamic>.from(record);
            updatedRecord['clientName'] = newName;
            // لا نحدث الكود هنا للحفاظ على استقلالية أكواد الأصناف كما طلب المستخدم

            await box.put(key, updatedRecord);
          }
        }
      }
    }

    if (mounted) {
      // مزامنة سحابية عبر Queue (تعمل offline أيضاً)
      SyncService.instance.pushToQueue('customers', _buildCustomerPayload(newRecord));

      UIUtils.showInfoSnackBar(
        message: "تم حفظ البيانات وتحديث السجلات",
        backgroundColor: Colors.green,
        icon: Icons.check_circle_outline,
      );
      Navigator.pop(context);
    }
  }

  /// تحويل سجل Hive إلى تنسيق جدول customers في Supabase
  Map<String, dynamic> _buildCustomerPayload(Map<String, dynamic> r) {
    return {
      'sync_id': r['sync_id'],
      'client_name': r['clientName'],
      'product_name': r['productName'],
      'product_code': r['productCode'],
      'process_type': r['processType'],
      'length': r['length'],
      'width': r['width'],
      'height': r['height'],
      'is_sheet': r['isSheet'],
      'date': r['date'],
      'is_client_record': r['isClientRecord'],
      'image_paths': r['imagePaths'] ?? [],
    };
  }

  // ديالوج التعارض (إستبدال أو إلغاء)
  void _showReplaceDialog(dynamic targetKey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                "هذا الكود مسجل بالفعل",
                softWrap: true,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            "هذا العميل (${clientNameController.text.trim()}) لديه صنف آخر بنفس الكود (${productCodeController.text.trim()}).\n\nهل تريد استبدال الصنف الموجود بالجديد؟",
            style: const TextStyle(height: 1.4),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _saveSheetSize(
                  duplicateKey: targetKey, shouldDeleteOriginal: true);
            },
            child: const Text("إستبدال", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- باقي الدوال (الكاميرا، الحسابات، إلخ) كما هي تماماً ---

  void _loadExistingData(Map data) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDirPath = '${appDir.path}/images';

    setState(() {
      _processType = data['processType'] ?? 'تفصيل';
      _cuttingType = data['cuttingType'] ?? 'دوبل';
      clientNameController.text = data['clientName']?.toString() ?? '';
      productNameController.text = data['productName']?.toString() ?? '';
      productCodeController.text = data['productCode']?.toString() ?? '';
      lengthController.text = data['length']?.toString() ?? '';
      widthController.text = data['width']?.toString() ?? '';
      heightController.text = data['height']?.toString() ?? '';
      isSheet = data['isSheet'] ?? false;

      if (data['imagePaths'] != null) {
        _capturedImages = (data['imagePaths'] as List).map((p) {
          String path = p.toString();
          if (path.startsWith('http')) {
            return path; // الاحتفاظ برابط الإنترنت كنص (String)
          } else if (!path.contains('/')) {
            return File('$imageDirPath/$path'); // استعادة الملف المحلي
          }
          return File(path); // مسار محلي كامل
        }).toList();
      }

      sheetLengthManualController.text =
          data['sheetLengthManual']?.toString() ?? '';
      sheetWidthManualController.text =
          data['sheetWidthManual']?.toString() ?? '';
      isOverFlap = data['isOverFlap'] ?? false;
      isFlap = data['isFlap'] ?? true;
      isOneFlap = data['isOneFlap'] ?? false;
      isTwoFlap = data['isTwoFlap'] ?? true;
      addTwoMm = data['addTwoMm'] ?? false;
      isFullSize = data['isFullSize'] ?? true;
      isQuarterSize = data['isQuarterSize'] ?? false;
      isQuarterWidth = data['isQuarterWidth'] ?? true;
      sheetLengthResult = data['sheetLengthResult'] ?? "";
      sheetWidthResult = data['sheetWidthResult'] ?? "";
      productionWidth1 = data['productionWidth1'] ?? "";
      productionHeight = data['productionHeight'] ?? "";
      productionWidth2 = data['productionWidth2'] ?? "";
    });
  }

  // دالة مرفقات جديدة باستخدام FilePicker لسطح المكتب
  Future<void> _pickImages() async {
    setState(() => _isProcessing = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${appDir.path}/images');
        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        for (var file in result.files) {
          if (file.path != null) {
            final String fileName =
                'IMG_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final targetPath = '${imageDir.path}/$fileName';
            final savedFile = await File(file.path!).copy(targetPath);
            setState(() => _capturedImages.add(savedFile));
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking files: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ignore: unused_element — محجوب مؤقتاً مع واجهة العميل المبسطة
  void _calculateSheet() {
    if (_processType != "تفصيل" || isAddingClientOnly) return;
    double L = double.tryParse(lengthController.text) ?? 0.0;
    double W = double.tryParse(widthController.text) ?? 0.0;
    double H = double.tryParse(heightController.text) ?? 0.0;
    double sL = 0.0;
    double sW = 0.0;

    if (isFullSize) {
      sL = ((L + W) * 2) + 4;
    } else if (isQuarterSize) {
      sL = isQuarterWidth ? W + 4 : L + 4;
    } else {
      sL = L + W + 4;
    }

    if (isOverFlap && isTwoFlap) {
      sW = addTwoMm ? H + (W * 2) + 0.4 : H + (W * 2);
    } else if (isOverFlap && isOneFlap) {
      sW = addTwoMm ? H + W + 0.2 : H + W;
    } else if (isFlap && isTwoFlap) {
      sW = addTwoMm ? H + W + 0.4 : H + W;
    } else if (isFlap && isOneFlap) {
      sW = addTwoMm ? H + (W / 2) + 0.2 : H + (W / 2);
    }

    productionHeight = H.toStringAsFixed(2);
    if (isOverFlap && isTwoFlap) {
      productionWidth1 =
          addTwoMm ? (W + 0.2).toStringAsFixed(2) : W.toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isOverFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 =
          addTwoMm ? (W + 0.2).toStringAsFixed(2) : W.toStringAsFixed(2);
    } else if (isFlap && isTwoFlap) {
      productionWidth1 = addTwoMm
          ? ((W / 2) + 0.2).toStringAsFixed(2)
          : (W / 2).toStringAsFixed(2);
      productionWidth2 = productionWidth1;
    } else if (isFlap && isOneFlap) {
      productionWidth1 = ".....";
      productionWidth2 = addTwoMm
          ? ((W / 2) + 0.2).toStringAsFixed(2)
          : (W / 2).toStringAsFixed(2);
    } else {
      productionWidth1 = productionWidth2 = ".....";
    }

    setState(() {
      sheetLengthResult = "طول الشيت: ${sL.toStringAsFixed(2)} سم";
      sheetWidthResult = "عرض الشيت: ${sW.toStringAsFixed(2)} سم";
    });
  }

  // خاصية لتحديد ما إذا كنا في وضع "إضافة/تعديل عميل" فقط (حقلين فقط)
  bool get isAddingClientOnly =>
      widget.isClientOnlyMode ||
      (widget.clientName == null &&
          widget.existingData == null &&
          widget.existingDataKey == null);

  @override
  void dispose() {
    clientNameController.dispose();
    productNameController.dispose();
    productCodeController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
    sheetLengthManualController.dispose();
    sheetWidthManualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLockedMode =
        widget.clientName != null && widget.existingDataKey == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isClientOnlyMode
            ? "تعديل بيانات العميل"
            : widget.existingDataKey != null
                ? "تعديل الصنف"
                : isAddingClientOnly
                    ? "إضافة عميل جديد"
                    : "إضافة صنف"),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: () => _saveSheetSize())
        ],
      ),
      resizeToAvoidBottomInset: true, // السماح للـ Scaffold بالتفاعل مع الكيبورد
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          // نُضيف ارتفاع الكيبورد كـ padding سفلي لضمان scroll صحيح
          padding: EdgeInsets.fromLTRB(
            16, 16, 16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- نموذج الحقول الأساسية ---
              SheetSizeForm(
                clientNameController: clientNameController,
                productNameController: productNameController,
                productCodeController: productCodeController,
                lengthController: lengthController,
                widthController: widthController,
                heightController: heightController,
                sheetLengthManualController: sheetLengthManualController,
                sheetWidthManualController: sheetWidthManualController,
                cuttingType: _cuttingType,
                onCuttingTypeChanged: (v) =>
                    setState(() => _cuttingType = v ?? 'دوبل'),
                processType: _processType,
                onProcessTypeChanged: (v) => setState(() => _processType = v),
                isSheet: isSheet,
                onSheetChanged: (v) {
                  setState(() {
                    isSheet = v ?? false;
                    if (isSheet) {
                      heightController.text = "0";
                    }
                  });
                },
                clientNameEnabled: !isLockedMode,
                clientNameLocked: isLockedMode,
                isAddingClientOnly: isAddingClientOnly,
              ),

              const SizedBox(height: 16),

              // في وضع إضافة عميل فقط، لا نعرض بقية الأقسام (كاميرا، خيارات، إلخ)
              if (!isAddingClientOnly) ...[
                // --- مرفقات سطح المكتب ---
                DesktopImagePicker(
                  isProcessing: _isProcessing,
                  capturedImages: _capturedImages,
                  onPickImages: _pickImages,
                  onRemoveImage: (index) {
                    final removedImage = _capturedImages[index];
                    UIUtils.showDeleteConfirmation(
                      context: context,
                      title: "حذف الصورة",
                      content: "هل أنت متأكد من حذف هذه الصورة؟",
                      onConfirm: () {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _capturedImages.removeAt(index));

                        messenger.clearSnackBars();
                        UIUtils.showUndoSnackBar(
                          context: context,
                          message: "تم حذف الصورة",
                          onUndo: () {
                            messenger.clearSnackBars();
                            setState(() =>
                                _capturedImages.insert(index, removedImage));
                          },
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 16),

                // --- خيارات التفصيل (مرئية فقط عند نوع "تفصيل") ---
                if (_processType == 'تفصيل') ...[
                  SheetSizeCheckboxes(
                    isOverFlap: isOverFlap,
                    isFlap: isFlap,
                    isOneFlap: isOneFlap,
                    isTwoFlap: isTwoFlap,
                    addTwoMm: addTwoMm,
                    isFullSize: isFullSize,
                    isQuarterSize: isQuarterSize,
                    isQuarterWidth: isQuarterWidth,
                    onOverFlapChanged: (v) => setState(() {
                      isOverFlap = v!;
                      isFlap = !v;
                    }),
                    onFlapChanged: (v) => setState(() {
                      isFlap = v!;
                      isOverFlap = !v;
                    }),
                    onOneFlapChanged: (v) => setState(() {
                      isOneFlap = v!;
                      isTwoFlap = !v;
                    }),
                    onTwoFlapChanged: (v) => setState(() {
                      isTwoFlap = v!;
                      isOneFlap = !v;
                    }),
                    onAddTwoMmChanged: (v) =>
                        setState(() => addTwoMm = v ?? false),
                    onFullSizeChanged: (v) => setState(() {
                      isFullSize = v!;
                      isQuarterSize = false;
                    }),
                    onQuarterSizeChanged: (v) => setState(() {
                      isQuarterSize = v ?? false;
                      isFullSize = false;
                    }),
                    onQuarterWidthChanged: (v) =>
                        setState(() => isQuarterWidth = v!),
                  ),

                  const SizedBox(height: 12),

                  // --- زر الحساب (يأتي من ويدجت منفصل) ---
                  SheetSizeButtons(
                    onCalculate: _calculateSheet,
                    onSave: _saveSheetSize,
                  ),

                  const SizedBox(height: 12),

                  // --- نتائج الحساب ---
                  if (sheetLengthResult.isNotEmpty)
                    SheetSizeCalculations(
                      sheetLengthResult: sheetLengthResult,
                      sheetWidthResult: sheetWidthResult,
                    ),

                  const SizedBox(height: 12),

                  // --- جدول مقاسات الإنتاج ---
                  if (productionWidth1.isNotEmpty)
                    SheetSizeProductionTable(
                      productionWidth1: productionWidth1,
                      productionHeight: productionHeight,
                      productionWidth2: productionWidth2,
                    ),
                ],
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
