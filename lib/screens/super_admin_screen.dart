import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _factoryNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _factoryNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createNewFactory() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        debugPrint('🔥 جاري إرسال الطلب إلى الدالة السحابية...');
        await Supabase.instance.client.functions.invoke(
          'create_factory_admin',
          body: {
            'factoryName': _factoryNameController.text.trim(),
            'adminEmail': _adminEmailController.text.trim(),
            'adminPassword': _adminPasswordController.text,
          },
        );

        debugPrint('✅ تم تنفيذ الطلب بنجاح!');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إنشاء المصنع وحساب المدير بنجاح"),
            backgroundColor: Colors.green,
          ),
        );

        _factoryNameController.clear();
        _adminEmailController.clear();
        _adminPasswordController.clear();
      } on FunctionException catch (e) {
        debugPrint('❌ FunctionException Caught!');
        debugPrint('تفاصيل الخطأ (Details): ${e.details}');
        debugPrint('حالة الرد (Reason): ${e.reasonPhrase}');

        if (!mounted) return;
        
        String errorMessage = 'حدث خطأ غير متوقع';
        if (e.details is Map && (e.details as Map).containsKey('error')) {
          errorMessage = (e.details as Map)['error'].toString();
        } else if (e.details != null) {
          errorMessage = e.details.toString();
        } else if (e.reasonPhrase != null) {
          errorMessage = e.reasonPhrase!;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("فشل: $errorMessage"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      } catch (e) {
        debugPrint('❌ General Error Caught: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
        title: const Text("لوحة تحكم النظام (Super Admin)"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings,
                          size: 64, color: Colors.red[800]),
                      const SizedBox(height: 16),
                      const Text(
                        "إضافة مصنع جديد",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _factoryNameController,
                        decoration: const InputDecoration(
                          labelText: "اسم المصنع",
                          prefixIcon: Icon(Icons.factory),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال اسم المصنع';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: "البريد الإلكتروني لمدير المصنع",
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال البريد الإلكتروني';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'الرجاء إدخال بريد إلكتروني صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _adminPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "كلمة المرور المؤقتة",
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'الرجاء إدخال كلمة المرور';
                          }
                          if (value.length < 6) {
                            return 'كلمة المرور يجب أن لا تقل عن 6 أحرف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoading ? null : _createNewFactory,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "إنشاء المصنع وحساب المدير",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
