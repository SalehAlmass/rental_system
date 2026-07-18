import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import 'package:rental_app/core/widgets/permission_guard.dart';
import 'package:rental_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rental_app/features/auth/presentation/ui/ChangePasswordPage.dart';
import 'package:rental_app/features/clients/presentation/ui/clients_page.dart';
import 'package:rental_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:rental_app/features/dashboard/presentation/ui/dashboard_home.dart';
import 'package:rental_app/features/dashboard/presentation/ui/dashboard_tab.dart';
import 'package:rental_app/features/equipment/presentation/ui/equipment_page.dart';
import 'package:rental_app/features/payments/presentation/ui/payments_page.dart';
import 'package:rental_app/features/rents/presentation/ui/rents_page.dart';
import 'package:rental_app/features/settings/presentation/settings_page.dart';
import 'package:rental_app/features/shifts/presentation/ui/shifts_page.dart';
import 'package:rental_app/theme/theme_bloc.dart';



import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/features/backup/data/backup_repository.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => DashboardPageState();
}

class DashboardPageState extends State<DashboardPage> {
  DashboardTab _currentTab = DashboardTab.home;

  bool _checkedAutoBackup = false;
  String _rentsFilter = 'open';

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

    context.read<DashboardBloc>().add(DashboardRequested());
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _changeTab(DashboardTab tab) {
    setState(() {
      _currentTab = tab;
      if (tab != DashboardTab.rents) {
        _rentsFilter = 'open';
      }
    });
  }

