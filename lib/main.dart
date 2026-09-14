import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'auth/app_lock_controller.dart';
import 'auth/auth_service.dart';
import 'data/db_repository.dart';
import 'data/host_repository.dart';
import 'data/settings_repository.dart';
import 'screens/host_list_screen.dart';
import 'screens/lock_screen.dart';
import 'session/db_session_manager.dart';
import 'session/session_manager.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final hostRepository = HostRepository();
  await hostRepository.init();

  final dbRepository = DbRepository();
  await dbRepository.init();

  final settingsRepository = SettingsRepository();
  await settingsRepository.init();

  runApp(
    TermulApp(
      hostRepository: hostRepository,
      dbRepository: dbRepository,
      settingsRepository: settingsRepository,
    ),
  );
}

class TermulApp extends StatelessWidget {
  final HostRepository hostRepository;
  final DbRepository dbRepository;
  final SettingsRepository settingsRepository;

  const TermulApp({
    super.key,
    required this.hostRepository,
    required this.dbRepository,
    required this.settingsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HostRepository>.value(value: hostRepository),
        Provider<DbRepository>.value(value: dbRepository),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<SessionManager>(
          create: (_) => SessionManager(),
        ),
        ChangeNotifierProvider<DbSessionManager>(
          create: (_) => DbSessionManager(),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(settingsRepository),
        ),
        ChangeNotifierProvider<AppLockController>(
          create: (_) => AppLockController(settingsRepository),
        ),
      ],
      child: const _AppView(),
    );
  }
}

/// Separated from [TermulApp] so it can watch [ThemeController] (declared by
/// the [MultiProvider] just above it) and rebuild [MaterialApp] when the
/// theme preset changes.
class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final seedColor = context.watch<ThemeController>().preset.seedColor;
    final lockController = context.watch<AppLockController>();
    return MaterialApp(
      title: 'Termul',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(seedColor),
      darkTheme: AppTheme.dark(seedColor),
      themeMode: ThemeMode.dark,
      // Any touch anywhere in the app counts as activity, postponing the
      // idle-timeout lock - this only observes pointer events (translucent
      // hit-testing), it never intercepts them from the actual widgets.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => lockController.registerActivity(),
        child: child!,
      ),
      home: lockController.locked
          ? const LockScreen()
          : const HostListScreen(),
    );
  }
}
