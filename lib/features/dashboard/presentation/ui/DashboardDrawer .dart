import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/user_management_page.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';

class DashboardDrawer extends StatelessWidget {
  final bool isAdmin;
  final String userName;

  const   DashboardDrawer({
    super.key,
    required this.isAdmin,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blueAccent),
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdmin ? 'مدير النظام' : 'مستخدم',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _drawerItem(
              context,
              title: 'إدارة العملاء',
              icon: Icons.people,
              page: const ClientsPage(),
            ),
            _drawerItem(
              context,
              title: 'إدارة المعدات',
              icon: Icons.construction,
              page: const EquipmentPage(),
            ),
            _drawerItem(
              context,
              title: 'إدارة العقود',
              icon: Icons.description,
              page: const RentsPage(),
            ),
            _drawerItem(
              context,
              title: 'إدارة السندات',
              icon: Icons.payments,
              page: const PaymentsPage(),
            ),
            _drawerItem(
              context,
              title: 'التقارير',
              icon: Icons.report,
              page: const ReportsPage(),
            ),

            if (isAdmin)
              _drawerItem(
                context,
                title: 'إدارة المستخدمين',
                icon: Icons.person,
                page: const UserManagementPage(),
              ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthBloc>().add(LogoutRequested());
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('تغيير كلمة المرور'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                );
              },
            ),
          
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title),
      onTap: () async {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );

        if (context.mounted) {
          context.read<DashboardBloc>().add(DashboardRequested());
        }
      },
    );
  }
}
