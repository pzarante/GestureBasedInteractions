// En web lee el acelerómetro del propio celular (web/motion_sensor.js).
// En otras plataformas (y en los tests) usa un stub sin sensores.
export 'motion_sensor_stub.dart'
    if (dart.library.js_interop) 'motion_sensor_web.dart';
