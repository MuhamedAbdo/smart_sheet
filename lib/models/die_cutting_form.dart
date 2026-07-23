import 'package:hive/hive.dart';

part 'die_cutting_form.g.dart';

@HiveType(typeId: 20)
class DieCuttingForm extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String formNumber;

  @HiveField(2)
  double length;

  @HiveField(3)
  double width;

  @HiveField(4)
  double height;

  @HiveField(5)
  double sheetLength;

  @HiveField(6)
  double sheetWidth;

  @HiveField(7)
  double numberOfBoxes;

  @HiveField(8)
  bool isSheet;

  @HiveField(9)
  String? shelfLocation;

  @HiveField(10)
  String? customerName;

  @HiveField(11)
  String? customerCode;

  @HiveField(12)
  String? itemName;

  @HiveField(13)
  String? itemCode;

  DieCuttingForm({
    required this.id,
    required this.formNumber,
    required this.length,
    required this.width,
    required this.height,
    required this.sheetLength,
    required this.sheetWidth,
    required this.numberOfBoxes,
    required this.isSheet,
    this.shelfLocation,
    this.customerName,
    this.customerCode,
    this.itemName,
    this.itemCode,
  });

  DieCuttingForm copyWith({
    String? id,
    String? formNumber,
    double? length,
    double? width,
    double? height,
    double? sheetLength,
    double? sheetWidth,
    double? numberOfBoxes,
    bool? isSheet,
    String? shelfLocation,
    String? customerName,
    String? customerCode,
    String? itemName,
    String? itemCode,
  }) {
    return DieCuttingForm(
      id: id ?? this.id,
      formNumber: formNumber ?? this.formNumber,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      sheetLength: sheetLength ?? this.sheetLength,
      sheetWidth: sheetWidth ?? this.sheetWidth,
      numberOfBoxes: numberOfBoxes ?? this.numberOfBoxes,
      isSheet: isSheet ?? this.isSheet,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      customerName: customerName ?? this.customerName,
      customerCode: customerCode ?? this.customerCode,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
    );
  }

  factory DieCuttingForm.fromJson(Map<String, dynamic> json) {
    return DieCuttingForm(
      id: (json['id'] ?? json['sync_id']).toString(),
      formNumber: (json['form_number'] ?? json['formNumber']).toString(),
      length: ((json['length'] ?? 0) as num).toDouble(),
      width: ((json['width'] ?? 0) as num).toDouble(),
      height: ((json['height'] ?? 0) as num).toDouble(),
      sheetLength: ((json['sheet_length'] ?? json['sheetLength'] ?? 0) as num).toDouble(),
      sheetWidth: ((json['sheet_width'] ?? json['sheetWidth'] ?? 0) as num).toDouble(),
      numberOfBoxes: ((json['number_of_boxes'] ?? json['numberOfBoxes'] ?? 0) as num).toDouble(),
      isSheet: json['is_sheet'] ?? json['isSheet'] as bool? ?? false,
      shelfLocation: json['shelf_location'] ?? json['shelfLocation'] as String?,
      customerName: json['customer_name'] as String?,
      customerCode: json['customer_code'] as String?,
      itemName: json['item_name'] as String?,
      itemCode: json['item_code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'form_number': formNumber,
      'length': length,
      'width': width,
      'height': height,
      'sheet_length': sheetLength,
      'sheet_width': sheetWidth,
      'number_of_boxes': numberOfBoxes,
      'is_sheet': isSheet,
      'shelf_location': shelfLocation,
      'customer_name': customerName,
      'customer_code': customerCode,
      'item_name': itemName,
      'item_code': itemCode,
    };
  }
}
