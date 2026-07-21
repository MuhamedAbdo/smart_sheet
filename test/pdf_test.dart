import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sheet/services/job_order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generateNativePdf generates Page 1 & 2 without Flex or Overflow errors and saves file', () async {
    final data = JobOrderData(
      customerName: 'شركة الاختبار التجريبية',
      orderNumber: 'ORD-2026-001',
      items: [
        JobOrderItem(
          productName: 'كرتونة تجريبية أولى',
          productCode: 'COD-101',
          quantity: '5000',
        ),
        JobOrderItem(
          productName: 'كرتونة تجريبية ثانية',
          productCode: 'COD-102',
          quantity: '3000',
        ),
      ],
    );

    final stopwatch = Stopwatch()..start();
    final pdfBytes = await JobOrderService.generateNativePdf(data);
    stopwatch.stop();

    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);
    
    final file1 = File(r'd:\projects\smart_sheet\job_order_extracted.pdf');
    await file1.writeAsBytes(pdfBytes);

    try {
      final file2 = File(r'C:\Users\MuhamedAbdo\Documents\job_order_extracted.pdf');
      await file2.writeAsBytes(pdfBytes);
      // ignore: avoid_print
      print('Saved also to Documents folder.');
    } catch (e) {
      // ignore
    }

    // ignore: avoid_print
    print('PDF generated successfully in ${stopwatch.elapsedMilliseconds} ms with ${pdfBytes.length} bytes.');
    // ignore: avoid_print
    print('Saved to: ${file1.absolute.path}');
  });
}
