import 'package:flutter_test/flutter_test.dart';

import 'package:expo_paunat/gestures/touchless_gesture_detector.dart';

/// Genera una mano sintética de 21 landmarks (palma mirando a la cámara,
/// dedos hacia arriba). [cx], [cy] = base del dedo medio; [s] = tamaño.
List<Point3D> fakeHand({
  bool index = true,
  bool middle = true,
  bool ring = true,
  bool pinky = true,
  bool pinch = false,
  double cx = 0.5,
  double cy = 0.5,
  double s = 0.2,
}) {
  final p = List<Point3D>.filled(21, const Point3D(0, 0, 0));
  p[0] = Point3D(cx, cy + s, 0); // muñeca

  void finger(int mcp, double xOff, bool extended) {
    final x = cx + xOff * s;
    p[mcp] = Point3D(x, cy, 0);
    if (extended) {
      p[mcp + 1] = Point3D(x, cy - 0.45 * s, 0);
      p[mcp + 2] = Point3D(x, cy - 0.70 * s, 0);
      p[mcp + 3] = Point3D(x, cy - 0.95 * s, 0);
    } else {
      // Dedo doblado: la punta regresa hacia la palma.
      p[mcp + 1] = Point3D(x, cy - 0.30 * s, 0);
      p[mcp + 2] = Point3D(x, cy - 0.10 * s, 0);
      p[mcp + 3] = Point3D(x, cy + 0.15 * s, 0);
    }
  }

  finger(5, -0.3, index);
  finger(9, 0.0, middle);
  finger(13, 0.3, ring);
  finger(17, 0.6, pinky);

  p[1] = Point3D(cx - 0.5 * s, cy + 0.7 * s, 0);
  p[2] = Point3D(cx - 0.7 * s, cy + 0.4 * s, 0);
  p[3] = Point3D(cx - 0.8 * s, cy + 0.15 * s, 0);
  p[4] = pinch
      ? Point3D(p[8].x + 0.02 * s, p[8].y, 0)
      : Point3D(cx - 0.85 * s, cy - 0.05 * s, 0);
  return p;
}

void main() {
  group('classify', () {
    test('palma abierta', () {
      expect(
        TouchlessGestureDetector.classify(fakeHand(), 1),
        HandPose.openPalm,
      );
    });
    test('puño', () {
      expect(
        TouchlessGestureDetector.classify(
          fakeHand(index: false, middle: false, ring: false, pinky: false),
          1,
        ),
        HandPose.fist,
      );
    });
    test('señalar con el índice', () {
      expect(
        TouchlessGestureDetector.classify(
          fakeHand(middle: false, ring: false, pinky: false),
          1,
        ),
        HandPose.pointing,
      );
    });
    test('dos dedos arriba (índice y medio)', () {
      expect(
        TouchlessGestureDetector.classify(
          fakeHand(ring: false, pinky: false),
          1,
        ),
        HandPose.victory,
      );
    });
    test('pinch / gesto OK', () {
      expect(
        TouchlessGestureDetector.classify(
          fakeHand(index: false, pinch: true),
          1,
        ),
        HandPose.pinch,
      );
    });
  });

  group('eventos', () {
    Duration ms(int v) => Duration(milliseconds: v);

    test('el pinch dispara un solo evento aunque se mantenga', () {
      final d = TouchlessGestureDetector();
      final events = <TouchlessEvent>[];
      var t = 0;
      for (var i = 0; i < 6; i++) {
        events.addAll(
          d.process(fakeHand(), timestamp: ms(t += 33), aspect: 1).events,
        );
      }
      for (var i = 0; i < 20; i++) {
        events.addAll(
          d
              .process(
                fakeHand(index: false, pinch: true),
                timestamp: ms(t += 33),
                aspect: 1,
              )
              .events,
        );
      }
      expect(events, [TouchlessEvent.pinch]);
    });

    test('el puño necesita sostenerse varios frames', () {
      final d = TouchlessGestureDetector();
      final fist = fakeHand(
        index: false,
        middle: false,
        ring: false,
        pinky: false,
      );
      var t = 0;
      final early = <TouchlessEvent>[];
      for (var i = 0; i < 5; i++) {
        early.addAll(d.process(fist, timestamp: ms(t += 33), aspect: 1).events);
      }
      expect(early, isEmpty);
      final later = <TouchlessEvent>[];
      for (var i = 0; i < 10; i++) {
        later.addAll(d.process(fist, timestamp: ms(t += 33), aspect: 1).events);
      }
      expect(later, [TouchlessEvent.fist]);
    });

    test('palma moviéndose a la izquierda de la pantalla = swipeLeft', () {
      final d = TouchlessGestureDetector();
      final events = <TouchlessEvent>[];
      // En la imagen original x crece; en pantalla (espejo) va a la izquierda.
      for (var i = 0; i <= 10; i++) {
        events.addAll(
          d
              .process(
                fakeHand(cx: 0.3 + i * 0.04),
                timestamp: ms(i * 30),
                aspect: 1,
              )
              .events,
        );
      }
      expect(events, [TouchlessEvent.swipeLeft]);
    });

    test('palma quieta no dispara swipe', () {
      final d = TouchlessGestureDetector();
      final events = <TouchlessEvent>[];
      for (var i = 0; i < 30; i++) {
        events.addAll(
          d
              .process(
                fakeHand(cx: 0.5 + (i.isEven ? 0.005 : -0.005)),
                timestamp: ms(i * 33),
                aspect: 1,
              )
              .events,
        );
      }
      expect(events, isEmpty);
    });
  });
}
