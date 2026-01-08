// lib/src/screens/flexo/color_detail_screen.dart

import 'package:flutter/material.dart';
import 'color_palette_screen.dart'; // استيراد CMYK

class ColorDetailScreen extends StatefulWidget {
  final CMYK originalCmyk;

  const ColorDetailScreen({super.key, required this.originalCmyk});

  @override
  State<ColorDetailScreen> createState() => _ColorDetailScreenState();
}

class _ColorDetailScreenState extends State<ColorDetailScreen> {
  bool _showWhiteInk = false;
  double _whitePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _whitePercentage = _suggestWhitePercentage(widget.originalCmyk);
  }

  double _suggestWhitePercentage(CMYK cmyk) {
    // اقتراح ذكي لنسبة الحبر الأبيض
    if (cmyk.k >= 70 && cmyk.c < 20 && cmyk.m < 20 && cmyk.y < 20) {
      return 30.0; // رمادي فاتح
    }
    if (cmyk.c >= 50 && cmyk.m >= 30) {
      return 20.0; // أرجواني فاتح → لبني
    }
    if (cmyk.c >= 60 && cmyk.m < 20 && cmyk.y < 20) {
      return 25.0; // أزرق فاتح → لبني
    }
    if (cmyk.c >= 40 && cmyk.y >= 40) {
      return 15.0; // أخضر فاتح
    }
    return 0.0;
  }

  Color _calculateFinalColor(CMYK original, double whitePercentage) {
    if (whitePercentage <= 0) {
      return Color.fromRGBO(
        original.toRGB()[0],
        original.toRGB()[1],
        original.toRGB()[2],
        1.0,
      );
    }

    List<int> rgb = original.toRGB();
    double wp = whitePercentage / 100.0;
    double lp = 1.0 - wp;

    int r = (rgb[0] * lp + 255 * wp).round().clamp(0, 255).toInt();
    int g = (rgb[1] * lp + 255 * wp).round().clamp(0, 255).toInt();
    int b = (rgb[2] * lp + 255 * wp).round().clamp(0, 255).toInt();

    return Color.fromRGBO(r, g, b, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    List<int> rgb = widget.originalCmyk.toRGB();
    Color originalColor = Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);
    Color finalColor = _showWhiteInk
        ? _calculateFinalColor(widget.originalCmyk, _whitePercentage)
        : originalColor;

    CMYK normalized = normalizeTo100(widget.originalCmyk);
    int actualTotal = widget.originalCmyk.c +
        widget.originalCmyk.m +
        widget.originalCmyk.y +
        widget.originalCmyk.k;

    return Scaffold(
      backgroundColor: finalColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Card(
                color: finalColor.computeLuminance() > 0.5
                    ? Colors.black54
                    : Colors.white30,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'القراءة الرقمية',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'CMYK: C:${widget.originalCmyk.c}% M:${widget.originalCmyk.m}% Y:${widget.originalCmyk.y}% K:${widget.originalCmyk.k}%',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      Text(
                        'المجموع: $actualTotal%',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'نسبة خلط الحبر المائي: C:${normalized.c}% M:${normalized.m}% Y:${normalized.y}% K:${normalized.k}%',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'HEX: ${widget.originalCmyk.toHex()}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Text(
                        'RGB: R:${rgb[0]} G:${rgb[1]} B:${rgb[2]}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showWhiteInk = !_showWhiteInk;
                    if (!_showWhiteInk) _whitePercentage = 0;
                  });
                },
                icon: const Icon(Icons.opacity, color: Colors.white),
                label: Text(
                  _showWhiteInk ? 'إخفاء الحبر الأبيض' : 'أضف حبر أبيض',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (_showWhiteInk) ...[
                const SizedBox(height: 16),
                Text(
                  'نسبة الحبر الأبيض: ${_whitePercentage.toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Slider(
                  value: _whitePercentage,
                  min: 0,
                  max: 100,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withOpacity(0.3),
                  onChanged: (value) {
                    setState(() {
                      _whitePercentage = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.blueGrey.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الخلطة النهائية المقترحة:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'أبيض: ${_whitePercentage.toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        Text(
                          'سيان: ${(normalized.c * (100 - _whitePercentage) / 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        Text(
                          'ماچنتا: ${(normalized.m * (100 - _whitePercentage) / 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        Text(
                          'أصفر: ${(normalized.y * (100 - _whitePercentage) / 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                        Text(
                          'أسود: ${(normalized.k * (100 - _whitePercentage) / 100).toInt()}%',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
