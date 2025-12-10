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

  // Search
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';

  // Filter / Sort
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _onlyWithImages = false;

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
    _cameraController.dispose();
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

    // ✅ تحميل الصور مع تجاهل الملفات المفقودة
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
                            const InputDecoration(labelText: "اسم العميل"),
                      ),
                      TextFormField(
                        controller: productNameController,
                        decoration:
                            const InputDecoration(labelText: "اسم الصنف"),
                      ),
                      TextFormField(
                        controller: operationOrderController,
                        decoration:
                            const InputDecoration(labelText: "رقم أمر التشغيل"),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: productCodeController,
                        decoration:
                            const InputDecoration(labelText: "كود الصنف"),
                        keyboardType: TextInputType.number,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: lengthController,
                              decoration:
                                  const InputDecoration(labelText: "الطول"),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: widthController,
                              decoration:
                                  const InputDecoration(labelText: "العرض"),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: heightController,
                              decoration:
                                  const InputDecoration(labelText: "الارتفاع"),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: countController,
                        decoration: const InputDecoration(labelText: "العدد"),
                        keyboardType: TextInputType.number,
                      ),
                      TextFormField(
                        controller: technicianController,
                        decoration:
                            const InputDecoration(labelText: "الفني المختص"),
                      ),
                      TextFormField(
                        controller: notesController,
                        decoration: const InputDecoration(labelText: "ملاحظات"),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      if (_isCameraAvailable)
                        Column(
                          children: [
                            const Text(
                              "📸 معاينة الكاميرا",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CameraPreview(_cameraController),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final image = await _captureImage();
                                if (image != null) {
                                  setModalState(() {
                                    capturedImages.add(image);
                                  });
                                }
                              },
                              icon: const Icon(Icons.camera),
                              label: const Text("التقط صورة"),
                            ),
                            const SizedBox(height: 16),
                          ],
                        )
                      else
                        const Text("الكاميرا غير متاحة"),
                      if (capturedImages.isNotEmpty)
                        Column(
                          children: [
                            const Text(
                              "🖼️ الصور الملتقطة",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                                            context, capturedImages, index),
                                        child: Image.file(
                                          capturedImages[index],
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            size: 18, color: Colors.red),
                                        onPressed: () {
                                          setModalState(() {
                                            capturedImages.removeAt(index);
                                          });
                                        },
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
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
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
    if (!_isCameraAvailable || !_cameraController.value.isInitialized) {
      return null;
    }

    if (!mounted) return null;

    try {
      final XFile image = await _cameraController.takePicture();

      // ✅ حفظ الصورة في مجلد دائم
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/finished_product_images');
      await imageDir.create(recursive: true);

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = '${imageDir.path}/$fileName';

      final File savedImage = await File(image.path).copy(newPath);

      return savedImage;
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }

  void _showFullScreenImage(
      BuildContext context, List<File> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImagePage(
          images: images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  bool _matchesSearch(FinishedProduct product, String q) {
    if (q.isEmpty) return true;
    final lower = q.toLowerCase();
    final client = (product.clientName ?? '').toString().toLowerCase();
    final productN = (product.productName ?? '').toString().toLowerCase();
    final order = (product.operationOrder ?? '').toString().toLowerCase();
    final code = (product.productCode ?? '').toString().toLowerCase();
    final tech = (product.technician ?? '').toString().toLowerCase();
    final dateBacker = (product.dateBacker ?? '').toString().toLowerCase();
    return client.contains(lower) ||
        productN.contains(lower) ||
        order.contains(lower) ||
        code.contains(lower) ||
        tech.contains(lower) ||
        dateBacker.contains(lower);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        String tempSortBy = _sortBy;
        bool tempSortAscending = _sortAscending;
        bool tempOnlyWithImages = _onlyWithImages;
        return StatefulBuilder(builder: (context, setStateSB) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('خيارات الفلترة والترتيب',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('ترتيب حسب:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: tempSortBy,
                        items: const [
                          DropdownMenuItem(
                              value: 'date', child: Text('تاريخ الإسناد')),
                          DropdownMenuItem(
                              value: 'clientName', child: Text('اسم العميل')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setStateSB(() => tempSortBy = v);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('اتجاه الترتيب:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<bool>(
                        value: tempSortAscending,
                        items: const [
                          DropdownMenuItem(
                              value: false, child: Text('الأحدث أولاً')),
                          DropdownMenuItem(
                              value: true, child: Text('الأقدم أولاً')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setStateSB(() => tempSortAscending = v);
                        },
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: tempOnlyWithImages,
                  onChanged: (v) {
                    setStateSB(() => tempOnlyWithImages = v ?? false);
                  },
                  title: const Text('إظهار المنتجات التي تحتوي على صور فقط'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _sortBy = tempSortBy;
                            _sortAscending = tempSortAscending;
                            _onlyWithImages = tempOnlyWithImages;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        });
      },
    );
  }

  List<MapEntry<dynamic, FinishedProduct>> _prepareRecords(
      Box<FinishedProduct> box) {
    var entries = box.toMap().entries.toList();

    entries.sort((a, b) {
      int result = 0;
      switch (_sortBy) {
        case 'date':
          final dateA = a.value.dateBacker ?? '';
          final dateB = b.value.dateBacker ?? '';
          result = dateA.compareTo(dateB);
          break;
        case 'clientName':
          final clientA = a.value.clientName ?? '';
          final clientB = b.value.clientName ?? '';
          result = clientA.compareTo(clientB);
          break;
        default:
          result = a.key.compareTo(b.key);
      }
      if (!_sortAscending) {
        result = -result;
      }
      return result;
    });

    var filtered = entries;
    if (_onlyWithImages) {
      filtered = filtered
          .where((e) => (e.value.imagePaths?.isNotEmpty ?? false))
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((e) => _matchesSearch(e.value, _searchQuery)).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    if (_productsBox == null || !_productsBox!.isOpen) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              setState(() {
                _searchQuery = _searchController.text.trim();
              });
              _searchFocus.unfocus();
            },
            decoration: InputDecoration(
              hintText: 'ابحث باسم العميل، الصنف، أمر التشغيل أو الكود',
              hintStyle: const TextStyle(color: Colors.white70),
              filled: false,
              prefixIcon: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _searchQuery = _searchController.text.trim();
                  });
                  _searchFocus.unfocus();
                },
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder(
        valueListenable: _productsBox!.listenable(),
        builder: (context, Box<FinishedProduct> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("لا توجد منتجات بعد."));
          }

          final prepared = _prepareRecords(box);

          if (prepared.isEmpty) {
            return Center(
              child: Text(_searchQuery.isNotEmpty
                  ? 'لا توجد نتائج مطابقة لـ "$_searchQuery"'
                  : 'لا توجد منتجات تطابق الفلاتر'),
            );
          }

          return ListView.builder(
            itemCount: prepared.length,
            itemBuilder: (context, index) {
              final entry = prepared[index];
              final dynamic key = entry.key;
              final product = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "📦 ${product.productName ?? 'منتج'}",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () =>
                                    _showAddEditDialog(product, key),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _productsBox?.delete(key);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (product.dateBacker != null &&
                          product.dateBacker!.isNotEmpty)
                        Text("📅 تاريخ الإسناد: ${product.dateBacker}"),
                      if (product.clientName != null &&
                          product.clientName!.isNotEmpty)
                        Text("👤 العميل: ${product.clientName}"),
                      if (product.operationOrder != null &&
                          product.operationOrder!.isNotEmpty)
                        Text("🔢 أمر التشغيل: ${product.operationOrder}"),
                      if (product.productCode != null &&
                          product.productCode!.isNotEmpty)
                        Text("🔢 كود الصنف: ${product.productCode}"),
                      if (product.length != null ||
                          product.width != null ||
                          product.height != null)
                        Text(
                            "📏 المقاس: ${product.length?.toStringAsFixed(2) ?? 0} × ${product.width?.toStringAsFixed(2) ?? 0} × ${product.height?.toStringAsFixed(2) ?? 0}"),
                      if (product.count != null)
                        Text("🔢 العدد: ${product.count}"),
                      if (product.technician != null &&
                          product.technician!.isNotEmpty)
                        Text("👨‍🔧 الفني: ${product.technician}"),
                      if (product.notes != null && product.notes!.isNotEmpty)
                        Text("📝 ملاحظات: ${product.notes}"),
                      FinishedProductImageViewer(
                        imagePaths: product.imagePaths ?? [],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
