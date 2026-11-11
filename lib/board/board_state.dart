import 'dart:ui' show Color;

import 'board_painter.dart';

const palette = <(String, Color)>[
  ('Blanco', Color(0xFFF5F5F5)),
  ('Cian', Color(0xFF4DD0E1)),
  ('Amarillo', Color(0xFFFFEE58)),
  ('Rosa', Color(0xFFF06292)),
  ('Verde', Color(0xFF81C784)),
  ('Naranja', Color(0xFFFFB74D)),
];

/// Contenido de la pizarra, historial para deshacer y color actual.
/// Sin widgets: los tres canales (táctil, touchless, inercial) lo usan igual.
class BoardState {
  List<Stroke> _strokes = [];
  final List<List<Stroke>> _history = [];
  int _colorIndex = 0;

  List<Stroke> get strokes => _strokes;
  String get colorName => palette[_colorIndex].$1;
  Color get color => palette[_colorIndex].$2;

  /// Agrega un trazo. Devuelve false si el trazo está vacío.
  bool commit(Stroke s) {
    if (s.points.isEmpty) return false;
    _history.add(_strokes);
    _strokes = [..._strokes, s];
    return true;
  }

  /// Vuelve al estado anterior. Devuelve false si no hay nada que deshacer.
  bool undo() {
    if (_history.isEmpty) return false;
    _strokes = _history.removeLast();
    return true;
  }

  /// Borra todo (se puede deshacer). Devuelve false si ya estaba vacía.
  bool clear() {
    if (_strokes.isEmpty) return false;
    _history.add(_strokes);
    _strokes = [];
    return true;
  }

  void changeColor(int delta) =>
      _colorIndex = (_colorIndex + delta) % palette.length;
}
