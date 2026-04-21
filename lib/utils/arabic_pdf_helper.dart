import 'package:arabic_reshaper/arabic_reshaper.dart';

class ArabicPDFHelper {
  static String fixArabic(String text) {
    // المحرك يعرف أن text لا يمكن أن يكون null، لذا نفحص الفراغ فقط
    if (text.isEmpty) return "";

    // 1. التطبيع (Normalization): استبدال الحروف المسببة للمشاكل بحروف قياسية
    String normalized = text
        .replaceAll('\u06CC', '\u064A') // ياء فارسي -> ياء عربي
        .replaceAll('\u0649', '\u064A') // ألف مقصورة -> ياء (أحياناً تُستخدم خطأ)
        .replaceAll('\u0642', '\u0642') // قاف
        .replaceAll('\u06A4', '\u0641') // حرف ڨ (كود آخر) -> ف
        .replaceAll('\u06A0', '\u0641') // حرف ڨ -> ف
        .replaceAll('\u0671', '\u0627') // همزة وصل -> ألف
        .replaceAll('\u0625', '\u0627') // ألف تحتها همزة -> ألف (للتسهيل في الخطوط البسيطة)
        .replaceAll('\u0622', '\u0627') // ألف مد -> ألف
        .replaceAll('\u0623', '\u0627'); // ألف فوقها همزة -> ألف

    // 2. التشكيل (Reshaping)
    var reshaper = ArabicReshaper();
    return reshaper.reshape(normalized);
  }
}
