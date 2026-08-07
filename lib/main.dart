import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/network/supabase_client.dart';
import 'core/utils/notification_service.dart';
import 'core/utils/user_cache_guard.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/energy_repository.dart';
import 'data/repositories/meter_repository.dart';
import 'presentation/auth_bloc/auth_bloc.dart';
import 'presentation/bloc/energy_bloc.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/main_navigation_hub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    debugPrint('=== RENDER ERROR === ${details.exception}');
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please restart the app. If the problem persists, contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  await dotenv.load(fileName: '.env');

  try {
    await SupabaseClientManager.initialize();
  } catch (_) {}

  await NotificationService.instance.initialize();

  final repository = EnergyRepository();

  runApp(EmsApp(repository: repository));
}

class EmsApp extends StatefulWidget {
  final EnergyRepository repository;

  const EmsApp({super.key, required this.repository});

  @override
  State<EmsApp> createState() => _EmsAppState();
}

class _EmsAppState extends State<EmsApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<EnergyRepository>.value(value: widget.repository),
        RepositoryProvider<MeterRepository>(create: (_) => MeterRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
          BlocProvider<EnergyBloc>(
            create: (_) => EnergyBloc(
              repository: widget.repository,
              meterRepository: MeterRepository(),
            ),
          ),
        ],
        child: _AppEntry(themeMode: _themeMode, onToggleTheme: _toggleTheme),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const _AppEntry({required this.themeMode, required this.onToggleTheme});

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AppAuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PowerEMS — Energy Management System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeMode,
      home: UserCacheGuard(
        child: BlocBuilder<AuthBloc, AppAuthState>(
          builder: (context, state) {
            return switch (state) {
              AppAuthInitial() ||
              AppAuthLoading() ||
              AppAuthUnauthenticated() ||
              AppAuthRegisterSuccess() ||
              AppAuthPasswordResetSent() ||
              AppAuthError _ => const LoginPage(),
              AppAuthAuthenticated() => MainNavigationHub(
                onToggleTheme: widget.onToggleTheme,
                isDark: widget.themeMode == ThemeMode.dark,
              ),
            };
          },
        ),
      ),
    );
  }
}
