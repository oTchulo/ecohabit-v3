import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/database/app_database.dart';
import 'providers/app_state.dart';
import 'repositories/activity_repository.dart';
import 'repositories/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    final state = AppState(
        AuthRepository(db, const SecureSessionStore()), ActivityRepository(db));
    runApp(EcoHabitApp(state: state));
    await state.initialize();
  } catch (e, stack) {
    debugPrint('Inicialização: $e\n$stack');
    runApp(MaterialApp(
        home: Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                          'Não foi possível abrir os dados locais. Seus dados não foram apagados.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: main,
                          child: const Text('Tentar novamente'))
                    ])))))));
  }
}
