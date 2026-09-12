import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'data/host_repository.dart';
import 'screens/host_list_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final hostRepository = HostRepository();
  await hostRepository.init();

  runApp(TermulApp(hostRepository: hostRepository));
}

class TermulApp extends StatelessWidget {
  final HostRepository hostRepository;

  const TermulApp({super.key, required this.hostRepository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<HostRepository>.value(value: hostRepository),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Termul',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const HostListScreen(),
      ),
    );
  }
}
