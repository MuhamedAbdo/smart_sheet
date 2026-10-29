import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sheet/controllers/item_history_controller.dart';

void main() {
  group('ItemHistoryController - computeDifferences tests', () {
    test('عملية تفصيل: يجب تغيير مسمى فلاب 1 وفلاب 2 وحجب عدد العلب ورقم الفورمة', () {
      final oldData = {
        'operation_type': 'تفصيل',
        'length': '50',
        'width': '30',
        'productionWidth1': '20',
        'productionWidth2': '10',
        'numberOfBoxes': '5', // لا يجب أن يظهر
        'formNumber': 'F-99', // لا يجب أن يظهر
        'isFullSize': true,
        'isQuarterSize': false,
        'addTwoMm': false,
        'isOverFlap': false,
      };

      final newData = {
        'operation_type': 'تفصيل',
        'length': '55',
        'width': '30',
        'productionWidth1': '25',
        'productionWidth2': '15',
        'numberOfBoxes': '10', // تم تغييره لكن يجب حجبه في التفصيل
        'formNumber': 'F-100', // تم تغييره لكن يجب حجبه في التفصيل
        'isFullSize': false,
        'isQuarterSize': false, // أصبح 1/2 ص
        'addTwoMm': true,
        'isOverFlap': true,
      };

      final diffs = ItemHistoryController.computeDifferences(oldData, newData);

      // التأكد من عدم ظهور عدد العلب ورقم الفورمة إطلاقاً
      expect(diffs.any((d) => d.key == 'numberOfBoxes'), isFalse);
      expect(diffs.any((d) => d.key == 'formNumber'), isFalse);

      // التأكد من مسميات فلاب 1 وفلاب 2
      final flap1Diff = diffs.firstWhere((d) => d.key == 'productionWidth1');
      expect(flap1Diff.label, 'فلاب 1');
      expect(flap1Diff.oldValue, '20 سم');
      expect(flap1Diff.newValue, '25 سم');

      final flap2Diff = diffs.firstWhere((d) => d.key == 'productionWidth2');
      expect(flap2Diff.label, 'فلاب 2');
      expect(flap2Diff.oldValue, '10 سم');
      expect(flap2Diff.newValue, '15 سم');

      // التأكد من ظهور نوع الشريحة بدلاً من البوليانات الفردية
      final sliceDiff = diffs.firstWhere((d) => d.key == 'sliceType');
      expect(sliceDiff.label, 'نوع الشريحة');
      expect(sliceDiff.oldValue, 'ص');
      expect(sliceDiff.newValue, '1/2 ص');

      // التأكد من خيارات التفصيل (أوفر فلاب، إضافة 2 ملم)
      final overFlapDiff = diffs.firstWhere((d) => d.key == 'isOverFlap');
      expect(overFlapDiff.label, 'أوفر فلاب');
      expect(overFlapDiff.oldValue, 'معطل');
      expect(overFlapDiff.newValue, 'مفعل');

      final addTwoMmDiff = diffs.firstWhere((d) => d.key == 'addTwoMm');
      expect(addTwoMmDiff.label, 'إضافة 2 ملم للفلاب');
      expect(addTwoMmDiff.oldValue, 'معطل');
      expect(addTwoMmDiff.newValue, 'مفعل');
    });

    test('عملية تكسير: يجب ظهور عدد العلب ورقم الفورمة وتسمية نوع التضليع / الشريحة', () {
      final oldData = {
        'processType': 'تكسير',
        'length': '60',
        'width': '40',
        'cuttingType': 'دوبل',
        'numberOfBoxes': '2',
        'formNumber': 'F-10',
        'productionWidth1': '20', // لا يجب أن يظهر في التكسير
      };

      final newData = {
        'processType': 'تكسير',
        'length': '60',
        'width': '40',
        'cuttingType': 'سنجل C',
        'numberOfBoxes': '4',
        'formNumber': 'F-12',
        'productionWidth1': '30', // تم تغييره لكن يجب حجبه في التكسير
      };

      final diffs = ItemHistoryController.computeDifferences(oldData, newData);

      // التأكد من حجب حقول التفصيل
      expect(diffs.any((d) => d.key == 'productionWidth1'), isFalse);

      // التأكد من مسمى نوع التضليع / الشريحة
      final cuttingDiff = diffs.firstWhere((d) => d.key == 'cuttingType');
      expect(cuttingDiff.label, 'نوع التضليع / الشريحة');
      expect(cuttingDiff.oldValue, 'دوبل');
      expect(cuttingDiff.newValue, 'سنجل C');

      // التأكد من ظهور عدد العلب ورقم الفورمة
      final boxesDiff = diffs.firstWhere((d) => d.key == 'numberOfBoxes');
      expect(boxesDiff.label, 'عدد العلب');
      expect(boxesDiff.oldValue, '2 علبة');
      expect(boxesDiff.newValue, '4 علبة');

      final formDiff = diffs.firstWhere((d) => d.key == 'formNumber');
      expect(formDiff.label, 'رقم الفورمة');
      expect(formDiff.oldValue, 'F-10');
      expect(formDiff.newValue, 'F-12');
    });

    test('تجاهل الحقول الفارغة والأصفار غير المعنية', () {
      final oldData = {
        'processType': 'تفصيل',
        'length': '50',
        'height': '0',
        'width': null,
      };

      final newData = {
        'processType': 'تفصيل',
        'length': '50',
        'height': 0.0,
        'width': '',
      };

      final diffs = ItemHistoryController.computeDifferences(oldData, newData);
      expect(diffs.isEmpty, isTrue);
      expect(ItemHistoryController.hasChanges(oldData, newData), isFalse);
    });
  });
}
