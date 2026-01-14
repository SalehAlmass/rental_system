import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/reports/domain/entities/report_dashboard.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/reports_repository_impl.dart';
import '../bloc/reports_bloc.dart';
import '../bloc/reports_event.dart';
import '../bloc/reports_state.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => ReportsRepository(context.read<ApiClient>()),
      child: BlocProvider(
        create: (ctx) =>
            ReportsBloc(ctx.read<ReportsRepository>())
              ..add(ReportsDashboardRequested()),
        child: const _ReportsView(),
      ),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'التقارير',
        onIconPressed: () {
          Navigator.of(context).pop();
        },
        
      ),
      body: BlocBuilder<ReportsBloc, ReportsState>(
        builder: (context, state) {
          switch (state.status) {
            case ReportsStatus.loading:
              return const Center(child: CircularProgressIndicator());

            case ReportsStatus.failure:
              return _ErrorView(
                error: state.error ?? 'حدث خطأ غير معروف',
                onRetry: () => context.read<ReportsBloc>().add(
                  ReportsDashboardRequested(),
                ),
              );

            case ReportsStatus.success:
              final data = state.data;
              if (data == null) {
                return const Center(child: Text('لا توجد بيانات'));
              }
              return _DashboardView(data: data);

            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({required this.data});
  final ReportDashboard data;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<ReportsBloc>().add(ReportsDashboardRequested());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile(
            title: 'عدد العملاء',
            value: data.clients.toString(),
            icon: Icons.people,
          ),
          _ReportTile(
            title: 'عدد المعدات',
            value: data.equipment.toString(),
            icon: Icons.construction,
          ),
          _ReportTile(
            title: 'العقود المفتوحة',
            value: data.openRents.toString(),
            icon: Icons.assignment,
          ),
          _ReportTile(
            title: 'الإيرادات',
            value: '${data.revenue.toStringAsFixed(0)} ر.س',
            icon: Icons.attach_money,
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Icon(icon, color: Colors.blueAccent),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
