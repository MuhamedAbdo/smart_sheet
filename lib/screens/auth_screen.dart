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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    String? error;
    if (_isSignIn) {
      error = await authService.signIn(email: email, password: password);
    } else {
      if (password != _confirmPasswordController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('كلمة المرور وتأكيدها غير متطابقين.')),
        );
        return;
      }
      error = await authService.signUp(email: email, password: password);
    }

    if (!mounted) return;

    if (error != null) {
      // ✅ حالة الخطأ: نعرض الرسالة القادمة من السيرفر
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      // ✅ حالة النجاح: error هو null
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      if (_isSignIn) {
        // العودة للشاشة السابقة عند نجاح تسجيل الدخول
        Navigator.pop(context);
      } else {
        // رسالة نجاح عند إنشاء حساب جديد
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ تم إنشاء الحساب بنجاح. يرجى تأكيد بريدك الإلكتروني لتسجيل الدخول.'),
          ),
        );
        // التبديل التلقائي لواجهة تسجيل الدخول
        setState(() {
          _isSignIn = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // نراقب الحالة فقط لمعرفة هل نحن في وضع التحميل أم لا
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
                // حقل البريد الإلكتروني
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: !authLoading,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'الرجاء إدخال بريد إلكتروني صالح.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // حقل كلمة المرور (أساسي)
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  enabled: !authLoading,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'يجب أن تكون كلمة المرور 6 أحرف على الأقل.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // حقل تأكيد كلمة المرور (يظهر فقط عند التسجيل)
                if (!_isSignIn)
                  Column(
                    children: [
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_isPasswordVisible,
                        decoration: const InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        enabled: !authLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء تأكيد كلمة المرور.';
                          }
                          if (value != _passwordController.text) {
                            return 'كلمة المرور غير متطابقة.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                const SizedBox(height: 16),

                // زر الإجراء
                ElevatedButton(
                  onPressed: authLoading ? null : _handleAuthAction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: authLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          _isSignIn ? 'تسجيل الدخول' : 'إنشاء حساب',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
                const SizedBox(height: 16),

                // زر التبديل بين الحالتين
                TextButton(
                  onPressed: authLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignIn = !_isSignIn;
                            _formKey.currentState?.reset();
                            _passwordController.clear();
                            _confirmPasswordController.clear();
                            _isPasswordVisible = false;
                          });
                        },
                  child: Text(
                    _isSignIn
                        ? 'ليس لديك حساب؟ إنشاء حساب جديد'
                        : 'لديك حساب بالفعل؟ تسجيل الدخول',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
