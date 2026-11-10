import 'package:flutter/material.dart';

/// Un trazo de la pizarra, en coordenadas del lienzo (sin zoom).
class Stroke {
  Stroke(this.color, {this.width = 6});

  final Color color;
  final double width;
  final List<Offset> points = [];
}

/// Dibuja la cuadrícula y los trazos aplicando el zoom y el desplazamiento.
class BoardPainter extends CustomPainter {
  BoardPainter({
    required this.strokes,
    required this.scale,
    required this.offset,
    required this.version,
  });

  final List<Stroke> strokes;
  final double scale;
  final Offset offset;

  /// Cambia cada vez que se modifica un trazo (para repintar).
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    final grid = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final s in strokes) {
      _drawStroke(canvas, s);
    }
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke s) {
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final p = s.points;
    if (p.isEmpty) return;
    if (p.length == 1) {
      canvas.drawCircle(
        p.first,
        s.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    // Curvas suaves pasando por los puntos medios.
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length; i++) {
      final mid = Offset.lerp(p[i - 1], p[i], 0.5)!;
      path.quadraticBezierTo(p[i - 1].dx, p[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(p.last.dx, p.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BoardPainter old) =>
      old.version != version || old.scale != scale || old.offset != offset;
}
