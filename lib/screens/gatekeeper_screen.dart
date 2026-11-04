import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_sheet/services/safe_secure_storage.dart';
import 'package:smart_sheet/screens/home_screen.dart';

class GatekeeperScreen extends StatefulWidget {
  static const String routeName = '/gatekeeper';
  const GatekeeperScreen({super.key});

  @override
  State<GatekeeperScreen> createState() => _GatekeeperScreenState();
}

class _GatekeeperScreenState extends State<GatekeeperScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// دالة التحقق من كود الدخول العام (فصل تام عن المصانع)
  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('الرجاء إدخال كود الدخول');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      bool isValid = false;

      // 1. استدعاء الدالة البرمجية validate_invitation_code من Supabase (تتحقق فقط من الكود دون factory_id)
      try {
        final response = await Supabase.instance.client.rpc(
          'validate_invitation_code',
          params: {'p_code': code},
        );
        if (response == true) {
          isValid = true;
        }
      } catch (rpcError) {
        debugPrint('⚠️ validate_invitation_code RPC info/error: $rpcError');
      }

      // 2. التحقق المباشر من جدول pairing_codes (تطابق الكود + is_used = false + الصلاحية expires_at)
      if (!isValid) {
        final res = await Supabase.instance.client
            .from('pairing_codes')
            .select()
            .eq('code', code)
            .maybeSingle();

        if (res != null) {
          final isUsed = res['is_used'] == true;
          bool isExpired = false;
          if (res['expires_at'] != null) {
            final expiresAt = DateTime.tryParse(res['expires_at'].toString());
            if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
              isExpired = true;
            }
          }

          if (!isUsed && !isExpired) {
            isValid = true;
            // تحديث الكود ليكون مستخدماً لمنع تكرار استخدامه
            try {
              await Supabase.instance.client
                  .from('pairing_codes')
                  .update({'is_used': true})
                  .eq('code', code);
            } catch (uErr) {
              debugPrint('⚠️ pairing_codes update error: $uErr');
            }
          }
        }
      }

      if (isValid) {
        // الكود صحيح وغير مستخدم — حفظ حالة التفعيل الدائمة في كافة طبقات التخزين الدائم
        // 1. SharedPreferences (مفتاح دائم لا يتأثر بأي تحديث للتطبيق أو زيادة رقم الإصدار)
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_device_unlocked', true);
          await prefs.setBool('has_valid_code', true);
        } catch (prefsErr) {
          debugPrint('⚠️ GatekeeperScreen: prefs save error: $prefsErr');
        }

        // 2. SafeSecureStorage (FlutterSecureStorage / KeyStore)
        const storage = SafeSecureStorage();
        await storage.write(key: 'is_device_unlocked', value: 'true');
        await storage.write(key: 'has_valid_code', value: 'true');

        // 3. Hive pairing_vault (صندوق الارتباط والتفعيل الدائم)
        if (Hive.isBoxOpen(SafeSecureStorage.pairingVaultBoxName)) {
          final box = Hive.box(SafeSecureStorage.pairingVaultBoxName);
          await box.put('is_device_unlocked', true);
          await box.put('has_valid_code', true);
        } else {
          final vaultBox = await Hive.openBox(SafeSecureStorage.pairingVaultBoxName);
          await vaultBox.put('is_device_unlocked', true);
          await vaultBox.put('has_valid_code', true);
        }

        // 4. Hive settings (للتوافق الرجعي)
        if (Hive.isBoxOpen('settings')) {
          await Hive.box('settings').put('is_device_unlocked', true);
          await Hive.box('settings').put('has_valid_code', true);
        }

        debugPrint('✅ GatekeeperScreen: تم حفظ حالة التفعيل (is_device_unlocked) بنجاح في جميع طبقات التخزين الدائم.');

        if (mounted) {
          // التوجيه مباشرة إلى الشاشة الرئيسية (Home) كمتصفح عام
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              settings: const RouteSettings(name: '/home'),
              pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      } else {
        // الكود غير صحيح أو مستخدم أو منتهي الصلاحية
        _showError('الكود غير صحيح أو تم استخدامه مسبقاً أو منتهي الصلاحية');
      }
    } catch (e) {
      debugPrint('Error validating code: $e');
      _showError('حدث خطأ أثناء التحقق من الكود');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(32.0),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_person_rounded,
                      size: 48,
                      color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    'بوابة الدخول',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'الرجاء إدخال كود الدخول للوصول إلى التطبيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // TextField
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: TextField(
                      controller: _codeController,
                      style: TextStyle(
                        fontSize: 22,
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '------',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                          letterSpacing: 4,
                        ),
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDarkMode ? Colors.blue[400]! : Colors.blue,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                      onSubmitted: (_) => _validateCode(),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _validateCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.blue[600] : Colors.blue[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'تأكيد الدخول',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
