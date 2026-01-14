import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/ui/login_page.dart';

import 'features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'features/dashboard/presentation/ui/dashboard_page.dart';

import 'theme/theme_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);

  runApp(AppRoot(tokenStorage: tokenStorage, apiClient: apiClient));
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key, required this.tokenStorage, required this.apiClient});

  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: apiClient),
        RepositoryProvider(create: (_) => AuthRepository(apiClient, tokenStorage)),
        RepositoryProvider(create: (_) => DashboardRepository(apiClient)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => AuthBloc(ctx.read<AuthRepository>())),
          BlocProvider(create: (_) => ThemeBloc()),

          // ✅ هذا المهم: DashboardBloc عالمي ويعمل fetch أول ما يفتح
          BlocProvider(
            create: (ctx) => DashboardBloc(ctx.read<DashboardRepository>())
              ..add(DashboardRequested()),
          ),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Rental System',
              themeMode: themeState.mode,
              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                primarySwatch: Colors.blue,
              ),
              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                primarySwatch: Colors.blue,
              ),
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state.status == AuthStatus.authenticated) {
                    return const DashboardPage();
                  }
                  return const LoginPage();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
