import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:smart_sheet/services/job_order_service.dart';
import 'package:smart_sheet/screens/issued_work_orders_screen.dart';

class PdfPreviewScreen extends StatefulWidget {
  final Future<Uint8List> Function(PdfPageFormat) buildPdf;
  final String title;
  final JobOrderData? jobOrderData;

  const PdfPreviewScreen({
    super.key,
    required this.buildPdf,
    this.title = 'معاينة للطباعة',
    this.jobOrderData,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value.getMaxScaleOnAxis() > 1.0) {
      // Zoom out
      _animateTo(Matrix4.identity());
    } else {
      // Zoom in
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const targetScale = 2.5;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);

      final matrix = Matrix4.identity()
        ..setEntry(0, 0, targetScale)
        ..setEntry(1, 1, targetScale)
        ..setEntry(0, 3, x)
        ..setEntry(1, 3, y);

      _animateTo(matrix);
    }
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(
        CurveTween(curve: Curves.easeInOut).animate(_animationController));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style:
              const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1a3a6e),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview.builder(
        build: (format) => widget.buildPdf(format),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true,
        pageFormats: const <String, PdfPageFormat>{
          'A3': PdfPageFormat.a3,
          'A4': PdfPageFormat.a4,
          'A5': PdfPageFormat.a5,
          'A6': PdfPageFormat.a6,
          'Letter': PdfPageFormat.letter,
          'Legal': PdfPageFormat.legal,
          'Roll 57mm': PdfPageFormat.roll57,
          'Roll 80mm': PdfPageFormat.roll80,
        },
        initialPageFormat: PdfPageFormat.a4,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1a3a6e)),
        ),
        actions: [
          if (widget.jobOrderData != null)
            PdfPreviewAction(
              icon: const Icon(Icons.cloud_upload),
              onPressed: (context, _, __) async {
                await _issueAndSync(context);
              },
            ),
        ],
        pagesBuilder: (context, pages) {
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  maxScale: 5.0,
                  minScale: 1.0,
                  panEnabled: true,
                  constrained:
                      false, // يسمح بالتمدد خارج الحدود لحل مشكلة الاقتطاع
                  boundaryMargin: EdgeInsets.zero,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      children: pages
                          .map((page) => Container(
                                margin: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Image(image: page.image),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _issueAndSync(BuildContext context) async {
    if (widget.jobOrderData == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('جاري الاعتماد والمزامنة...',
                textDirection: TextDirection.rtl),
          ],
        ),
      ),
    );

    try {
      await JobOrderService.saveOrder(widget.jobOrderData!);
      if (context.mounted) Navigator.pop(context); // close loading dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إصدار الأمر ومزامنته بنجاح',
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const IssuedWorkOrdersScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // close loading dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء المزامنة: $e',
                textDirection: TextDirection.rtl),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
