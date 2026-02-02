import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _userCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسيت كلمة المرور'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
      ),),
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
              padding: const EdgeInsets.all(24),
              child: Card(
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

                      if (state.status == AuthStatus.initial) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال الطلب بنجاح'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    builder: (context, state) {
                      final loading =
                          state.status == AuthStatus.loading;

                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            const Icon(
                              Icons.lock_reset,
                              size: 80,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'نسيت كلمة المرور',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),

                            TextFormField(
                              controller: _userCtrl,
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'الرجاء إدخال اسم المستخدم';
                                }
                                return null;
                              },
                              decoration:
                                  const InputDecoration(
                                labelText: 'اسم المستخدم',
                                prefixIcon:
                                    Icon(Icons.person),
                                border:
                                    OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton(
                              onPressed: loading
                                  ? null
                                  : () {
                                      if (_formKey
                                          .currentState!
                                          .validate()) {
                                        context
                                            .read<AuthBloc>()
                                            .add(
                                              ForgotPasswordSubmitted(
                                                username:
                                                    _userCtrl
                                                        .text
                                                        .trim(),
                                              ),
                                            );
                                      }
                                    },
                              child: loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 3,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'إرسال الطلب',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.bold,
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
            ),
          ),
        ),
      ),
    );
  }
}
