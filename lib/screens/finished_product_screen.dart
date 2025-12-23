// lib/src/screens/staple/finished_product_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/widgets/finished_product_image_viewer.dart';
import 'package:smart_sheet/widgets/full_screen_image_page.dart';

class FinishedProductScreen extends StatefulWidget {
  const FinishedProductScreen({super.key});

  @override
  State<FinishedProductScreen> createState() => _FinishedProductScreenState();
}

class _FinishedProductScreenState extends State<FinishedProductScreen> {
  Box<FinishedProduct>? _productsBox;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  final String _sortBy = 'date';
  final bool _sortAscending = false;
  final bool _onlyWithImages = false;

  late List<CameraDescription> _cameras;
  bool _isCameraAvailable = false;
  late CameraController _cameraController;

  @override
  void initState() {
    super.initState();
    _openBox();
    _initCameras();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    if (_isCameraAvailable) _cameraController.dispose();
    super.dispose();
  }

  Future<void> _openBox() async {
    if (!Hive.isBoxOpen('finished_products')) {
      _productsBox = await Hive.openBox<FinishedProduct>('finished_products');
    } else {
      _productsBox = Hive.box<FinishedProduct>('finished_products');
    }
    setState(() {});
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _isCameraAvailable = true;
        final camera = _cameras.first;
        _cameraController = CameraController(
          camera,
          ResolutionPreset.medium,
        );
        await _cameraController.initialize();
      }
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
      _isCameraAvailable = false;
    }
  }

  void _showAddEditDialog([FinishedProduct? existingProduct, dynamic key]) {
    final formKey = GlobalKey<FormState>();
    final dateBackerController =
        TextEditingController(text: existingProduct?.dateBacker);
    final clientNameController =
        TextEditingController(text: existingProduct?.clientName);
    final productNameController =
        TextEditingController(text: existingProduct?.productName);
    final operationOrderController =
        TextEditingController(text: existingProduct?.operationOrder);
    final productCodeController =
        TextEditingController(text: existingProduct?.productCode);
    final lengthController =
        TextEditingController(text: existingProduct?.length?.toString());
    final widthController =
        TextEditingController(text: existingProduct?.width?.toString());
    final heightController =
        TextEditingController(text: existingProduct?.height?.toString());
    final countController =
        TextEditingController(text: existingProduct?.count?.toString());
    final technicianController =
        TextEditingController(text: existingProduct?.technician);
    final notesController = TextEditingController(text: existingProduct?.notes);

    List<File> capturedImages =
        existingProduct?.imagePaths?.map((path) => File(path)).toList() ?? [];
    capturedImages = capturedImages.where((file) => file.existsSync()).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existingProduct == null
                            ? "إضافة منتج تام"
                            : "تعديل المنتج",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: dateBackerController,
                        readOnly: true,
                        decoration: const InputDecoration(
                            labelText: "📅 تاريخ الإسناد",
                            border: OutlineInputBorder()),
                        onTap: () =>
                            _selectDateBacker(context, dateBackerController),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: clientNameController,
                          decoration:
                              const InputDecoration(labelText: "اسم العميل")),
                      TextFormField(
                          controller: productNameController,
                          decoration:
                              const InputDecoration(labelText: "اسم الصنف")),
                      TextFormField(
                          controller: operationOrderController,
                          decoration: const InputDecoration(
                              labelText: "رقم أمر التشغيل"),
                          keyboardType: TextInputType.number),
                      TextFormField(
                          controller: productCodeController,
                          decoration:
                              const InputDecoration(labelText: "كود الصنف"),
                          keyboardType: TextInputType.number),
                      Row(
                        children: [
                          Expanded(
                              child: TextFormField(
                                  controller: lengthController,
                                  decoration:
                                      const InputDecoration(labelText: "الطول"),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextFormField(
                                  controller: widthController,
                                  decoration:
                                      const InputDecoration(labelText: "العرض"),
                                  keyboardType: TextInputType.number)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextFormField(
                                  controller: heightController,
                                  decoration: const InputDecoration(
                                      labelText: "الارتفاع"),
                                  keyboardType: TextInputType.number)),
                        ],
                      ),
                      TextFormField(
                          controller: countController,
                          decoration: const InputDecoration(labelText: "العدد"),
                          keyboardType: TextInputType.number),
                      TextFormField(
                          controller: technicianController,
                          decoration:
                              const InputDecoration(labelText: "الفني المختص")),
                      TextFormField(
                          controller: notesController,
                          decoration:
                              const InputDecoration(labelText: "ملاحظات"),
                          maxLines: 3),
                      const SizedBox(height: 16),
                      if (_isCameraAvailable)
                        Column(
                          children: [
                            const Text("📸 معاينة الكاميرا",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8)),
                              child: CameraPreview(_cameraController),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final image = await _captureImage();
                                if (image != null)
                                  setModalState(
                                      () => capturedImages.add(image));
                              },
                              icon: const Icon(Icons.camera),
                              label: const Text("التقط صورة"),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      if (capturedImages.isNotEmpty)
                        Column(
                          children: [
                            const Text("🖼️ الصور الملتقطة",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: capturedImages.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0),
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showFullScreenImage(
                                            context,
                                            capturedImages
                                                .map((f) => f.path)
                                                .toList(), // تحويل لـ String
                                            index),
                                        child: Image.file(capturedImages[index],
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.red),
                                        onPressed: () => setModalState(() =>
                                            capturedImages.removeAt(index)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey),
                            child: const Text("إلغاء",
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final product = FinishedProduct(
                                  dateBacker: dateBackerController.text,
                                  clientName: clientNameController.text,
                                  productName: productNameController.text,
                                  operationOrder: operationOrderController.text,
                                  productCode: productCodeController.text,
                                  length:
                                      double.tryParse(lengthController.text),
                                  width: double.tryParse(widthController.text),
                                  height:
                                      double.tryParse(heightController.text),
                                  count: int.tryParse(countController.text),
                                  imagePaths: capturedImages
                                      .map((file) => file.path)
                                      .toList(),
                                  technician: technicianController.text,
                                  notes: notesController.text,
                                );

                                if (existingProduct == null) {
                                  _productsBox?.add(product);
                                } else {
                                  existingProduct.dateBacker =
                                      product.dateBacker;
                                  existingProduct.clientName =
                                      product.clientName;
                                  existingProduct.productName =
                                      product.productName;
                                  existingProduct.operationOrder =
                                      product.operationOrder;
                                  existingProduct.productCode =
                                      product.productCode;
                                  existingProduct.length = product.length;
                                  existingProduct.width = product.width;
                                  existingProduct.height = product.height;
                                  existingProduct.count = product.count;
                                  existingProduct.imagePaths =
                                      product.imagePaths;
                                  existingProduct.technician =
                                      product.technician;
                                  existingProduct.notes = product.notes;
                                  existingProduct.save();
                                }
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text("💾 حفظ"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // الدالة المحدثة لاستقبال المسارات كنصوص
  void _showFullScreenImage(
      BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          imagesPaths: images, // استخدام المعامل الصحيح
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ... باقي الدوال (captureImage, matchesSearch, filterSheet, prepareRecords, build) تبقى كما هي
  // مع التأكد من استدعاء _showFullScreenImage بالمعاملات الجديدة في أي مكان آخر

  Future<void> _selectDateBacker(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.tryParse(controller.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<File?> _captureImage() async {
    if (!_isCameraAvailable || !_cameraController.value.isInitialized)
      return null;
    try {
      final XFile image = await _cameraController.takePicture();
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/finished_product_images');
      await imageDir.create(recursive: true);
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = '${imageDir.path}/$fileName';
      return await File(image.path).copy(newPath);
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }

  bool _matchesSearch(FinishedProduct product, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    return (product.clientName ?? '').toLowerCase().contains(lower) ||
        (product.productName ?? '').toLowerCase().contains(lower) ||
        (product.operationOrder ?? '').toLowerCase().contains(lower);
  }

  void _showFilterSheet() {/* كود الفلترة الخاص بك */}

  List<MapEntry<dynamic, FinishedProduct>> _prepareRecords(
      Box<FinishedProduct> box) {
    var entries = box.toMap().entries.toList();
    // منطق الترتيب والفلترة الخاص بك
    return entries.where((e) => _matchesSearch(e.value, _searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_productsBox == null || !_productsBox!.isOpen) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
                hintText: 'بحث...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70)),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list), onPressed: _showFilterSheet)
        ],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder(
        valueListenable: _productsBox!.listenable(),
        builder: (context, Box<FinishedProduct> box, _) {
          final prepared = _prepareRecords(box);
          return ListView.builder(
            itemCount: prepared.length,
            itemBuilder: (context, index) {
              final product = prepared[index].value;
              final key = prepared[index].key;
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(product.productName ?? 'بدون اسم'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("العميل: ${product.clientName}"),
                      FinishedProductImageViewer(
                          imagePaths: product.imagePaths ?? []),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showAddEditDialog(product, key)),
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => box.delete(key)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddEditDialog(), child: const Icon(Icons.add)),
    );
  }
}
