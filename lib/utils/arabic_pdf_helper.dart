import 'package:arabic_reshaper/arabic_reshaper.dart';

class ArabicPDFHelper {
  static String fixArabic(String text) {
    // المحرك يعرف أن text لا يمكن أن يكون null، لذا نفحص الفراغ فقط
    if (text.isEmpty) return "";

    // 1. التطبيع (Normalization): استبدال الحروف المسببة للمشاكل بحروف قياسية
    String normalized = text
        .replaceAll('\u06CC', '\u064A') // ياء فارسي -> ياء عربي
        .replaceAll('\u06A4', '\u0641') // حرف ڨ (كود آخر) -> ف
        .replaceAll('\u06A0', '\u0641'); // حرف ڨ -> ف

    // 2. التشكيل (Reshaping)
    var reshaper = ArabicReshaper();
    return reshaper.reshape(normalized);
  }
}
