// lib/src/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  static const routeName = '/auth-screen';
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSignIn = true;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthAction() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    String? error;
    if (_isSignIn) {
      error = await authService.signIn(email: email, password: password);
    } else {
      if (password != _confirmPasswordController.text.trim()) {
        _showSnackBar('كلمة المرور وتأكيدها غير متطابقين.', Colors.orange);
        return;
      }
      error = await authService.signUp(email: email, password: password);
    }

    if (!mounted) return;

    // ✅ الحل: لا نستدعي الـ SnackBar إلا إذا كان هناك خطأ بالفعل (error != null)
    if (error != null) {
      _showSnackBar(error, Colors.red);
    } else {
      // إذا كان الخطأ null، فهذا يعني نجاح العملية
      _showSnackBar(
          _isSignIn ? 'تم تسجيل الدخول بنجاح' : 'تم إنشاء الحساب بنجاح',
          Colors.green);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar(); // إخفاء الـ SnackBar الحالي إن وجد
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating, // جعل شكل الرسالة عائم وأكثر عصرية
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // مراقبة حالة التحميل من AuthService
    final authLoading = context.watch<AuthService>().state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignIn ? 'تسجيل الدخول' : 'إنشاء حساب'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email)),
                  enabled: !authLoading,
                  validator: (value) => (value == null || !value.contains('@'))
                      ? 'بريد إلكتروني غير صالح'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                  ),
                  enabled: !authLoading,
                  validator: (value) => (value == null || value.length < 6)
                      ? '6 أحرف على الأقل'
                      : null,
                ),
                if (!_isSignIn) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_isPasswordVisible,
                    decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock)),
                    enabled: !authLoading,
                    validator: (value) => value != _passwordController.text
                        ? 'لا يوجد تطابق في كلمة المرور'
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: authLoading ? null : _handleAuthAction,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: authLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : Text(_isSignIn ? 'تسجيل الدخول' : 'إنشاء حساب',
                          style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: authLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignIn = !_isSignIn;
                            _formKey.currentState?.reset();
                            _passwordController.clear();
                            _confirmPasswordController.clear();
                            _emailController.clear();
                          });
                        },
                  child: Text(_isSignIn
                      ? 'ليس لديك حساب؟ إنشاء حساب جديد'
                      : 'لديك حساب بالفعل؟ تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