  void _openRentsWithFilter(String filter) {
    setState(() {
      _rentsFilter = filter;
      _currentTab = DashboardTab.rents;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;

    if (authState.status != AuthStatus.authenticated) {
      return const SizedBox.shrink();
    }

    final currentConfig =
        _tabConfig[_currentTab] ?? {'appBar': true, 'drawer': true};

    return BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, pstate) {
          final userName = (pstate is ProfileLoaded)
              ? (pstate.user['username'] ?? 'مستخدم').toString()
              : '...';

          final isAdmin = (pstate is ProfileLoaded)
              ? (pstate.user['role']?.toString() == 'admin')
              : false;

          // Automatic fallback if current tab is not allowed
          if (pstate is ProfileLoaded) {
            final showDashboard = pstate.hasScreenPermission('dashboard');
            final showEquipment = pstate.hasScreenPermission('equipment');
            final showShifts = pstate.hasScreenPermission('shifts');
            final showRents = pstate.hasScreenPermission('rents');
            final showSettings = pstate.hasScreenPermission('settings');

            final allowedTabs = <DashboardTab>[];
            if (showDashboard) allowedTabs.add(DashboardTab.home);
            if (showEquipment || showShifts) allowedTabs.add(DashboardTab.equipment);
            if (showRents) allowedTabs.add(DashboardTab.rents);
            if (showSettings) allowedTabs.add(DashboardTab.settings);

            if (allowedTabs.isNotEmpty && !allowedTabs.contains(_currentTab)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _currentTab = allowedTabs.first;
                  });
                }
              });
            }
          }

          if (isAdmin && !_checkedAutoBackup) {
            _checkedAutoBackup = true;
            _tryAutoBackup(context);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Scaffold(
                appBar: currentConfig['appBar'] == true
                    ? CustomAppBar(
                        title: 'لوحة التحكم',
                        showShadow: true,
                        centerTitle: true,
                        actions: [
                          if (isAdmin)
                            IconButton(
                              tooltip: 'حذف كل بيانات التشغيل',
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              onPressed: _confirmClearBusinessData,
                            ),

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

                          IconButton(
                            tooltip: 'تسجيل الخروج',
                            icon: const Icon(Icons.logout),
                            onPressed: () =>
                                context.read<AuthBloc>().add(LogoutRequested()),
                          ),
                        ],
                      )
                    : null,

                body: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.02, 0.02),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_currentTab),
                    child: _buildBody(isAdmin, userName, pstate),
                  ),
                ),

                floatingActionButton: PermissionGuard(
                  permissionKey: 'clients',
                  child: FloatingActionButton(
                    heroTag: 'dashboard_fab',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClientsPage()),
                      );
                    },
                    child: const Icon(Icons.person),
                  ),
                ),

                floatingActionButtonLocation:
                    FloatingActionButtonLocation.centerDocked,

                bottomNavigationBar: _buildBottomNav(isAdmin, pstate),
              );
            },
          );
        },
      );
  }

  Future<void> _confirmClearBusinessData() async {
    final textCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('حذف كل بيانات التشغيل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيتم حذف العملاء والمعدات والعقود والسندات والحضور والتنبيهات، مع إبقاء المستخدمين والإعدادات حتى تستطيع الدخول للنظام.',
            ),
            const SizedBox(height: 12),
            const Text('للتأكيد اكتب مسح'),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'مسح',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, textCtrl.text.trim() == 'مسح'),
            icon: const Icon(Icons.delete_forever),
            label: const Text('حذف البيانات'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await context.read<ApiClient>().dio.delete(
        'maintenance/clear-business-data',
        data: {'confirm': 'CLEAR'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف بيانات التشغيل بنجاح')),
      );
      context.read<DashboardBloc>().add(DashboardRequested());
      setState(() {
        _currentTab = DashboardTab.home;
        _rentsFilter = 'all';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حذف البيانات: $e')),
      );
    }
  }

  Future<void> _tryAutoBackup(BuildContext context) async {
    try {
      final repo = BackupRepository(context.read<ApiClient>());
      final items = await repo.list();
      if (items.isEmpty) {
        await repo.create();
        return;
      }

      DateTime? parsed(String s) {
        try {
          final normalized = s.replaceAll(' ', 'T');
          return DateTime.tryParse(normalized);
        } catch (_) {
          return null;
        }
      }

      final latest = items
          .map((e) => parsed(e.createdAt))
          .whereType<DateTime>()
          .fold<DateTime?>(null, (a, b) => (a == null || b.isAfter(a)) ? b : a);

      if (latest == null) {
        await repo.create();
        return;
      }

      final diff = DateTime.now().difference(latest);
      if (diff.inHours >= 12) {
        await repo.create();
      }
    } catch (_) {}
  }

  Widget _buildBody(bool isAdmin, String userName, ProfileState pstate) {
    switch (_currentTab) {
      case DashboardTab.home:
        return PermissionGuard(
          permissionKey: 'dashboard',
          fallback: const Center(child: Text('غير مصرح لك بالوصول إلى الرئيسية')),
          child: DashboardHome(
            isAdmin: isAdmin,
            userName: userName,
            onOpenRents: () => _openRentsWithFilter('open'),
            onOpenRentsWithFilter: _openRentsWithFilter,
            onOpenClients: () => _changeTab(DashboardTab.clients),
            onOpenEquipment: () => _changeTab(DashboardTab.equipment),
            onOpenPayments: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PaymentsPage()),
            ),
          ),
        );
      case DashboardTab.clients:
        return const PermissionGuard(
          permissionKey: 'clients',
          fallback: Center(child: Text('غير مصرح لك بالوصول إلى العملاء')),
          child: ClientsPage(),
        );
      case DashboardTab.equipment:
        final showEquipment = pstate.hasScreenPermission('equipment');
        if (showEquipment) {
          return const PermissionGuard(
            permissionKey: 'equipment',
            fallback: Center(child: Text('غير مصرح لك بالوصول إلى المعدات')),
            child: EquipmentPage(),
          );
        } else {
          return const PermissionGuard(
            permissionKey: 'shifts',
            fallback: Center(child: Text('غير مصرح لك بالوصول إلى إغلاق الدوام')),
            child: ShiftsPage(),
          );
        }
      case DashboardTab.rents:
        return PermissionGuard(
          permissionKey: 'rents',
          fallback: const Center(child: Text('غير مصرح لك بالوصول إلى العقود')),
          child: RentsPage(initialFilter: _rentsFilter),
        );
      case DashboardTab.settings:
        return PermissionGuard(
          permissionKey: 'settings',
          fallback: const Center(child: Text('غير مصرح لك بالوصول إلى الإعدادات')),
          child: SettingsPage(isAdmin: isAdmin),
        );
    }
  }

  Widget _buildBottomNav(bool isAdmin, ProfileState pstate) {
    final showDashboard = pstate.hasScreenPermission('dashboard');
    final showEquipment = pstate.hasScreenPermission('equipment');
    final showShifts = pstate.hasScreenPermission('shifts');
    final showRents = pstate.hasScreenPermission('rents');
    final showSettings = pstate.hasScreenPermission('settings');

    final navTabs = <DashboardTab>[];
    if (showDashboard) navTabs.add(DashboardTab.home);
    if (showEquipment || showShifts) navTabs.add(DashboardTab.equipment);
    if (showRents) navTabs.add(DashboardTab.rents);
    if (showSettings) navTabs.add(DashboardTab.settings);

    final idx = navTabs.indexOf(_currentTab);

    final destinations = <NavigationDestination>[];
    if (showDashboard) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'الرئيسية',
      ));
    }
    if (showEquipment || showShifts) {
      final isEquip = showEquipment;
      destinations.add(NavigationDestination(
        icon: Icon(isEquip ? Icons.construction_outlined : Icons.lock_clock_outlined),
        selectedIcon: Icon(isEquip ? Icons.construction : Icons.lock_clock),
        label: isEquip ? 'المعدات' : 'إغلاق الدوام',
      ));
    }
    if (showRents) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.wallet_outlined),
        selectedIcon: Icon(Icons.wallet),
        label: 'العقود',
      ));
    }
    if (showSettings) {
      destinations.add(const NavigationDestination(
        icon: Icon(Icons.info_outlined),
        selectedIcon: Icon(Icons.info),
        label: 'الإعدادات',
      ));
    }

    if (destinations.isEmpty) return const SizedBox.shrink();

    return NavigationBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primary,
      selectedIndex: idx < 0 ? 0 : idx,
      onDestinationSelected: (index) => _changeTab(navTabs[index]),
      destinations: destinations,
    );
  }
}
