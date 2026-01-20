import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الملف الشخصي'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<ProfileCubit>().refresh(),
            ),
          ],
        ),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading || state is ProfileInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileError) {
              return _ErrorView(
                message: state.message,
                onRetry: () => context.read<ProfileCubit>().load(),
              );
            }

            if (state is ProfileLoaded) {
              final u = state.user;
              final username = (u['username'] ?? '').toString();
              final role = (u['role'] ?? '').toString();
              final createdAt = (u['created_at'] ?? '').toString();
              final isActive = u['is_active'] == null
                  ? null
                  : (u['is_active'].toString() == '1' || u['is_active'] == true);

              return RefreshIndicator(
                onRefresh: () => context.read<ProfileCubit>().refresh(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderCard(username: username, role: role),

                    const SizedBox(height: 16),

                    _InfoCard(
                      title: 'معلومات الحساب',
                      items: [
                        _InfoRow(label: 'اسم المستخدم', value: username),
                        _InfoRow(
                          label: 'الصلاحية',
                          value: role == 'admin' ? 'مدير النظام' : 'موظف',
                        ),
                        if (createdAt.isNotEmpty)
                          _InfoRow(label: 'تاريخ الإنشاء', value: createdAt),
                        if (isActive != null)
                          _InfoRow(
                            label: 'الحالة',
                            value: isActive ? 'نشط' : 'موقوف',
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _ActionCard(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_reset),
                          title: const Text('تغيير كلمة المرور'),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('تسجيل الخروج'),
                          onTap: () {
                            context.read<AuthBloc>().add(LogoutRequested());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String username;
  final String role;

  const _HeaderCard({required this.username, required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username.isEmpty ? 'مستخدم' : username,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin ? 'مدير النظام' : 'موظف',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> items;

  const _InfoCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          e.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(e.value),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final List<Widget> children;

  const _ActionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}
