import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/auth/presentation/ui/CreateUserPage.dart';
import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:rental_app/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_app/theme/theme_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leading: IconButton(
          tooltip: 'تبديل الوضع',
          icon: BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return Icon(
                state.mode == ThemeMode.light
                    ? Icons.dark_mode
                    : Icons.light_mode,
              );
            },
          ),
          onPressed: () => context.read<ThemeBloc>().add(ThemeToggled()),
        ),
        title: 'لوحة التحكم',
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChangePasswordPage(),
              ),
            ),
            icon: const Icon(Icons.lock_reset),
          ),
          IconButton(
            onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state.status == DashboardStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == DashboardStatus.failure) {
            return Center(child: Text(state.error ?? 'حدث خطأ'));
          }
          final stats = state.stats;
          if (stats == null)
            return const Center(child: Text('لا توجد بيانات بعد'));

          // 👇 هنا اترك تصميمك كما هو (نفس Grid و الأزرار...)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _statCard(
                          'عدد العملاء',
                          stats.clients.toString(),
                          Icons.people,
                          Colors.blueAccent,
                        ),
                        _statCard(
                          'عدد المعدات',
                          stats.equipment.toString(),
                          Icons.construction,
                          Colors.orangeAccent,
                        ),
                        _statCard(
                          'العقود المفتوحة',
                          stats.openRents.toString(),
                          Icons.description,
                          Colors.green,
                        ),
                        _statCard(
                          'الإيراد',
                          stats.revenue.toStringAsFixed(2),
                          Icons.attach_money,
                          Colors.purpleAccent,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),
                _sectionTitle('الإدارة'),
                const SizedBox(height: 12),
                _actionButton(
                  context,
                  'إدارة العملاء',
                  Icons.people,
                  const ClientsPage(),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  context,
                  'إدارة المعدات',
                  Icons.construction,
                  const EquipmentPage(),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  context,
                  'إدارة العقود',
                  Icons.description,
                  const RentsPage(),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  context,
                  'إدارة السندات',
                  Icons.payments,
                  const PaymentsPage(),
                ),
                const SizedBox(height: 12),
                _actionButton(
                  context,
                  'إدارة التقارير',
                  Icons.report,
                  const ReportsPage(),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final authState = context.read<AuthBloc>().state;
                    final isAdmin = authState.user?['role'] == 'admin';

                    return isAdmin
                        ? _actionButton(
                            context,
                            'إدارة المستخدمين',
                            Icons.person,
                            const CreateUserPage(),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    Widget page,
  ) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          // ✅ لما ترجع من صفحة العملاء/المعدات/العقود/السندات يحدث الداشبورد
          if (context.mounted) {
            context.read<DashboardBloc>().add(DashboardRequested());
          }
        },

        icon: Icon(icon, size: 24, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
