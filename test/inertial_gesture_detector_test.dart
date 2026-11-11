import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:expo_paunat/gestures/inertial_gesture_detector.dart';

Duration ms(int v) => Duration(milliseconds: v);

MotionSample still({double? beta = 20, double? gamma = 0}) =>
    MotionSample(ax: 0, ay: 0, az: 0, beta: beta, gamma: gamma);

void main() {
  test('|a| = √(x² + y² + z²)', () {
    expect(
      InertialGestureDetector.magnitude(
        const MotionSample(ax: 3, ay: 4, az: 12),
      ),
      13,
    );
  });

  test('agitar (picos fuertes que alternan de signo) = shake', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    // Ida y vuelta en x: +18, reposo, -18, reposo, +18 …
    for (final ax in [18.0, 0.0, -18.0, 0.0, 18.0, 0.0, -18.0, 0.0]) {
      events.addAll(
        d.process(MotionSample(ax: ax, ay: 0, az: 0), ms(t += 60)).events,
      );
    }
    expect(events, [InertialEvent.shake]);
  });

  test('agitar en arco (|a| nunca baja del umbral) también es shake', () {
    // Mano real: x va de +18 a -18 a 4 Hz y la curva del arco empuja en y
    // justo cuando x pasa por cero, así que |a| no vuelve al reposo.
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    for (var i = 0; i < 60; i++) {
      final phase = 2 * math.pi * 4 * i / 60;
      final s = MotionSample(
        ax: 18 * math.sin(phase),
        ay: 10 * math.cos(phase).abs(),
        az: 0,
      );
      events.addAll(d.process(s, ms(i * 1000 ~/ 60)).events);
    }
    expect(events, [InertialEvent.shake]);
  });

  test('un solo golpe fuerte no es agitar', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    for (final ax in [20.0, 0.0, 0.0, 0.0, 20.0, 0.0]) {
      events.addAll(
        d.process(MotionSample(ax: ax, ay: 0, az: 0), ms(t += 60)).events,
      );
    }
    expect(events, isEmpty);
  });

  test('movimiento suave bajo el umbral no dispara nada', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    for (var i = 0; i < 60; i++) {
      final ax = i.isEven ? 6.0 : -6.0;
      events.addAll(
        d.process(MotionSample(ax: ax, ay: 0, az: 0), ms(i * 16)).events,
      );
    }
    expect(events, isEmpty);
  });

  test('inclinar a la derecha y sostener = tiltRight una sola vez', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    for (var i = 0; i < 40; i++) {
      events.addAll(d.process(still(gamma: 50), ms(t += 16)).events);
    }
    expect(events, [InertialEvent.tiltRight]);

    // Para volver a disparar hay que regresar al centro.
    for (var i = 0; i < 10; i++) {
      events.addAll(d.process(still(gamma: 0), ms(t += 16)).events);
    }
    for (var i = 0; i < 40; i++) {
      events.addAll(d.process(still(gamma: -50), ms(t += 16)).events);
    }
    expect(events, [InertialEvent.tiltRight, InertialEvent.tiltLeft]);
  });

  test('inclinación breve (menos de 250 ms) no cuenta', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    for (var i = 0; i < 8; i++) {
      events.addAll(d.process(still(gamma: 50), ms(t += 16)).events);
    }
    for (var i = 0; i < 20; i++) {
      events.addAll(d.process(still(gamma: 0), ms(t += 16)).events);
    }
    expect(events, isEmpty);
  });

  test('boca abajo sostenido = faceDown una sola vez', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    for (var i = 0; i < 80; i++) {
      events.addAll(d.process(still(beta: 178, gamma: 0), ms(t += 16)).events);
    }
    expect(events, [InertialEvent.faceDown]);
  });

  test('mientras se agita no se evalúa la inclinación', () {
    final d = InertialGestureDetector();
    final events = <InertialEvent>[];
    var t = 0;
    for (var i = 0; i < 30; i++) {
      final ax = i.isEven ? 16.0 : -16.0;
      events.addAll(
        d
            .process(
              MotionSample(ax: ax, ay: 0, az: 0, gamma: 60, beta: 20),
              ms(t += 30),
            )
            .events,
      );
    }
    expect(events.where((e) => e != InertialEvent.shake), isEmpty);
  });
}
