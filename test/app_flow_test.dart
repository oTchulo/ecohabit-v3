import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ecohabit/app/app.dart';
import 'package:ecohabit/core/database/app_database.dart';
import 'package:ecohabit/providers/app_state.dart';
import 'package:ecohabit/repositories/activity_repository.dart';
import 'package:ecohabit/repositories/auth_repository.dart';
import 'ecohabit_test.dart' show MemorySession, TestPasswords;

void main() {
  testWidgets('fluxo SQLite: navegação, registro, ranking, histórico e logout',
      (tester) async {
    sqfliteFfiInit();
    if (const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) {
      await tester.runAsync(() async {
        final fonts =
            '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
        for (final entry in {
          'Roboto': 'roboto-regular.ttf',
          'MaterialIcons': 'materialicons-regular.otf'
        }.entries) {
          final loader = FontLoader(entry.key);
          loader.addFont(File('$fonts/${entry.value}')
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)));
          await loader.load();
        }
      });
    }
    final db = (await tester.runAsync(() => AppDatabase.open(
        factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath)))!;
    final state = AppState(
        AuthRepository(db, MemorySession(), passwords: TestPasswords()),
        ActivityRepository(db));
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_SCREENSHOTS')) return;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots').create(recursive: true);
        await File('docs/screenshots/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    state.ready = true;
    await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: EcoHabitApp(state: state)));
    await tester.pumpAndSettle();
    await capture('login');
    await tester.tap(find.text('Criar minha conta'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Conta de teste');
    await tester.enterText(fields.at(1), 'teste@example.com');
    await tester.enterText(fields.at(2), 'teste12345');
    await tester.enterText(fields.at(3), 'teste12345');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Criar conta'));
      while (state.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Guarde seu código de recuperação'), findsOneWidget);
    // O código secreto não aparece nas capturas.
    await tester.tap(find.text('Guardei meu código'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Olá, Conta'), findsOneWidget);
    await capture('inicio');
    await tester.tap(find.text('Atividades'));
    await tester.pumpAndSettle();
    await capture('atividades');
    await tester.ensureVisible(find.text('Registrar').first);
    await tester.tap(find.text('Registrar').first);
    await tester.pumpAndSettle();
    expect(find.text('Registrar ação'), findsOneWidget);
    for (final invalid in ['-4', '1,5', '1.5', '0', '2147483648']) {
      await tester.enterText(find.byType(TextFormField).first, invalid);
      await tester.pumpAndSettle();
      expect(find.text('Informe um inteiro positivo até 2147483647.'),
          findsOneWidget);
      expect(state.history, isEmpty);
    }
    await tester.enterText(find.byType(TextFormField).first, '4');
    await tester.pumpAndSettle();
    expect(find.text('+30 XP estimados'), findsOneWidget);
    await capture('registro');
    await tester.ensureVisible(find.text('Confirmar registro'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Confirmar registro'));
      while (state.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(state.xp, 30);
    expect(state.history.length, 1);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranking'));
    await tester.pumpAndSettle();
    expect(find.text('Conta de teste (você)'), findsOneWidget);
    await capture('ranking');
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await capture('perfil');
    await tester.scrollUntilVisible(find.text('Reciclagem de garrafas'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Reciclagem de garrafas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sair da conta'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.runAsync(() async {
      await tester.tap(find.text('Sair da conta'));
      while (state.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'teste@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'teste12345');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.runAsync(() async {
      await tester.tap(find.text('Entrar'));
      while (state.busy) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Olá, Conta'), findsOneWidget);
    expect(state.xp, 30);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    await tester.runAsync(db.close);
  });
}
