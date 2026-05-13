import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  String? _scannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // تنظيف الكود تماماً (أبجدي رقمي) كما طلب المستخدم
        final String rawResult = barcode.rawValue!;
        final String cleanedResult = rawResult.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        
        setState(() {
          _scannedCode = cleanedResult;
          _isScanning = false;
        });
        
        // إرجاع الكود المنظف للشاشة السابقة
        Navigator.pop(context, cleanedResult);
        
        // إعادة تفعيل المسح بعد فترة قصيرة (إذا عاد المستخدم لهذه الشاشة)
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _scannedCode = null;
            });
          }
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // إخفاء شاشة الماسح الضوئي في الكمبيوتر
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && 
        defaultTargetPlatform != TargetPlatform.iOS)) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('قارئ QR Code'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'قارئ QR Code متاح فقط على الأجهزة المحمولة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('قارئ QR Code'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
              });
              if (_isScanning) {
                _controller.start();
              } else {
                _controller.stop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetect,
          ),
          
          if (_scannedCode != null)
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'تم المسح بنجاح!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _scannedCode!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'وجه الكاميرا نحو كود QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isScanning = !_isScanning;
                        });
                        if (_isScanning) {
                          _controller.start();
                        } else {
                          _controller.stop();
                        }
                      },
                      icon: Icon(_isScanning ? Icons.pause : Icons.play_arrow),
                      label: Text(_isScanning ? 'إيقاف' : 'بدء'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('إلغاء'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QRScannerOverlay extends StatelessWidget {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  const QRScannerOverlay({
    super.key,
    required this.borderColor,
    this.borderRadius = 12,
    this.borderLength = 30,
    this.borderWidth = 4,
    this.cutOutSize = 250,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: QRScannerOverlayPainter(
        borderColor: borderColor,
        borderRadius: borderRadius,
        borderLength: borderLength,
        borderWidth: borderWidth,
        cutOutSize: cutOutSize,
      ),
    );
  }
}

class QRScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  QRScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.black54
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutOffset = (size.width - cutOutSize) / 2;

    // رسم الخلفية المعتمة
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(
              cutOutOffset,
              (size.height - cutOutSize) / 2,
              cutOutSize,
              cutOutSize,
            ),
            Radius.circular(borderRadius),
          )),
      ),
      paint,
    );

    // رسم أركان الماسح الضوئي
    final cutOutRect = Rect.fromLTWH(
      cutOutOffset,
      (size.height - cutOutSize) / 2,
      cutOutSize,
      cutOutSize,
    );

    // الركن العلوي الأيسر
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.top + borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.top,
          cutOutRect.left + borderRadius,
          cutOutRect.top,
        )
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.top),
      borderPaint,
    );

    // الركن العلوي الأيمن
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - borderLength, cutOutRect.top)
        ..lineTo(cutOutRect.right - borderRadius, cutOutRect.top)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.top,
          cutOutRect.right,
          cutOutRect.top + borderRadius,
        )
        ..lineTo(cutOutRect.right, cutOutRect.top + borderLength),
      borderPaint,
    );

    // الركن السفلي الأيسر
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.bottom - borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(
          cutOutRect.left,
          cutOutRect.bottom,
          cutOutRect.left + borderRadius,
          cutOutRect.bottom,
        )
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.bottom),
      borderPaint,
    );

    // الركن السفلي الأيمن
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - borderLength, cutOutRect.bottom)
        ..lineTo(cutOutRect.right - borderRadius, cutOutRect.bottom)
        ..quadraticBezierTo(
          cutOutRect.right,
          cutOutRect.bottom,
          cutOutRect.right,
          cutOutRect.bottom - borderRadius,
        )
        ..lineTo(cutOutRect.right, cutOutRect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
