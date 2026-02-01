import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';

import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/repositories/user_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/user_management_bloc.dart';
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
  const AppRoot({
    super.key,
    required this.tokenStorage,
    required this.apiClient,
  });

  final TokenStorage tokenStorage;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // Core singletons
        RepositoryProvider<ApiClient>.value(value: apiClient),
        RepositoryProvider<TokenStorage>.value(value: tokenStorage),

        // Feature repositories
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepository(apiClient, tokenStorage),
        ),
        RepositoryProvider<DashboardRepository>(
          create: (_) => DashboardRepository(apiClient),
        ),
        RepositoryProvider<UserRepository>(
          create: (_) => UserRepositoryImpl(apiClient),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (ctx) => AuthBloc(ctx.read<AuthRepository>()),
          ),
          BlocProvider<UserManagementBloc>(
            create: (ctx) => UserManagementBloc(ctx.read<UserRepository>()),
          ),
          BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
          // NOTE: Don't fire DashboardRequested here. It depends on the authenticated user.
          BlocProvider<DashboardBloc>(
            create: (ctx) => DashboardBloc(ctx.read<DashboardRepository>()),
          ),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Rental System',
              themeMode: themeState.mode,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('ar', 'SA'), // Arabic
                Locale('en', 'US'), // English
              ],
              locale: const Locale('ar', 'SA'), // Set Arabic as default
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2563EB),
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(0xFFF9FAFB),
                cardTheme: CardThemeData(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: EdgeInsets.zero,
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Color(0xFFEEF2FF),
                  foregroundColor: Color(0xFF1E3A8A),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2563EB),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF020617),
                cardTheme: CardThemeData(
                  elevation: 0,
                  color: const Color(0xFF020617),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: EdgeInsets.zero,
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Color(0xFF020617),
                  foregroundColor: Colors.white,
                ),
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
