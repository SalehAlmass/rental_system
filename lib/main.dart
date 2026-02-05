import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rental_app/core/network/api_client.dart';
import 'package:rental_app/core/storage/token_storage.dart';
import 'package:rental_app/features/profile/profile_cubit.dart';
import 'package:rental_app/features/profile/profile_repository.dart';

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
          BlocProvider<ProfileCubit>(
            create: (ctx) => ProfileCubit(
              repo: ProfileRepository(ctx.read<ApiClient>().dio),
              storage: ctx.read<TokenStorage>(), // إذا عندك TokenStorage كمزوّد
            )..load(),
          ),
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
                  seedColor: const Color(0xFF0F766E), // Professional teal green
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: const Color(
                  0xFFF1F5F9,
                ), // Light gray background
                cardTheme: CardThemeData(
                  elevation: 3,
                  color: Colors.white,
                  shadowColor: Colors.black.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                  ),
                  margin: const EdgeInsets.all(8),
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Color(0xFF0F766E), // Professional teal green
                  foregroundColor: Colors.white,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  hoverColor: const Color(0xEFE1E5E9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF0F766E), width: 2),
                  ),
                ),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                  },
                ),
              ),

              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(
                    0xFF0D9488,
                  ), // Lighter teal for dark mode
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(
                  0xFF0F172A,
                ), // Dark blue-gray
                cardTheme: CardThemeData(
                  elevation: 3,
                  color: Color(0xFF1E293B), // Darker card color
                  shadowColor: Colors.black.withOpacity(0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade600, width: 0.5),
                  ),
                  margin: const EdgeInsets.all(8),
                ),
                appBarTheme: const AppBarTheme(
                  centerTitle: true,
                  elevation: 0,
                  backgroundColor: Color(0xFF0D9488), // Teal for dark app bar
                  foregroundColor: Colors.white,
                  titleTextStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  hoverColor: const Color(0xFF334155),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade500),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade500),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF0D9488), width: 2),
                  ),
                ),
                pageTransitionsTheme: const PageTransitionsTheme(
                  builders: {
                    TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                    TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                  },
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
