import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// خدمة إدارة أكواد الربط بين الأجهزة
class PairingService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const _storage = FlutterSecureStorage();
  
  String? _currentCode;
  DateTime? _codeExpiry;
  Timer? _expiryTimer;
  
  // Singleton pattern
  static final PairingService _instance = PairingService._internal();
  factory PairingService() => _instance;
  PairingService._internal();
  
  /// توليد كود عشوائي مكون من 6 أرقام (مع إضافة أصفار في البداية إذا لزم)
  String _generateCode() {
    final random = Random();
    final code = random.nextInt(1000000); // 0 to 999999
    return code.toString().padLeft(6, '0'); // Always 6 digits
  }
  
  /// إنشاء كود ربط جديد
  Future<String?> generatePairingCode() async {
    try {
      final factoryId = await _storage.read(key: 'factory_id');
      if (factoryId == null || factoryId.isEmpty) {
        debugPrint('❌ Error: factory_id is missing!');
        return null;
      }
      
      // إلغاء الكود القديم إن وجد
      await _cancelExistingCode(factoryId);
      
      // توليد كود جديد
      final code = _generateCode();
      final expiryTime = DateTime.now().add(const Duration(minutes: 5));
      
      // حفظ في Supabase
      debugPrint('💾 Saving pairing code to Supabase: $code for factory: $factoryId');
      try {
        await _supabase.from('pairing_codes').upsert({
          'code': code,
          'factory_id': factoryId,
          'created_at': DateTime.now().toIso8601String(),
          'expires_at': expiryTime.toIso8601String(),
        });
        debugPrint('✅ Pairing code saved successfully');
      } catch (insertError) {
        debugPrint('❌ Error saving pairing code: $insertError');
        // نحاول insert عادي بدون upsert
        try {
          await _supabase.from('pairing_codes').insert({
            'code': code,
            'factory_id': factoryId,
            'created_at': DateTime.now().toIso8601String(),
            'expires_at': expiryTime.toIso8601String(),
          });
          debugPrint('✅ Pairing code saved with insert');
        } catch (e2) {
          debugPrint('❌ Insert also failed: $e2');
          return null;
        }
      }

      _currentCode = code;
      _codeExpiry = expiryTime;
      
      // إعداد مؤقت لإلغاء الكود بعد 5 دقائق
      _expiryTimer?.cancel();
      _expiryTimer = Timer(const Duration(minutes: 5), () async {
        await _cancelExistingCode(factoryId);
        _currentCode = null;
        _codeExpiry = null;
      });
      
      debugPrint('✅ Pairing code generated: $code (expires at $expiryTime)');
      return code;
    } catch (e) {
      debugPrint('❌ Error generating pairing code: $e');
      return null;
    }
  }
  
  /// إلغاء كود موجود
  Future<void> _cancelExistingCode(String factoryId) async {
    try {
      await _supabase
          .from('pairing_codes')
          .delete()
          .eq('factory_id', factoryId);
    } catch (e) {
      debugPrint('⚠️ Error canceling existing code: $e');
    }
  }
  
  /// التحقق من صحة الكود وربط الجهاز
  Future<Map<String, dynamic>?> verifyAndLink(String code) async {
    try {
      // تنظيف الكود تماماً (أبجدي رقمي) كما طلب المستخدم
      final cleanCode = code.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final currentFactoryId = await _storage.read(key: 'factory_id');
      debugPrint('🔍 Verifying pairing code: $cleanCode (current factory: $currentFactoryId)');
      
      // جلب الكود من قاعدة البيانات
      final response = await _supabase
          .from('pairing_codes')
          .select()
          .eq('code', cleanCode)
          .maybeSingle();
      
      debugPrint('📊 Supabase response: $response');
      
      if (response == null) {
        debugPrint('❌ Code not found in database');
        return {'success': false, 'error': 'الكود غير صحيح'};
      }
      
      // التحقق من انتهاء الصلاحية
      final expiresAt = DateTime.parse(response['expires_at']);
      if (DateTime.now().isAfter(expiresAt)) {
        return {'success': false, 'error': 'انتهت صلاحية الكود'};
      }
      
      final factoryId = response['factory_id'] as String;
      
      // حذف الكود بعد الاستخدام (للأمان)
      await _supabase.from('pairing_codes').delete().eq('code', code);
      
      return {
        'success': true,
        'factory_id': factoryId,
      };
    } catch (e) {
      debugPrint('❌ Error verifying pairing code: $e');
      return {'success': false, 'error': 'حدث خطأ أثناء التحقق'};
    }
  }
  
  /// الحصول على الوقت المتبقي للكود
  Duration? getRemainingTime() {
    if (_codeExpiry == null) return null;
    return _codeExpiry!.difference(DateTime.now());
  }
  
  /// إلغاء الكود الحالي
  Future<void> cancelCurrentCode() async {
    _expiryTimer?.cancel();
    
    try {
      final factoryId = await _storage.read(key: 'factory_id');
      if (factoryId != null && _currentCode != null) {
        await _cancelExistingCode(factoryId);
      }
    } catch (e) {
      debugPrint('⚠️ Error canceling current code: $e');
    }
    
    _currentCode = null;
    _codeExpiry = null;
  }
  
  /// التحقق مما إذا كان هناك كود نشط
  bool get hasActiveCode => _currentCode != null && _codeExpiry != null && DateTime.now().isBefore(_codeExpiry!);
  
  /// الحصول على الكود الحالي
  String? get currentCode => _currentCode;
}
