import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';

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
    return Provider<HostRepository>.value(
      value: hostRepository,
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
