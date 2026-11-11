import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Punto 3D devuelto por el pipeline de visión por computadora (MediaPipe).
/// x, y están normalizados a [0, 1] respecto al frame de la cámara;
/// z es la profundidad relativa a la muñeca (misma escala aproximada que x).
class Point3D {
  final double x;
  final double y;
  final double z;

  const Point3D(this.x, this.y, this.z);
}

/// Índices de los 21 landmarks de MediaPipe Hands.
abstract final class Landmark {
  static const wrist = 0;
  static const thumbTip = 4;
  static const indexMcp = 5, indexPip = 6, indexTip = 8;
  static const middleMcp = 9, middlePip = 10, middleTip = 12;
  static const ringMcp = 13, ringPip = 14, ringTip = 16;
  static const pinkyMcp = 17, pinkyPip = 18, pinkyTip = 20;
}

/// Pose estática de la mano en un frame.
enum HandPose {
  none('Sin mano'),
  openPalm('Palma abierta'),
  pointing('Señalando (índice)'),
  pinch('Pinch / gesto OK'),
  zoomGrip('Zoom (pulgar + medio)'),
  victory('Dos dedos arriba'),
  fist('Puño cerrado'),
  other('Otra pose');

  const HandPose(this.label);
  final String label;
}

/// Gestos discretos que disparan una función.
enum TouchlessEvent { swipeLeft, swipeRight, pinch, victory, fist }

class TouchlessFrameResult {
  const TouchlessFrameResult({
    required this.pose,
    required this.events,
    required this.pinchRatio,
    this.indexTip,
    this.pinchPoint,
    this.zoomFactor,
  });

  /// Pose estable (filtrada en el tiempo, no la del frame crudo).
  final HandPose pose;

  /// Gestos que se completaron en este frame.
  final List<TouchlessEvent> events;

  /// Distancia pulgar-índice dividida entre el tamaño de la mano.
  final double pinchRatio;

  /// Punta del índice en coordenadas de pantalla (espejadas), 0..1.
  final Offset? indexTip;

  /// Punto medio entre pulgar e índice en coordenadas de pantalla, 0..1.
  final Offset? pinchPoint;

  /// Mientras se sostiene [HandPose.zoomGrip]: tamaño de la mano ahora
  /// dividido entre su tamaño al empezar (>1 = mano más cerca = acercar).
  final double? zoomFactor;
}

/// Convierte los landmarks de cada frame en poses y gestos.
///
/// 1. Clasifica la pose del frame (palma, señalar, pinch, dos dedos, puño).
/// 2. La estabiliza: solo cambia si se repite N frames seguidos
///    (evita falsos positivos por ruido del modelo).
/// 3. Emite eventos en el *flanco* de cambio (entrar a pinch / dos dedos /
///    puño) y
///    detecta el swipe analizando la trayectoria de la palma abierta.
class TouchlessGestureDetector {
  TouchlessGestureDetector({
    this.pinchThreshold = 0.30,
    this.stableFrames = 4,
    this.fistStableFrames = 8,
    this.victoryStableFrames = 8,
    this.swipeMinDistance = 0.20,
    this.swipeWindow = const Duration(milliseconds: 500),
    this.swipeCooldown = const Duration(milliseconds: 900),
  });

  final double pinchThreshold;
  final int stableFrames;
  final int fistStableFrames;
  final int victoryStableFrames;
  final double swipeMinDistance;
  final Duration swipeWindow;
  final Duration swipeCooldown;

  HandPose _candidate = HandPose.none;
  int _candidateCount = 0;
  HandPose _stable = HandPose.none;
  final List<(Duration, Offset)> _palmTrail = [];
  Duration? _lastSwipe;
  double? _zoomStartSize;
  double? _zoomSize; // suavizado contra el temblor del modelo

  HandPose get stablePose => _stable;

  void reset() {
    _candidate = HandPose.none;
    _candidateCount = 0;
    _stable = HandPose.none;
    _palmTrail.clear();
    _lastSwipe = null;
    _zoomStartSize = null;
    _zoomSize = null;
  }

  TouchlessFrameResult process(
    List<Point3D>? hand, {
    required Duration timestamp,
    double aspect = 4 / 3,
  }) {
    final events = <TouchlessEvent>[];
    var raw = HandPose.none;
    var ratio = 0.0;
    Offset? indexTip;
    Offset? pinchPoint;

    if (hand != null && hand.length >= 21) {
      ratio = pinchRatio(hand, aspect);
      raw = classify(hand, aspect, pinchThreshold: pinchThreshold);
      indexTip = _mirror(hand[Landmark.indexTip]);
      pinchPoint = Offset.lerp(_mirror(hand[Landmark.thumbTip]), indexTip, 0.5);

      final swipe = _trackSwipe(hand, raw, timestamp);
      if (swipe != null) events.add(swipe);
    } else {
      _palmTrail.clear();
    }

    // Estabilización temporal de la pose.
    if (raw == _candidate) {
      _candidateCount++;
    } else {
      _candidate = raw;
      _candidateCount = 1;
    }
    final needed = switch (raw) {
      HandPose.fist => fistStableFrames,
      HandPose.victory => victoryStableFrames,
      HandPose.none => 2,
      _ => stableFrames,
    };
    if (_candidateCount >= needed && _stable != _candidate) {
      _stable = _candidate;
      if (_stable == HandPose.pinch) events.add(TouchlessEvent.pinch);
      if (_stable == HandPose.fist) events.add(TouchlessEvent.fist);
      if (_stable == HandPose.victory) events.add(TouchlessEvent.victory);
    }

    // Zoom: el tamaño de la mano en la imagen dice qué tan cerca está de la
    // cámara (más estable que la profundidad z del modelo).
    if (_stable != HandPose.zoomGrip) {
      _zoomStartSize = null;
      _zoomSize = null;
    } else if (hand != null && hand.length >= 21) {
      final size = handSize(hand, aspect);
      final prev = _zoomSize;
      _zoomSize = prev == null ? size : prev * 0.7 + size * 0.3;
      _zoomStartSize ??= _zoomSize;
    }
    final zoomStart = _zoomStartSize;
    final zoomFactor = zoomStart == null ? null : _zoomSize! / zoomStart;

    return TouchlessFrameResult(
      pose: _stable,
      events: events,
      pinchRatio: ratio,
      indexTip: indexTip,
      pinchPoint: pinchPoint,
      zoomFactor: zoomFactor,
    );
  }

