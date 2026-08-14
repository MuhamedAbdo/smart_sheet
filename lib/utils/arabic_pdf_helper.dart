import 'package:arabic_reshaper/arabic_reshaper.dart';

class ArabicPDFHelper {
  static String fixArabic(String text) {
    if (text.isEmpty) return "";

    // 0. إزالة علامات الاتجاه (RTL/LTR marks) لأن مكتبة bidi تتعطل معها
    //    \u200F = Right-to-Left Mark, \u200E = Left-to-Right Mark
    //    \u200B = Zero-Width Space, \u00AD = Soft Hyphen
    //    \uFEFF = BOM / Zero-Width No-Break Space
    String cleaned = text
        .replaceAll('\u200F', '')
        .replaceAll('\u200E', '')
        .replaceAll('\u200B', '')
        .replaceAll('\u00AD', '')
        .replaceAll('\uFEFF', '');

    // 1. إزالة التشكيل (Harakat) لأن مكتبة bidi لا تتعامل معها بشكل صحيح
    //    نطاق التشكيل: \u064B–\u065F (تنوين + حركات)
    //    نطاق إضافي:  \u0610–\u061A (علامات قرآنية)
    cleaned = cleaned.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F]'), '');

    // 2. الاحتفاظ فقط بالأحرف الآمنة:
    //    - العربية الأساسية    \u0600-\u06FF
    //    - العربية التكميلية   \u0750-\u077F
    //    - عرض العربي أ/ب     \uFB50-\uFDFF و \uFE70-\uFEFF
    //    - اللاتينية والأرقام  \u0020-\u007F
    //    - الأرقام العربية     \u0660-\u0669
    //    - مسافات وعلامات ترقيم شائعة
    //    أي حرف خارج هذه النطاقات يُستبدل بمسافة لتجنب crash مكتبة bidi
    cleaned = cleaned.splitMapJoin(
      RegExp(r'.', dotAll: true),
      onMatch: (m) {
        final char = m[0]!;
        final cp = char.codeUnitAt(0);
        // Basic Latin + digits + punctuation
        if (cp >= 0x0020 && cp <= 0x007E) return char;
        // Arabic block
        if (cp >= 0x0600 && cp <= 0x06FF) return char;
        // Arabic Supplement
        if (cp >= 0x0750 && cp <= 0x077F) return char;
        // Arabic Extended-A
        if (cp >= 0x08A0 && cp <= 0x08FF) return char;
        // Arabic Presentation Forms-A
        if (cp >= 0xFB50 && cp <= 0xFDFF) return char;
        // Arabic Presentation Forms-B
        if (cp >= 0xFE70 && cp <= 0xFEFF) return char;
        // Common punctuation / symbols
        if (cp >= 0x00A0 && cp <= 0x00FF) return char;
        // Replace unknown chars with space to prevent bidi crash
        return ' ';
      },
      onNonMatch: (s) => s,
    );

    // 3. التطبيع (Normalization): استبدال الحروف المسببة للمشاكل بحروف قياسية
    String normalized = cleaned
        .replaceAll('\u06CC', '\u064A') // ياء فارسي -> ياء عربي
        .replaceAll('\u0649', '\u064A') // ألف مقصورة -> ياء
        .replaceAll('\u06A4', '\u0641') // حرف ڨ (كود آخر) -> ف
        .replaceAll('\u06A0', '\u0641') // حرف ڨ -> ف
        .replaceAll('\u0671', '\u0627') // همزة وصل -> ألف
        .replaceAll('\u0625', '\u0627') // ألف تحتها همزة -> ألف
        .replaceAll('\u0622', '\u0627') // ألف مد -> ألف
        .replaceAll('\u0623', '\u0627'); // ألف فوقها همزة -> ألف

    // 4. التشكيل (Reshaping) مع حماية من الـ crash
    try {
      var reshaper = ArabicReshaper();
      return reshaper.reshape(normalized);
    } catch (e) {
      // إذا فشل الـ reshaper، نُعيد النص مباشرةً بدون تشكيل
      // هذا أفضل من crash كامل
      return normalized;
    }
  }
}
