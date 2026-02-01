import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';

import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/user_management_page.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';

import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_app/features/shifts/presentation/ui/shifts_page.dart';

import 'package:rental_app/features/settings/presentation/about_page.dart';
import 'package:rental_app/features/settings/presentation/api_settings_page.dart';

import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';

import 'package:rental_app/theme/theme_bloc.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    // Extract isAdmin from AuthState based on the actual structure
    final bool isAdmin = false; // Placeholder - adjust based on actual AuthState structure

    return Scaffold(
      appBar: CustomAppBar(
        title: 'الإعدادات',
        centerTitle: true,
        showShadow: true,
      ),
      body: ListView(
        children: [
          _header(context, 'التنقل السريع'),
          _tile(
            context,
            icon: Icons.people,
            title: 'العملاء',
            subtitle: 'إدارة بيانات العملاء',
            onTap: () => _push(context, const ClientsPage()),
          ),
          _tile(
            context,
            icon: Icons.construction,
            title: 'المعدات',
            subtitle: 'إدارة المعدات المتاحة',
            onTap: () => _push(context, const EquipmentPage()),
          ),
          _tile(
            context,
            icon: Icons.description,
            title: 'العقود',
            subtitle: 'إدارة عقود الإيجار',
            onTap: () => _push(context, const RentsPage()),
          ),
          _tile(
            context,
            icon: Icons.payments,
            title: 'السندات',
            subtitle: 'سندات القبض والصرف',
            onTap: () => _push(context, const PaymentsPage()),
          ),
          _tile(
            context,
            icon: Icons.assessment,
            title: 'التقارير',
            subtitle: 'عرض التقارير والإحصائيات',
            onTap: () => _push(context, const ReportsPage()),
          ),
          _tile(
            context,
            icon: Icons.lock_clock,
            title: 'إغلاق الدوام',
            subtitle: 'إدارة شفتات الموظفين',
            onTap: () => _push(context, const ShiftsPage()),
          ),

          const Divider(height: 28),

          _header(context, 'عام'),
          _tile(
            context,
            icon: Icons.info_outline,
            title: 'عن النظام',
            subtitle: 'معلومات التطبيق والإصدار',
            onTap: () => _push(context, const AboutPage()),
          ),

          const Divider(height: 28),

          _header(context, 'الاتصال بالسيرفر'),
          _tile(
            context,
            icon: Icons.api,
            title: 'إعدادات الـ API',
            subtitle: 'تعديل رابط الاتصال',
            onTap: () => _push(context, const ApiSettingsPage()),
          ),

          if (isAdmin) ...[
            const Divider(height: 28),
            _header(context, 'الإدارة'),
            _tile(
              context,
              icon: Icons.supervised_user_circle,
              title: 'إدارة المستخدمين',
              subtitle: 'إضافة/تعديل/تعطيل المستخدمين',
              onTap: () => _push(context, const UserManagementPage()),
            ),
          ],

          const Divider(height: 28),

          _header(context, 'الحساب'),
          _tile(
            context,
            icon: Icons.lock_reset,
            title: 'تغيير كلمة المرور',
            subtitle: 'تغيير كلمة المرور الحالية',
            onTap: () => _push(context, const ChangePasswordPage()),
          ),
          _tile(
            context,
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            subtitle: 'الخروج من الحساب الحالي',
            trailing: const Icon(Icons.logout, color: Colors.red),
            onTap: () => _logout(context),
          ),

          const Divider(height: 28),

          _header(context, 'المظهر'),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, themeState) {
              final isDark = themeState.mode == ThemeMode.dark;
              return _tile(
                context,
                icon: isDark ? Icons.dark_mode : Icons.light_mode,
                title: 'الوضع الليلي',
                subtitle: isDark ? 'مفعّل' : 'غير مفعّل',
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) => context.read<ThemeBloc>().add(ThemeToggled()),
                ),
                onTap: () => context.read<ThemeBloc>().add(ThemeToggled()),
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!context.mounted) return;
    context.read<DashboardBloc>().add(DashboardRequested());
  }

  void _logout(BuildContext context) {
    // ✅ لا تعتمد على pop فقط
    context.read<AuthBloc>().add(LogoutRequested());
  }
}
