import 'package:flutter_test/flutter_test.dart';
import 'package:smart_sheet/services/job_order_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generateNativePdf generates Page 1 & 2 without Flex or Overflow errors', () async {
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

    final pdfBytes = await JobOrderService.generateNativePdf(data);
    expect(pdfBytes, isNotNull);
    expect(pdfBytes.isNotEmpty, isTrue);
    // ignore: avoid_print
    print('PDF generated successfully with ${pdfBytes.length} bytes.');
  });
}
