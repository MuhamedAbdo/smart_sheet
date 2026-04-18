import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smart_sheet/models/finished_product_model.dart';
import 'package:smart_sheet/widgets/app_drawer.dart';
import 'package:smart_sheet/utils/ui_utils.dart';

class FinishedProductScreen extends StatefulWidget {
  const FinishedProductScreen({super.key});

  @override
  State<FinishedProductScreen> createState() => _FinishedProductScreenState();
}

class _FinishedProductScreenState extends State<FinishedProductScreen> {
  Box<FinishedProduct>? _productsBox;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _openBox();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  void _showAddEditDialog([FinishedProduct? existingProduct, dynamic key]) {
    final formKey = GlobalKey<FormState>();
    final dateBackerController =
        TextEditingController(text: existingProduct?.dateBacker ?? "");
    final clientNameController =
        TextEditingController(text: existingProduct?.clientName ?? "");
    final productNameController =
        TextEditingController(text: existingProduct?.productName ?? "");
    final operationOrderController =
        TextEditingController(text: existingProduct?.operationOrder ?? "");
    final productCodeController =
        TextEditingController(text: existingProduct?.productCode ?? "");
    final lengthController =
        TextEditingController(text: existingProduct?.length?.toString() ?? "");
    final widthController =
        TextEditingController(text: existingProduct?.width?.toString() ?? "");
    final heightController =
        TextEditingController(text: existingProduct?.height?.toString() ?? "");
    final countController =
        TextEditingController(text: existingProduct?.count?.toString() ?? "");
    final technicianController =
        TextEditingController(text: existingProduct?.technician ?? "");
    final notesController =
        TextEditingController(text: existingProduct?.notes ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    existingProduct == null ? "إضافة منتج تام" : "تعديل المنتج",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: dateBackerController,
                  readOnly: true,
                  decoration: const InputDecoration(
                      labelText: "📅 تاريخ الإسناد",
                      border: OutlineInputBorder()),
                  onTap: () => _selectDateBacker(context, dateBackerController),
                ),
                const SizedBox(height: 10),
                TextFormField(
                    controller: clientNameController,
                    decoration: const InputDecoration(labelText: "اسم العميل")),
                TextFormField(
                    controller: productNameController,
                    decoration: const InputDecoration(labelText: "اسم الصنف")),
                Row(
                  children: [
                    Expanded(
                        child: TextFormField(
                            controller: operationOrderController,
                            decoration:
                                const InputDecoration(labelText: "رقم الأوردر"),
                            keyboardType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: productCodeController,
                            decoration:
                                const InputDecoration(labelText: "كود الصنف"),
                            keyboardType: TextInputType.number)),
                  ],
                ),
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
                            decoration:
                                const InputDecoration(labelText: "الارتفاع"),
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
                    decoration: const InputDecoration(labelText: "ملاحظات"),
                    maxLines: 2),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
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
                            length: double.tryParse(lengthController.text),
                            width: double.tryParse(widthController.text),
                            height: double.tryParse(heightController.text),
                            count: int.tryParse(countController.text),
                            technician: technicianController.text,
                            notes: notesController.text,
                          );

                          if (existingProduct == null) {
                            _productsBox?.add(product);
                          } else {
                            existingProduct.dateBacker = product.dateBacker;
                            existingProduct.clientName = product.clientName;
                            existingProduct.productName = product.productName;
                            existingProduct.operationOrder =
                                product.operationOrder;
                            existingProduct.productCode = product.productCode;
                            existingProduct.length = product.length;
                            existingProduct.width = product.width;
                            existingProduct.height = product.height;
                            existingProduct.count = product.count;
                            existingProduct.technician = product.technician;
                            existingProduct.notes = product.notes;
                            existingProduct.save();
                          }
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("💾 حفظ البيانات"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateBacker(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  List<MapEntry<dynamic, FinishedProduct>> _prepareRecords(
      Box<FinishedProduct> box) {
    var entries = box.toMap().entries.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      entries = entries.where((e) {
        final p = e.value;
        return (p.clientName?.toLowerCase().contains(q) ?? false) ||
            (p.productName?.toLowerCase().contains(q) ?? false) ||
            (p.operationOrder?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    entries.sort((a, b) =>
        (b.value.dateBacker ?? "").compareTo(a.value.dateBacker ?? ""));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    if (_productsBox == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'بحث باسم العميل أو المنتج...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: () => setState(() {}))
        ],
      ),
      drawer: const AppDrawer(),
      body: ValueListenableBuilder(
        valueListenable: _productsBox!.listenable(),
        builder: (context, Box<FinishedProduct> box, _) {
          final prepared = _prepareRecords(box);
          if (prepared.isEmpty) {
            return const Center(child: Text("لا توجد سجلات حالياً"));
          }

          return ListView.builder(
            itemCount: prepared.length,
            itemBuilder: (context, index) {
              final product = prepared[index].value;
              final key = prepared[index].key;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // السطر الأول: اسم العميل وأزرار التحكم
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            product.clientName ?? "عميل غير معروف",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue, size: 20),
                                onPressed: () =>
                                    _showAddEditDialog(product, key)),
                            IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  final productToRemove = box.get(key);
                                  if (productToRemove == null) return;
                                  
                                  UIUtils.showDeleteConfirmation(
                                    context: context,
                                    title: "حذف المنتج",
                                    content: "هل أنت متأكد من حذف المنتج \"${productToRemove.productName}\"؟",
                                    onConfirm: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      await box.delete(key);
                                      
                                      messenger.clearSnackBars();
                                      if (!context.mounted) return;
                                      UIUtils.showUndoSnackBar(
                                        context: context,
                                        message: "تم حذف المنتج",
                                        onUndo: () async {
                                          messenger.clearSnackBars();
                                          await box.put(key, productToRemove);
                                        },
                                      );
                                    },
                                  );
                                }),
                          ],
                        )
                      ],
                    ),
                    const Divider(height: 20),

                    // اسم الصنف ورقم الأوردر
                    _buildInfoRow(Icons.label_outline, "الصنف: ",
                        product.productName ?? "---"),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                            child: _buildInfoRow(Icons.qr_code, "الكود: ",
                                product.productCode ?? "---")),
                        Expanded(
                            child: _buildInfoRow(Icons.assignment, "الأوردر: ",
                                product.operationOrder ?? "---")),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // المقاسات (طول / عرض / ارتفاع)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMeasureItem(
                              Icons.straighten, "${product.length ?? 0}"),
                          const Text("/",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          _buildMeasureItem(
                              Icons.square_foot, "${product.width ?? 0}"),
                          const Text("/",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          _buildMeasureItem(
                              Icons.height, "${product.height ?? 0}"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // العدد والفني
                    Row(
                      children: [
                        Expanded(
                            child: _buildInfoRow(Icons.numbers, "العدد: ",
                                "${product.count ?? 0}")),
                        Expanded(
                            child: _buildInfoRow(Icons.person, "الفني: ",
                                product.technician ?? "---")),
                      ],
                    ),

                    // الملاحظات
                    if (product.notes != null && product.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.note, "ملاحظات: ", product.notes!),
                    ],

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "التاريخ: ${product.dateBacker}",
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
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

  // ويلجت لبناء سطر معلومات
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ويلجت لبناء عنصر المقاسات
  Widget _buildMeasureItem(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}
