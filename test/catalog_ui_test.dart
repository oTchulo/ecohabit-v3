import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ecohabit/app/app.dart';
import 'package:ecohabit/core/database/app_database.dart';
import 'package:ecohabit/providers/app_state.dart';
import 'package:ecohabit/repositories/activity_repository.dart';
import 'package:ecohabit/repositories/auth_repository.dart';
import 'ecohabit_test.dart' show MemorySession, TestPasswords;

void main() {
  testWidgets(
      'busca, seis categorias, conquista concluída e registro mensal com referência',
      (tester) async {
    sqfliteFfiInit();
    final db = (await tester.runAsync(() => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath)))!;
    final auth =
        AuthRepository(db, MemorySession(), passwords: TestPasswords());
    final state = AppState(
        auth, ActivityRepository(db, clock: () => DateTime(2026, 11, 10)));
    await tester.runAsync(() async {
      state.account = await auth.register('Teste de catálogo',
          'catalogo@example.invalid', 'teste12345', 'teste12345');
      auth.lastRecoveryCode = null;
      await state.refresh();
    });
    state.ready = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(EcoHabitApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atividades'));
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(7));
    Future<void> search(String value) async {
      final finder = find.byKey(const ValueKey('activity-search'));
      await tester.scrollUntilVisible(finder, -300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.enterText(finder, value);
      await tester.pumpAndSettle();
    }

    Future<void> tapVisible(String text) async {
      await tester.scrollUntilVisible(find.text(text).first, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(text).first);
      await tester.pumpAndSettle();
    }

    Future<void> confirm() async {
      await tester.scrollUntilVisible(find.text('Confirmar registro'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirmar registro'));
        while (state.busy) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    await search('inexistente');
    expect(find.textContaining('Nenhuma atividade encontrada'), findsOneWidget);
    await search('composteira');
    await tapVisible('Registrar');
    expect(find.textContaining('Conquista única'), findsOneWidget);
    final quantity =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(
        tester.widget<EditableText>(find.byType(EditableText).first).readOnly,
        isTrue);
    expect(quantity.controller!.text, '1');
    await confirm();
    expect(state.xp, 150);
    await tester.ensureVisible(find.text('Concluída'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Concluída'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
    await search('vazamento');
    await tapVisible('Registrar');
    await tester.enterText(find.byType(TextFormField).first, '1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Mensal · Mês 2026-11'), findsOneWidget);
    await confirm();
    expect(find.text('Identifique o trajeto ou evento real.'), findsOneWidget);
    expect(state.xp, 150);
    await tester.enterText(find.byType(TextFormField).at(1), 'reparo-teste-1');
    await tester.pumpAndSettle();
    await confirm();
    expect(state.xp, 210);
    expect(state.history.length, 2);
    await tester.ensureVisible(find.text('XP conquistado: 60 / 100 XP'));
    await tester.pumpAndSettle();
    expect(find.text('XP conquistado: 60 / 100 XP'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.runAsync(db.close);
  });
}
