// En web usa la cámara + MediaPipe (web/hand_tracker.js).
// En otras plataformas (y en los tests) usa un stub sin cámara.
export 'hand_tracker_stub.dart'
    if (dart.library.js_interop) 'hand_tracker_web.dart';
