import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/auth/presentation/ui/user_management_page.dart';
import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/ui/dashboard_tab.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/reports/presentation/pages/reports_page.dart';
import 'package:rental_app/features/settings/presentation/about_page.dart';
import 'package:rental_app/features/settings/presentation/settings_page.dart';
import 'package:rental_app/theme/theme_bloc.dart';


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
    DashboardTab.settings: {'appBar': false, 'drawer': false},
  };

  @override
  void initState() {
    super.initState();

    // ننشئ ProfileCubit مرة واحدة فقط
    final api = context.read<ApiClient>().dio;
    final tokenStorage = context.read<TokenStorage>();
    _profileCubit = ProfileCubit(
      repo: ProfileRepository(api),
      // IMPORTANT: use the same TokenStorage instance created in main.dart
      storage: tokenStorage,
    )..load();

    // حمّل بيانات الداشبورد بعد تسجيل الدخول
    context.read<DashboardBloc>().add(DashboardRequested());
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

    final currentConfig = _tabConfig[_currentTab] ?? {'appBar': true, 'drawer': true};

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
                appBar: currentConfig['appBar'] == true
                    ? CustomAppBar(
                        title: 'لوحة التحكم',
                        showShadow: true,
                        centerTitle: true,
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

                // Drawer removed - all navigation moved to Settings page

                body: _buildBody(isAdmin, userName),

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

                floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

                bottomNavigationBar: _buildBottomNav(),
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
      DashboardTab.settings,
    ];

    final idx = railTabs.indexOf(_currentTab);

    return NavigationRail(
      backgroundColor: Theme.of(context).colorScheme.onBackground,      
      selectedIndex: idx < 0 ? 0 : idx,
      onDestinationSelected: (i) => _changeTab(railTabs[i]),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home,
          color: Colors.white,),
          label: Text('الرئيسية',
          style: TextStyle(color: Colors.white)),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings,
          color: Colors.white,),
          label: Text('المعدات',
          style: TextStyle(color: Colors.white)),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.wallet,
          color: Colors.white,),
          label: Text('العقود',
          style: TextStyle(color: Colors.white)),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.info,
          color: Colors.white,),
          label: Text('الإعدادات',
          style: TextStyle(color: Colors.white)),
        ),
        
        // NavigationRailDestination(
        //   icon: Icon(Icons.assessment),
        //   label: Text('التقارير'),
        // ),
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
      case DashboardTab.settings:
        return const SettingsPage();
      // case DashboardTab.about:
      //   return const AboutPage();
      // case DashboardTab.users:
      //   return const UserManagementPage();
      // case DashboardTab.reports:
      //   return const ReportsPage();
      // case DashboardTab.settings:
      //   return const SettingsPage();
        
    }
  }

  Widget _buildBottomNav() {
    final navTabs = [
      DashboardTab.home,
      DashboardTab.equipment,
      DashboardTab.rents,
      DashboardTab.settings,
    ];

    final idx = navTabs.indexOf(_currentTab);

    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primary,
      selectedIndex: idx < 0 ? 0 : idx,
      onDestinationSelected: (index) => _changeTab(navTabs[index]),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Icon(Icons.construction_outlined),
          selectedIcon: Icon(Icons.construction),
          label: 'المعدات',
        ),
        NavigationDestination(
          icon: Icon(Icons.wallet_outlined),
          selectedIcon: Icon(Icons.wallet),
          label: 'العقود',
        ),
        NavigationDestination(
          icon: Icon(Icons.info_outlined),
          selectedIcon: Icon(Icons.info),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}
