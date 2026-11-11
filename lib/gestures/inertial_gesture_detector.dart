import 'dart:math' as math;

/// Una lectura de la IMU del celular (llega por Wi-Fi desde la página de
/// control, que lee el evento `devicemotion` / `deviceorientation`).
class MotionSample {
  const MotionSample({
    required this.ax,
    required this.ay,
    required this.az,
    this.beta,
    this.gamma,
  });

  /// Aceleración lineal (sin gravedad) en m/s², ejes del dispositivo.
  final double ax, ay, az;

  /// Inclinación adelante/atrás en grados (-180..180). ±180 = boca abajo.
  final double? beta;

  /// Inclinación izquierda/derecha en grados (-90..90).
  final double? gamma;
}

enum InertialEvent { shake, tiltLeft, tiltRight, faceDown }

class InertialFrameResult {
  const InertialFrameResult({
    required this.magnitude,
    required this.events,
    this.gamma,
    this.faceDown = false,
  });

  /// |a| = √(x² + y² + z²) de esta lectura.
  final double magnitude;
  final List<InertialEvent> events;
  final double? gamma;
  final bool faceDown;
}

/// Convierte el flujo de lecturas del acelerómetro en gestos inerciales.
///
/// * **Agitar (shake-to-undo):** se calcula la magnitud del vector de
///   aceleración lineal. Una agitación son varios picos que superan el
///   umbral *y* alternan de signo (ida y vuelta) dentro de una ventana corta.
///   Un solo golpe o un movimiento en una sola dirección no cuenta.
/// * **Inclinar:** el ángulo gamma supera ±[tiltOnDegrees] durante
///   [tiltHold]; para volver a dispararse hay que regresar al centro.
/// * **Boca abajo:** |beta| cerca de 180° durante [faceDownHold].
class InertialGestureDetector {
  InertialGestureDetector({
    this.shakeThreshold = 12.0,
    this.shakePeaks = 3,
    this.shakeWindow = const Duration(milliseconds: 900),
    this.shakeCooldown = const Duration(milliseconds: 1200),
    this.tiltOnDegrees = 35,
    this.tiltOffDegrees = 15,
    this.tiltHold = const Duration(milliseconds: 250),
    this.faceDownDegrees = 150,
    this.faceDownHold = const Duration(milliseconds: 600),
  });

  final double shakeThreshold;
  final int shakePeaks;
  final Duration shakeWindow;
  final Duration shakeCooldown;
  final double tiltOnDegrees;
  final double tiltOffDegrees;
  final Duration tiltHold;
  final double faceDownDegrees;
  final Duration faceDownHold;

  final List<(Duration, int)> _peaks = []; // (tiempo, signo del pico)
  Duration? _lastShake;
  Duration? _lastStrongMotion;

  int _tiltArmedSide = 0; // -1 izquierda, 1 derecha, 0 centro
  Duration? _tiltSince;
  bool _tiltFired = false;

  Duration? _faceDownSince;
  bool _faceDownFired = false;

  void reset() {
    _peaks.clear();
    _lastShake = null;
    _lastStrongMotion = null;
    _tiltArmedSide = 0;
    _tiltSince = null;
    _tiltFired = false;
    _faceDownSince = null;
    _faceDownFired = false;
  }

  /// |a| = √(x² + y² + z²)
  static double magnitude(MotionSample s) =>
      math.sqrt(s.ax * s.ax + s.ay * s.ay + s.az * s.az);

  InertialFrameResult process(MotionSample s, Duration t) {
    final events = <InertialEvent>[];
    final m = magnitude(s);

    // ---------------- Agitar ----------------
    if (m > shakeThreshold) {
      _lastStrongMotion = t;
      // Signo del eje dominante: indica hacia dónde va este pico. Un pico
      // nuevo se cuenta solo al cambiar de sentido; no se espera a que |a|
      // baje, porque al agitar en arco los otros ejes la mantienen alta.
      final axes = [s.ax, s.ay, s.az];
      var dominant = axes[0];
      for (final a in axes) {
        if (a.abs() > dominant.abs()) dominant = a;
      }
      final sign = dominant >= 0 ? 1 : -1;
      if (_peaks.isEmpty || _peaks.last.$2 != sign) {
        _peaks.add((t, sign));
      }
    }
    _peaks.removeWhere((p) => t - p.$1 > shakeWindow);
    final cooling = _lastShake != null && t - _lastShake! < shakeCooldown;
    if (!cooling && _peaks.length >= shakePeaks) {
      events.add(InertialEvent.shake);
      _lastShake = t;
      _peaks.clear();
    }

    // Mientras se agita, gamma y beta cambian mucho: no evaluar inclinación.
    final shaking =
        _lastStrongMotion != null &&
        t - _lastStrongMotion! < const Duration(milliseconds: 700);

    // ---------------- Boca abajo ----------------
    final beta = s.beta;
    var faceDown = false;
    if (beta != null) {
      faceDown = beta.abs() > faceDownDegrees;
      if (faceDown && !shaking) {
        _faceDownSince ??= t;
        if (!_faceDownFired && t - _faceDownSince! >= faceDownHold) {
          _faceDownFired = true;
          events.add(InertialEvent.faceDown);
        }
      } else if (beta.abs() < faceDownDegrees - 30) {
        _faceDownSince = null;
        _faceDownFired = false;
      }
    }

    // ---------------- Inclinar ----------------
    final gamma = s.gamma;
    if (gamma != null && !shaking && !faceDown) {
      final side = gamma > tiltOnDegrees
          ? 1
          : gamma < -tiltOnDegrees
          ? -1
          : 0;
      if (side != 0) {
        if (_tiltArmedSide != side) {
          _tiltArmedSide = side;
          _tiltSince = t;
          _tiltFired = false;
        } else if (!_tiltFired && t - _tiltSince! >= tiltHold) {
          _tiltFired = true;
          events.add(
            side > 0 ? InertialEvent.tiltRight : InertialEvent.tiltLeft,
          );
        }
      } else if (gamma.abs() < tiltOffDegrees) {
        _tiltArmedSide = 0;
        _tiltFired = false;
      }
    }

    return InertialFrameResult(
      magnitude: m,
      events: events,
      gamma: gamma,
      faceDown: faceDown,
    );
  }
}
