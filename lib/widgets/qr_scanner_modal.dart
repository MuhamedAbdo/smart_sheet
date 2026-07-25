import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerModal extends StatefulWidget {
  final String title;
  final String subtitle;

  const QRScannerModal({
    super.key,
    this.title = 'مسح باركود (QR Code)',
    this.subtitle = 'قم بتوجيه كاميرا الهاتف نحو رمز QR',
  });

  @override
  State<QRScannerModal> createState() => _QRScannerModalState();
}

class _QRScannerModalState extends State<QRScannerModal> {
  final MobileScannerController controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 420,
        height: 540,
        color: Colors.black,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Camera
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                'تعذر تشغيل الكاميرا.\nيرجى إعادة تشغيل التطبيق بالكامل (Stop & Run) لتفعيل مكتبة الكاميرا الأصلية أو استخدام الإدخال اليدوي.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, 'MANUAL_ENTRY'),
                                child: const Text('الانتقال للإدخال اليدوي'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onDetect: (capture) {
                      if (_hasScanned) return;
                      for (final barcode in capture.barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null && code.trim().isNotEmpty) {
                          _hasScanned = true;
                          Navigator.pop(context, code.trim());
                          break;
                        }
                      }
                    },
                  ),
                  // Viewfinder Frame
                  Center(
                    child: Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  // Flash & Switch camera buttons overlay
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.flash_on, color: Colors.white),
                          onPressed: () => controller.toggleTorch(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cameraswitch,
                              color: Colors.white),
                          onPressed: () => controller.switchCamera(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action Bar with Manual Entry alternative button
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, 'MANUAL_ENTRY'),
                      icon: const Icon(Icons.keyboard),
                      label: const Text(
                        'إدخال الكود يدوياً',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
