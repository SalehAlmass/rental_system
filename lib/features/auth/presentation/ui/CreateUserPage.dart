import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _role = 'employee';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthBloc>().state;
    if (auth.user?['role'] != 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('غير مصرح لك بالدخول')),
        );
      });
    }
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
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Center(
          child: Text('إنشاء مستخدم جديد',
              style: TextStyle(color: Colors.white)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                  const Icon( 
                    Icons.person_add,
                    size: 100,
                    color: Colors.white,
                  ),
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

                  // بطاقة إنشاء مستخدم
                  Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: BlocConsumer<AuthBloc, AuthState>(
                        listener: (context, state) {
                          if (state.status == AuthStatus.failure &&
                              state.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(state.error!)));
                          }

                          if (state.status == AuthStatus.initial) {
                            // بعد التسجيل بنجاح نعتبر الحالة initial
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تم إنشاء المستخدم بنجاح')),
                            );
                            Navigator.pop(context);
                          }
                        },
                        builder: (context, state) {
                          final loading = state.status == AuthStatus.loading;

                          return Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _userCtrl,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال اسم المستخدم';
                                    }
                                    // Check if the field contains only numbers (not allowed for username)
                                    if (RegExp(r'^\d+$').hasMatch(value)) {
                                      return 'اسم المستخدم لا يمكن أن يكون أرقام فقط';
                                    }
                                    return null;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'اسم المستخدم',
                                    prefixIcon: Icon(Icons.person),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passCtrl,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال كلمة المرور';
                                    }
                                    if (value.length < 5) {
                                      return 'كلمة المرور يجب أن تكون على الأقل 5 أحرف';
                                    }
                                    return null;
                                  },
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'كلمة المرور',
                                    prefixIcon: Icon(Icons.lock),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _role,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'employee', child: Text('موظف')),
                                    DropdownMenuItem(
                                        value: 'admin', child: Text('مدير')),
                                  ],
                                  onChanged: (v) => setState(() => _role = v!),
                                  decoration:
                                      const InputDecoration(labelText: 'الصلاحية'),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    backgroundColor: Colors.blueAccent,
                                  ),
                                  onPressed: loading
                                      ? null
                                      : () {
                                        if (_formKey.currentState!.validate()) {
                                          context.read<AuthBloc>().add(
                                                RegisterSubmitted(
                                                  username: _userCtrl.text.trim(),
                                                  password: _passCtrl.text.trim(),
                                                  role: _role,
                                                ),
                                              );
                                        }
                                      },
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 300),
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
                                            'إنشاء المستخدم',
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
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
