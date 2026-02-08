import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/ui/StatCard.dart';
import 'package:rental_app/core/widgets/page_entrance.dart';
import 'package:rental_app/features/rents/presentation/ui/rent_details_page.dart';

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

	        return PageEntrance(
	          child: RefreshIndicator(
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

                const SizedBox(height: 24),

                Text(
                  'آخر 10 عقود',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (state.recentRents.isEmpty)
                  const Text('لا توجد عقود لعرضها')
                else
                  ...state.recentRents.map((r) => _RentCard(rent: r)).toList(),
	              ],
	            ),
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

class _RentCard extends StatelessWidget {
  const _RentCard({required this.rent});
  final dynamic rent;

  @override
  Widget build(BuildContext context) {
    final status = (rent.status ?? '').toString();
    final statusLabel = status == 'closed'
        ? 'مغلق'
        : status == 'cancelled'
            ? 'ملغي'
            : 'مفتوح';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('#${rent.id}'),
        ),
        title: Text('${rent.clientName ?? rent.clientId} • ${rent.equipmentName ?? rent.equipmentId}'),
        subtitle: Text('الحالة: $statusLabel   |   البداية: ${rent.startDatetime ?? '-'}'),
        trailing: Text('${(rent.totalAmount ?? 0).toStringAsFixed(2)} ر.س'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RentDetailsPage(rentId: rent.id)),
          );
        },
      ),
    );
  }
}
