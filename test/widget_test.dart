import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ecohabit/app/theme.dart';
import 'package:ecohabit/providers/app_state.dart';
import 'package:ecohabit/screens/auth_screen.dart';
import 'package:ecohabit/widgets/shared.dart';
import 'package:ecohabit/repositories/auth_repository.dart';
import 'package:ecohabit/repositories/activity_repository.dart';
import 'package:ecohabit/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'ecohabit_test.dart' show MemorySession;

void main() {
  testWidgets('login, cadastro e validação em tela estreita', (tester) async {
    sqfliteFfiInit();
    final db = (await tester.runAsync(() => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath)))!;
    final state =
        AppState(AuthRepository(db, MemorySession()), ActivityRepository(db));
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: ecoTheme(), home: const AuthScreen())));
    expect(find.text('EcoHabit'), findsOneWidget);
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('E-mail inválido.'), findsOneWidget);
    await tester.ensureVisible(find.text('Criar minha conta'));
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    expect(find.text('Nome completo'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.runAsync(db.close);
  });
  testWidgets('progresso no nível máximo e impacto não calculado',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ecoTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          ProgressCard(xp: 2000),
          ImpactCard(data: {'acoes': 0})
        ])))));
    await tester.pumpAndSettle();
    expect(find.text('Nível máximo alcançado!'), findsOneWidget);
    expect(find.textContaining('Não calculado'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
