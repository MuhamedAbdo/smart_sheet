// lib/src/screens/flexo/camera_color_picker_screen.dart

import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
// ✅ حذف استيراد go_router
// import 'package:go_router/go_router.dart';
import 'color_palette_screen.dart'; // استيراد CMYK
import 'color_detail_screen.dart'; // ✅ استيراد شاشة التفاصيل

class CameraColorPickerScreen extends StatefulWidget {
  const CameraColorPickerScreen({super.key});

  @override
  State<CameraColorPickerScreen> createState() =>
      _CameraColorPickerScreenState();
}

class _CameraColorPickerScreenState extends State<CameraColorPickerScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  List<CameraDescription>? cameras;
  bool _flashOn = false;
  bool _isCapturing = false; // ✅ متغير جديد

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        _showError('No cameras found.');
        return;
      }

      final camera = cameras!.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras![0],
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _initializeControllerFuture = _controller.initialize();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _showError('Camera init error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  CMYK rgbToCmyk(int r, int g, int b) {
    double rf = r / 255.0;
    double gf = g / 255.0;
    double bf = b / 255.0;
    double k = 1 - [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    double c = k == 1 ? 0 : (1 - rf - k) / (1 - k);
    double m = k == 1 ? 0 : (1 - gf - k) / (1 - k);
    double y = k == 1 ? 0 : (1 - bf - k) / (1 - k);

    c = c.clamp(0, 1);
    m = m.clamp(0, 1);
    y = y.clamp(0, 1);
    k = k.clamp(0, 1);

    return CMYK(
      (c * 100).round().clamp(0, 100).toInt(),
      (m * 100).round().clamp(0, 100).toInt(),
      (y * 100).round().clamp(0, 100).toInt(),
      (k * 100).round().clamp(0, 100).toInt(),
    );
  }

  Future<void> _captureAndAnalyzeCenterPixel() async {
    if (!_controller.value.isInitialized) {
      _showError('Camera not ready.');
      return;
    }

    // ✅ منع الضغط المتكرر
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    // ✅ إضافة مؤشر تقدم
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final image = await _controller.takePicture();
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);

      if (decodedImage == null) {
        _showError('Failed to decode image.');
        Navigator.of(context).pop(); // إغلاق مؤشر التقدم
        setState(() {
          _isCapturing = false;
        });
        return;
      }

      int centerX = decodedImage.width ~/ 2;
      int centerY = decodedImage.height ~/ 2;
      final pixel = decodedImage.getPixel(centerX, centerY);
      int r = pixel.r.toInt().clamp(0, 255);
      int g = pixel.g.toInt().clamp(0, 255);
      int b = pixel.b.toInt().clamp(0, 255);

      CMYK cmyk = rgbToCmyk(r, g, b);
      if (!mounted) return;
      Navigator.of(context).pop(); // إغلاق مؤشر التقدم
      // ✅ Navigate to Color Detail Screen using standard Navigator
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ColorDetailScreen(originalCmyk: cmyk),
          // ✅ تمرير الكائن مباشرة كـ argument
        ),
      );
    } catch (e) {
      // ✅ إظهار سبب المشكلة
      _showError('Capture failed: ${e.runtimeType} - $e');
      Navigator.of(context).pop(); // إغلاق مؤشر التقدم
    } finally {
      // ✅ تأكد من أن _isCapturing ترجع false
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    try {
      await _controller.setFlashMode(
        _flashOn ? FlashMode.off : FlashMode.torch,
      );
      if (!mounted) return;
      setState(() {
        _flashOn = !_flashOn;
      });
    } catch (e) {
      _showError('Flash not supported: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (cameras == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ✅ كاميرا تملأ الشاشة بدون فراغات
          LayoutBuilder(
            builder: (context, constraints) {
              return FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // استخدم AspectRatio لضبط النسبة
                    return SizedBox.expand(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: CameraPreview(_controller),
                      ),
                    );
                  } else {
                    // ✅ إضافة مؤشر تقدم للكاميرا
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              );
            },
          ),

          // ✅ علامة X على الصورة (ليس على الشاشة)
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 60,
                height: 60,
                child: CustomPaint(painter: _CrosshairPainter()),
              ),
            ),
          ),

          // ✅ شريط تحكم في الأسفل
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  heroTag: "flash",
                  onPressed: _toggleFlash,
                  backgroundColor:
                      _flashOn ? Colors.yellow[700] : Colors.grey[700],
                  mini: true,
                  child: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 24),
                FloatingActionButton(
                  heroTag: "capture",
                  onPressed: _isCapturing
                      ? null
                      : _captureAndAnalyzeCenterPixel, // ✅ تعطيل الزر
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  child: _isCapturing // ✅ تغيير الأيقونة
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                        )
                      : const Icon(Icons.circle, size: 32),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(
        Offset(centerX - 22, centerY), Offset(centerX - 8, centerY), paint);
    canvas.drawLine(
        Offset(centerX + 8, centerY), Offset(centerX + 22, centerY), paint);
    canvas.drawLine(
        Offset(centerX, centerY - 22), Offset(centerX, centerY - 8), paint);
    canvas.drawLine(
        Offset(centerX, centerY + 8), Offset(centerX, centerY + 22), paint);
    canvas.drawCircle(Offset(centerX, centerY), 14, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
