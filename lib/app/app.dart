import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../screens/auth_screen.dart';
import '../screens/home_shell.dart';
import 'theme.dart';

class EcoHabitApp extends StatelessWidget {
  final AppState state;
  const EcoHabitApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
          title: 'EcoHabit',
          debugShowCheckedModeBanner: false,
          theme: ecoTheme(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Consumer<AppState>(
              builder: (_, s, child) => !s.ready
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()))
                  : s.account == null
                      ? const AuthScreen()
                      : const HomeShell())));
}
