import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/auth/presentation/ui/user_management_page.dart';
import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/dashboard/presentation/ui/dashboard_tab.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_app/theme/theme_bloc.dart';

import 'package:rental_app/features/dashboard/presentation/ui/DashboardDrawer%20.dart';
import 'package:rental_app/features/dashboard/presentation/ui/DashboardHome%20.dart';

import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/features/profile/profile_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  DashboardTab _currentTab = DashboardTab.home;

  late final ProfileCubit _profileCubit;

  final Map<DashboardTab, Map<String, bool>> _tabConfig = const {
    DashboardTab.home: {'appBar': true, 'drawer': true},
    DashboardTab.clients: {'appBar': false, 'drawer': false},
    DashboardTab.equipment: {'appBar': false, 'drawer': false},
    DashboardTab.rents: {'appBar': false, 'drawer': false},
    DashboardTab.payments: {'appBar': false, 'drawer': false},
    DashboardTab.reports: {'appBar': false, 'drawer': false},
    DashboardTab.users: {'appBar': false, 'drawer': false},
  };

  @override
  void initState() {
    super.initState();

    // ننشئ ProfileCubit مرة واحدة فقط
    final api = context.read<ApiClient>().dio;
    _profileCubit = ProfileCubit(
      repo: ProfileRepository(api),
      storage: TokenStorage(),
    )..load();
  }

  @override
  void dispose() {
    _profileCubit.close();
    super.dispose();
  }

  void _changeTab(DashboardTab tab) => setState(() => _currentTab = tab);

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    // لو لم يكن مسجل دخول، لا نعرض شيء (main/router يتكفل)
    if (authState.status != AuthStatus.authenticated) {
      return const SizedBox.shrink();
    }

    final currentConfig = _tabConfig[_currentTab]!;

    return BlocProvider.value(
      value: _profileCubit,
      child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, pstate) {
          final userName = (pstate is ProfileLoaded)
              ? (pstate.user['username'] ?? 'مستخدم').toString()
              : '...';

          final isAdmin = (pstate is ProfileLoaded)
              ? (pstate.user['role']?.toString() == 'admin')
              : false;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return Scaffold(
                appBar: currentConfig['appBar']!
                    ? CustomAppBar(
                        title: 'لوحة التحكم',
                        leading: Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        actions: [
                          // تبديل الوضع
                          IconButton(
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
                            onPressed: () =>
                                context.read<ThemeBloc>().add(ThemeToggled()),
                          ),

                          // تغيير كلمة المرور
                          IconButton(
                            tooltip: 'تغيير كلمة المرور',
                            icon: const Icon(Icons.lock_reset),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ChangePasswordPage(),
                                ),
                              );
                            },
                          ),

                          // تسجيل خروج
                          IconButton(
                            tooltip: 'تسجيل الخروج',
                            icon: const Icon(Icons.logout),
                            onPressed: () =>
                                context.read<AuthBloc>().add(LogoutRequested()),
                          ),
                        ],
                      )
                    : null,

                drawer: (!isWide && currentConfig['drawer']!)
                    ? DashboardDrawer(isAdmin: isAdmin, userName: userName)
                    : null,

                body: isWide
                    ? Row(
                        children: [
                          _buildRail(),
                          const VerticalDivider(width: 1),
                          Expanded(child: _buildBody(isAdmin, userName)),
                        ],
                      )
                    : _buildBody(isAdmin, userName),

                floatingActionButton: FloatingActionButton(
                  heroTag: 'dashboard_fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClientsPage()),
                    );
                  },
                  child: const Icon(Icons.person),
                ),

                floatingActionButtonLocation: isWide
                    ? FloatingActionButtonLocation.endFloat
                    : FloatingActionButtonLocation.centerDocked,

                bottomNavigationBar: isWide ? null : _buildBottomNav(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRail() {
    final railTabs = [
      DashboardTab.home,
      DashboardTab.equipment,
      DashboardTab.rents,
      DashboardTab.payments,
      DashboardTab.reports,
    ];

    final idx = railTabs.indexOf(_currentTab);

    return NavigationRail(
      selectedIndex: idx < 0 ? 0 : idx,
      onDestinationSelected: (i) => _changeTab(railTabs[i]),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home),
          label: Text('الرئيسية'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings),
          label: Text('المعدات'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.wallet),
          label: Text('العقود'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.payment),
          label: Text('المدفوعات'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.assessment),
          label: Text('التقارير'),
        ),
      ],
    );
  }

  Widget _buildBody(bool isAdmin, String userName) {
    switch (_currentTab) {
      case DashboardTab.home:
        return DashboardHome(isAdmin: isAdmin, userName: userName);
      case DashboardTab.clients:
        return const ClientsPage();
      case DashboardTab.equipment:
        return const EquipmentPage();
      case DashboardTab.rents:
        return const RentsPage();
      case DashboardTab.payments:
        return const PaymentsPage();
      case DashboardTab.reports:
        return const ReportsPage();
      case DashboardTab.users:
        return const UserManagementPage();
    }
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: Colors.blue,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home, DashboardTab.home),
            _navItem(Icons.settings, DashboardTab.equipment),
            const SizedBox(width: 40),
            _navItem(Icons.wallet, DashboardTab.rents),
            _navItem(Icons.payment, DashboardTab.payments),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, DashboardTab tab) {
    final isActive = _currentTab == tab;
    return IconButton(
      icon: Icon(icon, color: isActive ? Colors.black : Colors.white),
      onPressed: () => _changeTab(tab),
    );
  }
}
