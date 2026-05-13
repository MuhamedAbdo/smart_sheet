import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:smart_sheet/screens/qr_scanner_screen.dart';
import 'package:smart_sheet/services/auth_service.dart';
import 'package:provider/provider.dart';

class FactoryLinkScreen extends StatefulWidget {
  const FactoryLinkScreen({super.key});

  @override
  State<FactoryLinkScreen> createState() => _FactoryLinkScreenState();
}

class _FactoryLinkScreenState extends State<FactoryLinkScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _scannedCode;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    setState(() {
      _scannedCode = null;
    });
  }

  Future<void> _linkWithCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showErrorSnackBar('الرجاء إدخال كود الربط');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _saveFactoryLink(code);

      if (mounted) {
        _showSuccessSnackBar('تم ربط الجهاز بنجاح!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل الربط: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanQRCode() async {
    if (kIsWeb || Platform.isWindows) {
      _showErrorSnackBar('قارئ QR Code متاح فقط على الأجهزة المحمولة');
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result != null && result is String && mounted) {
      setState(() {
        _scannedCode = result;
        _codeController.text = result;
      });

      // التحقق من صحة الكود الممسوح تلقائياً
      await _validateAndLink(result);
    }
  }

  Future<void> _validateAndLink(String code) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // تنظيف الكود تماماً (أبجدي رقمي) كما طلب المستخدم
      final cleanCode = code.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      
      if (cleanCode.isEmpty) {
        _showErrorSnackBar('كود QR غير صالح.');
        return;
      }

      await _saveFactoryLink(cleanCode);

      if (mounted) {
        _showSuccessSnackBar('تم ربط الجهاز بنجاح!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل التحقق من الكود: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// حفظ بيانات ربط المصنع
  Future<void> _saveFactoryLink(String factoryCode) async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // استخدام الدالة الموحدة في AuthService لضمان المزامنة والتخزين الصحيح
    final error = await authService.linkToFactory(factoryCode);

    if (error != null) {
      throw Exception(error);
    }

    debugPrint(
        '✅ Factory linked successfully via AuthService with code: $factoryCode');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // الصف الأول
          Row(
            children: [
              _buildNumberButton('1'),
              _buildNumberButton('2'),
              _buildNumberButton('3'),
            ],
          ),
          const SizedBox(height: 1),
          // الصف الثاني
          Row(
            children: [
              _buildNumberButton('4'),
              _buildNumberButton('5'),
              _buildNumberButton('6'),
            ],
          ),
          const SizedBox(height: 1),
          // الصف الثالث
          Row(
            children: [
              _buildNumberButton('7'),
              _buildNumberButton('8'),
              _buildNumberButton('9'),
            ],
          ),
          const SizedBox(height: 1),
          // الصف الرابع
          Row(
            children: [
              _buildNumberButton(''),
              _buildNumberButton('0'),
              _buildDeleteButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    if (number.isEmpty) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(1),
          child: const SizedBox(),
        ),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (_codeController.text.length < 6) {
                _codeController.text += number;
                _onCodeChanged(_codeController.text);
              }
            },
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(1),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              if (_codeController.text.isNotEmpty) {
                final newText = _codeController.text
                    .substring(0, _codeController.text.length - 1);
                _codeController.text = newText;
                _onCodeChanged(newText);
              }
            },
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: const Icon(
                Icons.backspace_outlined,
                size: 24,
                color: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // منع الخروج التلقائي
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // عند محاولة الرجوع، توجه للشاشة الرئيسية بدلاً من الخروج من التطبيق
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('ربط جهاز الكمبيوتر'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: (kIsWeb || (Platform.isWindows))
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'رجوع',
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/home',
                        (route) => false,
                      );
                    }
                  },
                )
              : null,
        ),
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // البطاقة الرئيسية
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // العنوان
                        const Text(
                          'ربط جهاز الكمبيوتر',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // التعليمات
                        const Text(
                          'أدخل كود الربط المكون من 6 أرقام الذي يظهر في تطبيق الأدمن:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 20),

                        // حقل إدخال الكود
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _scannedCode != null
                                  ? Colors.green
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _codeController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                            maxLength: 6,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                letterSpacing: 8,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              counterText: '',
                            ),
                            onChanged: _onCodeChanged,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // عداد الأرقام
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_codeController.text.length}/6',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const Text(
                              'صالح لمدة 5 دقائق فقط',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // الأزرار
                        Row(
                          children: [
                            // زر إلغاء
                            Expanded(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // زر ربط الآن
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _linkWithCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'ربط الآن',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // قسم الخيارات
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildOptionCard(
                            icon: Icons.keyboard,
                            title: 'إدخال الكود',
                            subtitle: 'استخدام لوحة المفاتيح',
                            onTap: () {
                              // التركيز على حقل الإدخال
                              FocusScope.of(context).requestFocus(FocusNode());
                            },
                            isSelected: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildOptionCard(
                            icon: Icons.qr_code_scanner,
                            title: 'مسح QR Code',
                            subtitle: 'استخدام الكاميرا',
                            onTap: _scanQRCode,
                            isSelected: false,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // لوحة المفاتيح الرقمية
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildNumberPad(),
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

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
