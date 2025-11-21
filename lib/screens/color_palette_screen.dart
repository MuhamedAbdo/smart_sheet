// lib/src/screens/flexo/color_palette_screen.dart

import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import 'color_detail_screen.dart'; // ✅ استيراد شاشة التفاصيل
import 'camera_color_picker_screen.dart'; // ✅ استيراد شاشة الكاميرا

// ✅ نسخة من موديل CMYK
class CMYK {
  final int c, m, y, k;

  CMYK(this.c, this.m, this.y, this.k);

  // تحويل CMYK إلى RGB (0-255)
  List<int> toRGB() {
    double c = this.c / 100.0;
    double m = this.m / 100.0;
    double y = this.y / 100.0;
    double k = this.k / 100.0;

    double r = 255 * (1 - c) * (1 - k);
    double g = 255 * (1 - m) * (1 - k);
    double b = 255 * (1 - y) * (1 - k);

    return [
      r.round().clamp(0, 255).toInt(),
      g.round().clamp(0, 255).toInt(),
      b.round().clamp(0, 255).toInt(),
    ];
  }

  String toHex() {
    List<int> rgb = toRGB();
    return '#${rgb[0].toRadixString(16).padLeft(2, '0')}'
            '${rgb[1].toRadixString(16).padLeft(2, '0')}'
            '${rgb[2].toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  @override
  String toString() => 'C:$c% M:$m% Y:$y% K:$k%';
}

// ✅ نسخة من normalizeTo100
CMYK normalizeTo100(CMYK original) {
  int total = original.c + original.m + original.y + original.k;
  if (total == 0) return CMYK(0, 0, 0, 0);
  double factor = 100.0 / total;
  return CMYK(
    (original.c * factor).round().clamp(0, 100).toInt(),
    (original.m * factor).round().clamp(0, 100).toInt(),
    (original.y * factor).round().clamp(0, 100).toInt(),
    (original.k * factor).round().clamp(0, 100).toInt(),
  );
}

class ColorPaletteScreen extends StatelessWidget {
  const ColorPaletteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // إنشاء ألوان CMYK
    final colors = _generateCMYKColors();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'بالتة ألوان',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 1,
        actions: [
          // أيقونة الكاميرا
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () {
              // ✅ Navigate to Camera Screen using standard Navigator
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CameraColorPickerScreen(),
                ),
              );
            },
          ),
          // أيقونة التركيب اليدوي (نحنا مش عملينها دلوقتي، ممكن تضيفها لاحقًا)
          // IconButton(
          //   icon: const Icon(Icons.opacity),
          //   onPressed: () {
          //     // context.push('/manual_mix');
          //   },
          // ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 0.8,
          ),
          itemCount: colors.length,
          itemBuilder: (context, index) {
            final color = colors[index];
            final rgb = color.toRGB();
            final displayColor = Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0);

            return GestureDetector(
              onTap: () {
                // ✅ Navigate to Color Detail Screen using standard Navigator
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ColorDetailScreen(originalCmyk: color),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: displayColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<CMYK> _generateCMYKColors() {
    // ✅ إنشاء ألوان مرتبة حسب المكون المسيطر وفرق 10%
    final List<CMYK> colors = [];

    // عدد الألوان لكل مكون
    int colorsPerGroup = 50; // 200 / 4 = 50

    // 1. Cyan Dominant
    for (int i = 0; i < colorsPerGroup; i++) {
      int c = 100 - (i * 2); // 100 -> 2
      int m = (i * 2) % 101; // 0 -> 100
      int y = (i * 3) % 101; // 0 -> 100
      int k = (i * 1) % 101; // 0 -> 100

      // ضمان المجموع = 100%
      int sum = c + m + y + k;
      if (sum != 100) k = 100 - c - m - y;
      k = k.clamp(0, 100).toInt(); // تأمين القيمة

      colors.add(CMYK(c, m, y, k));
    }

    // 2. Magenta Dominant
    for (int i = 0; i < colorsPerGroup; i++) {
      int m = 100 - (i * 2); // 100 -> 2
      int c = (i * 2) % 101; // 0 -> 100
      int y = (i * 3) % 101; // 0 -> 100
      int k = (i * 1) % 101; // 0 -> 100

      // ضمان المجموع = 100%
      int sum = c + m + y + k;
      if (sum != 100) k = 100 - c - m - y;
      k = k.clamp(0, 100).toInt(); // تأمين القيمة

      colors.add(CMYK(c, m, y, k));
    }

    // 3. Yellow Dominant
    for (int i = 0; i < colorsPerGroup; i++) {
      int y = 100 - (i * 2); // 100 -> 2
      int c = (i * 2) % 101; // 0 -> 100
      int m = (i * 3) % 101; // 0 -> 100
      int k = (i * 1) % 101; // 0 -> 100

      // ضمان المجموع = 100%
      int sum = c + m + y + k;
      if (sum != 100) k = 100 - c - m - y;
      k = k.clamp(0, 100).toInt(); // تأمين القيمة

      colors.add(CMYK(c, m, y, k));
    }

    // 4. Black Dominant
    for (int i = 0; i < colorsPerGroup; i++) {
      int k = 100 - (i * 2); // 100 -> 2
      int c = (i * 2) % 101; // 0 -> 100
      int m = (i * 3) % 101; // 0 -> 100
      int y = (i * 1) % 101; // 0 -> 100

      // ضمان المجموع = 100%
      int sum = c + m + y + k;
      if (sum != 100) k = 100 - c - m - y;
      k = k.clamp(0, 100).toInt(); // تأمين القيمة

      colors.add(CMYK(c, m, y, k));
    }

    return colors;
  }
}