  /// Distancia euclidiana 3D entre punta del pulgar (4) y del índice (8),
  /// normalizada por el tamaño de la mano (muñeca → base del dedo medio)
  /// para que funcione igual cerca o lejos de la cámara.
  static double pinchRatio(List<Point3D> h, double aspect) =>
      _thumbRatio(h, Landmark.indexTip, aspect);

  /// Tamaño de la mano en la imagen: muñeca → base del dedo medio.
  static double handSize(List<Point3D> h, double aspect) =>
      _dist(h[Landmark.wrist], h[Landmark.middleMcp], aspect);

  /// Distancia de la punta del pulgar a la punta [tip], sobre el tamaño de
  /// la mano.
  static double _thumbRatio(List<Point3D> h, int tip, double aspect) {
    final size = handSize(h, aspect);
    if (size < 1e-6) return double.infinity;
    return _dist(h[Landmark.thumbTip], h[tip], aspect) / size;
  }

  /// Un dedo está extendido si su punta está claramente más lejos de la
  /// muñeca que su articulación media (PIP).
  static bool isExtended(List<Point3D> h, int tip, int pip, double aspect) {
    final wrist = h[Landmark.wrist];
    return _dist(wrist, h[tip], aspect) > _dist(wrist, h[pip], aspect) * 1.1;
  }

  static HandPose classify(
    List<Point3D> h,
    double aspect, {
    double pinchThreshold = 0.30,
  }) {
    final index = isExtended(h, Landmark.indexTip, Landmark.indexPip, aspect);
    final middle = isExtended(
      h,
      Landmark.middleTip,
      Landmark.middlePip,
      aspect,
    );
    final ring = isExtended(h, Landmark.ringTip, Landmark.ringPip, aspect);
    final pinky = isExtended(h, Landmark.pinkyTip, Landmark.pinkyPip, aspect);
    final ratio = pinchRatio(h, aspect);

    // Pulgar con medio y el índice arriba = modo zoom. Va primero: el medio
    // doblado hacia el pulgar puede contar como extendido y caer en palma.
    if (index &&
        ratio > pinchThreshold &&
        _thumbRatio(h, Landmark.middleTip, aspect) < pinchThreshold) {
      return HandPose.zoomGrip;
    }

    final others = [middle, ring, pinky].where((e) => e).length;
    if (ratio < pinchThreshold && others >= 2) return HandPose.pinch;

    final extended = [index, middle, ring, pinky].where((e) => e).length;
    if (extended == 4 && ratio > 0.5) return HandPose.openPalm;
    if (index && others == 0) return HandPose.pointing;
    if (index && middle && !ring && !pinky) return HandPose.victory;
    if (extended == 0) return HandPose.fist;
    return HandPose.other;
  }

  /// Swipe aéreo: la palma abierta recorre horizontalmente al menos
  /// [swipeMinDistance] del ancho de la imagen dentro de [swipeWindow].
  TouchlessEvent? _trackSwipe(List<Point3D> h, HandPose raw, Duration t) {
    if (raw != HandPose.openPalm) {
      _palmTrail.clear();
      return null;
    }
    final palm = _mirror(
      _average(h, const [
        Landmark.wrist,
        Landmark.indexMcp,
        Landmark.middleMcp,
        Landmark.ringMcp,
        Landmark.pinkyMcp,
      ]),
    );
    _palmTrail.add((t, palm));
    _palmTrail.removeWhere((e) => t - e.$1 > swipeWindow);

    if (_lastSwipe != null && t - _lastSwipe! < swipeCooldown) return null;
    if (_palmTrail.length < 3) return null;

    final delta = _palmTrail.last.$2 - _palmTrail.first.$2;
    if (delta.dx.abs() >= swipeMinDistance &&
        delta.dx.abs() > delta.dy.abs() * 1.5) {
      _lastSwipe = t;
      _palmTrail.clear();
      return delta.dx < 0
          ? TouchlessEvent.swipeLeft
          : TouchlessEvent.swipeRight;
    }
    return null;
  }

  /// La cámara frontal se muestra en espejo: lo que el usuario ve a su
  /// izquierda corresponde a x grande en la imagen original.
  static Offset _mirror(Point3D p) => Offset(1 - p.x, p.y);

  static Point3D _average(List<Point3D> h, List<int> ids) {
    var x = 0.0, y = 0.0, z = 0.0;
    for (final i in ids) {
      x += h[i].x;
      y += h[i].y;
      z += h[i].z;
    }
    return Point3D(x / ids.length, y / ids.length, z / ids.length);
  }

  /// d = sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2), corrigiendo x y z
  /// por la relación de aspecto de la cámara (x está normalizado al ancho).
  static double _dist(Point3D a, Point3D b, double aspect) {
    final dx = (a.x - b.x) * aspect;
    final dy = a.y - b.y;
    final dz = (a.z - b.z) * aspect;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}
