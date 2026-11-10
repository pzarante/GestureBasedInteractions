import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:expo_paunat/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PizarraApp());
  }

  final board = find.byKey(const ValueKey('board'));

  String colorName(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('colorName'))).data!;

  Future<void> drawLine(WidgetTester tester) async {
    final c = tester.getCenter(board);
    final g = await tester.startGesture(c - const Offset(150, 0));
    for (var i = 1; i <= 15; i++) {
      await g.moveBy(const Offset(20, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('arrastrar un dedo dibuja un trazo', (tester) async {
    await pumpApp(tester);
    expect(find.textContaining('Dibuja con el dedo'), findsOneWidget);

    await drawLine(tester);

    expect(find.textContaining('Dibuja con el dedo'), findsNothing);
    expect(
      find.textContaining('Táctil: Arrastrar un dedo → Dibujar'),
      findsOneWidget,
    );
  });

  testWidgets('doble toque cambia el color', (tester) async {
    await pumpApp(tester);
    expect(colorName(tester), 'Blanco');

    await tester.tap(board);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(board);
    await tester.pumpAndSettle();

    expect(colorName(tester), 'Cian');
  });

  testWidgets('mantener presionado borra y dos dedos deshacen', (tester) async {
    await pumpApp(tester);
    await drawLine(tester);

    await tester.longPress(board);
    await tester.pumpAndSettle();
    expect(find.textContaining('(Pizarra borrada)'), findsOneWidget);
    expect(find.textContaining('Dibuja con el dedo'), findsOneWidget);

    // Toque rápido con dos dedos, sin moverlos.
    final c = tester.getCenter(board);
    final a = await tester.startGesture(c);
    final b = await tester.startGesture(c + const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 80));
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(find.textContaining('(Último cambio deshecho)'), findsOneWidget);
    expect(find.textContaining('Dibuja con el dedo'), findsNothing);
  });

  testWidgets('en pantalla de celular: pizarra, barra de canales y guía', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const PizarraApp());

    expect(find.byKey(const ValueKey('cameraButton')), findsOneWidget);
    expect(find.byKey(const ValueKey('sensorsButton')), findsOneWidget);

    await drawLine(tester);
    expect(find.textContaining('Dibuja con el dedo'), findsNothing);

    // Fuera del navegador no hay sensores: se muestra el aviso, sin fallar.
    await tester.tap(find.byKey(const ValueKey('sensorsButton')));
    await tester.pumpAndSettle();
    expect(find.textContaining('versión web'), findsOneWidget);

    await tester.tap(find.byTooltip('Gestos y registro'));
    await tester.pumpAndSettle();
    expect(find.text('Gesto → función'), findsOneWidget);
    final entry = find.textContaining('Táctil: Arrastrar un dedo');
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(entry, findsOneWidget);
  });

  testWidgets('pellizcar con dos dedos hace zoom', (tester) async {
    await pumpApp(tester);
    final c = tester.getCenter(board);
    final a = await tester.startGesture(c - const Offset(40, 0));
    final b = await tester.startGesture(c + const Offset(40, 0));
    for (var i = 0; i < 10; i++) {
      await a.moveBy(const Offset(-15, 0));
      await b.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Pellizcar con dos dedos → Zoom'),
      findsOneWidget,
    );
    expect(find.textContaining('×'), findsWidgets);
  });
}
