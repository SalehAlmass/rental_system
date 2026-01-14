import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/auth/presentation/ui/CreateUserPage.dart';
import 'package:rental_app/features/auth/presentation/ui/ForgotPasswordPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController(text: 'admin123');
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال اسم المستخدم';
    }
    // Check if the field contains only numbers (not allowed for username)
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return 'اسم المستخدم لا يمكن أن يكون أرقام فقط';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرجاء إدخال كلمة المرور';
    }
    if (value.length < 5) {
      return 'كلمة المرور يجب أن تكون على الأقل 5 أحرف';
    }
    return null;
  }

  // Generic validation function that can be used for other fields
  String? _validateField(String? value, {bool isNumber = false, bool isRequired = true, int minLength = 0}) {
    if (isRequired && (value == null || value.isEmpty)) {
      return 'الرجاء إدخال قيمة';
    }
    
    if (value != null && value.isNotEmpty) {
      if (isNumber && !RegExp(r'^\d+$').hasMatch(value)) {
        return 'الرجاء إدخال أرقام فقط';
      }
      
      if (!isNumber && RegExp(r'^\d+$').hasMatch(value)) {
        return 'الحقل لا يمكن أن يكون أرقام فقط';
      }
      
      if (minLength > 0 && value.length < minLength) {
        return 'القيمة يجب أن تحتوي على ${minLength} أحرف على الأقل';
      }
    }
    
    return null;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 100, color: Colors.white),
                  const SizedBox(height: 24),
                  const Text(
                    'نظام التأجير',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: BlocConsumer<AuthBloc, AuthState>(
                        listener: (context, state) {
                          if (state.status == AuthStatus.failure &&
                              state.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(state.error!)),
                            );
                          }
                        },
                        builder: (context, state) {
                          final loading = state.status == AuthStatus.loading;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _userCtrl,
                                      validator: _validateUsername,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم المستخدم',
                                        prefixIcon: Icon(Icons.person),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscure,
                                      validator: _validatePassword,
                                      decoration: InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: const Icon(Icons.lock),
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                          ),
                                          onPressed: () =>
                                              setState(() => _obscure = !_obscure),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.blueAccent,
                                ),
                                onPressed: loading
                                    ? null
                                    : () {
                                      if (_formKey.currentState!.validate()) {
                                        context.read<AuthBloc>().add(
                                          LoginSubmitted(
                                            username: _userCtrl.text.trim(),
                                            password: _passCtrl.text.trim(),
                                          ),
                                        );
                                      }
                                    },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // زر إنشاء مستخدم يظهر فقط للـ admin
                              Builder(
                                builder: (context) {
                                  final authState = context
                                      .read<AuthBloc>()
                                      .state;
                                  final isAdmin =
                                      authState.user?['role'] == 'admin';

                                  return isAdmin
                                      ? TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const CreateUserPage(),
                                              ),
                                            );
                                          },
                                          child: const Text('إنشاء مستخدم؟'),
                                        )
                                      : const SizedBox.shrink();
                                },
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'نسيت كلمة المرور؟',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          );
                        },
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
