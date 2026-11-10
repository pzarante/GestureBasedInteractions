import 'dart:js_interop';

import '../gestures/inertial_gesture_detector.dart';

typedef MotionCallback = void Function(MotionSample sample);

/// API expuesta por web/motion_sensor.js en `window.motionSensor`.
extension type _MotionSensorJS._(JSObject _) implements JSObject {
  external JSPromise<JSString?> start();
  external void stop();
  external void setListener(JSFunction listener);
}

@JS('motionSensor')
external _MotionSensorJS? get _sensor;

/// Lee la IMU del mismo dispositivo donde corre la app (el celular).
class MotionSensor {
  /// Pide permiso y empieza a entregar lecturas (~60 por segundo).
  /// Debe llamarse desde un toque del usuario (lo exige iPhone).
  /// Devuelve un mensaje de error, o null si arrancó bien.
  static Future<String?> start(MotionCallback onSample) async {
    final sensor = _sensor;
    if (sensor == null) {
      return 'No se cargó motion_sensor.js (revisa web/index.html).';
    }
    sensor.setListener(
      ((
        JSNumber ax,
        JSNumber ay,
        JSNumber az,
        JSNumber? beta,
        JSNumber? gamma,
      ) {
        onSample(
          MotionSample(
            ax: ax.toDartDouble,
            ay: ay.toDartDouble,
            az: az.toDartDouble,
            beta: beta?.toDartDouble,
            gamma: gamma?.toDartDouble,
          ),
        );
      }).toJS,
    );
    final error = await sensor.start().toDart;
    return error?.toDart;
  }

  static void stop() => _sensor?.stop();
}
