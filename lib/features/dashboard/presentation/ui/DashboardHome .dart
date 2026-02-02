import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/ui/StatCard.dart';

class DashboardHome extends StatelessWidget {
  final bool isAdmin;
  final String userName;

  const DashboardHome({
    required this.isAdmin,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state.status == DashboardStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == DashboardStatus.failure) {
          return Center(child: Text(state.error ?? 'حدث خطأ'));
        }

        final stats = state.stats;
        if (stats == null) {
          return const Center(child: Text('لا توجد بيانات'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<DashboardBloc>().add(DashboardRequested());
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(context, userName, isAdmin),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final crossAxisCount = w >= 1100
                      ? 4
                      : w >= 800
                          ? 3
                          : w >= 500
                              ? 2
                              : 1;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      StatCard(
                        title: 'عدد العملاء',
                        value: stats.clients.toString(),
                        icon: Icons.people,
                      ),
                      StatCard(
                        title: 'عدد المعدات',
                        value: stats.equipment.toString(),
                        icon: Icons.construction,
                      ),
                      StatCard(
                        title: 'العقود المفتوحة',
                        value: stats.openRents.toString(),
                        icon: Icons.description,
                      ),
                      StatCard(
                        title: 'الإيراد',
                        value: stats.revenue.toStringAsFixed(2),
                        icon: Icons.attach_money,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String userName, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primary,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $userName 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin ? 'مدير النظام' : 'موظف',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              context.read<DashboardBloc>().add(DashboardRequested());
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
