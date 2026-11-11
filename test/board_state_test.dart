import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:expo_paunat/board/board_painter.dart';
import 'package:expo_paunat/board/board_state.dart';

Stroke line() => Stroke(const Color(0xFFFFFFFF))..points.add(Offset.zero);

void main() {
  test('dibujar, borrar y deshacer en orden', () {
    final b = BoardState();
    final a = line(), c = line();
    expect(b.commit(a), isTrue);
    expect(b.commit(c), isTrue);
    expect(b.clear(), isTrue);
    expect(b.strokes, isEmpty);

    expect(b.undo(), isTrue); // deshace el borrado
    expect(b.strokes, [a, c]);
    expect(b.undo(), isTrue); // deshace el segundo trazo
    expect(b.strokes, [a]);
    expect(b.undo(), isTrue);
    expect(b.strokes, isEmpty);
    expect(b.undo(), isFalse); // nada más que deshacer
  });

  test('trazo vacío y borrar pizarra vacía no cambian el historial', () {
    final b = BoardState();
    expect(b.commit(Stroke(const Color(0xFFFFFFFF))), isFalse);
    expect(b.clear(), isFalse);
    expect(b.undo(), isFalse);
  });

  test('el color da la vuelta en ambos sentidos', () {
    final b = BoardState();
    b.changeColor(-1);
    expect(b.colorName, palette.last.$1);
    b.changeColor(1);
    expect(b.colorName, palette.first.$1);
  });
}
