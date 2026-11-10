import '../gestures/inertial_gesture_detector.dart';

typedef MotionCallback = void Function(MotionSample sample);

/// Implementación vacía para plataformas sin el puente de sensores web.
class MotionSensor {
  /// Devuelve un mensaje de error, o null si arrancó bien.
  static Future<String?> start(MotionCallback onSample) async =>
      'Los sensores de movimiento están disponibles en la versión web.';

  static void stop() {}
}
