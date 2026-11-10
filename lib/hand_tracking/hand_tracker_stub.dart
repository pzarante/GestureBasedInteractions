import 'package:flutter/widgets.dart';

import '../gestures/touchless_gesture_detector.dart';

typedef HandFrameCallback = void Function(List<Point3D>? hand, double aspect);

/// Implementación vacía para plataformas sin el puente de cámara web.
class HandTracker {
  static bool get isSupported => false;

  /// Devuelve un mensaje de error, o null si arrancó bien.
  static Future<String?> start(HandFrameCallback onFrame) async =>
      'El modo touchless está disponible en la versión web (Chrome).';

  static void stop() {}

  static Widget preview() => const SizedBox.shrink();
}
